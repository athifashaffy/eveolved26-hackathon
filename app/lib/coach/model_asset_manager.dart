import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'model_manifest.dart';

enum ModelInstallStatus { notInstalled, ready, invalid }

class ModelInstallException implements Exception {
  final String code;
  const ModelInstallException(this.code);

  @override
  String toString() => 'ModelInstallException($code)';
}

class ModelAssetManager {
  final http.Client client;
  final Directory modelDirectory;
  final List<int> publicKeyBytes;
  final Set<String> allowedHosts;
  final Future<int> Function() availableBytes;

  const ModelAssetManager({
    required this.client,
    required this.modelDirectory,
    required this.publicKeyBytes,
    required this.allowedHosts,
    required this.availableBytes,
  });

  String get modelPath =>
      '${modelDirectory.path}/${ModelManifest.supportedModelVersion}.gguf';
  String get _partialPath => '${modelDirectory.path}/gemma.partial';
  String get _metadataPath => '${modelDirectory.path}/model.json';

  Future<ModelInstallStatus> modelStatus() async {
    final model = File(modelPath);
    final metadata = File(_metadataPath);
    if (!await model.exists() && !await metadata.exists()) {
      return ModelInstallStatus.notInstalled;
    }
    return await verify()
        ? ModelInstallStatus.ready
        : ModelInstallStatus.invalid;
  }

  Future<void> download(
    Uri manifestUri,
    void Function(double progress) onProgress, {
    bool Function()? isCancelled,
  }) async {
    _requireAllowed(manifestUri);
    await modelDirectory.create(recursive: true);
    final partial = File(_partialPath);
    try {
      final manifestBytes = await _readResponse(manifestUri);
      final manifest = await ModelManifest.parseAndVerify(
        utf8.decode(manifestBytes),
        publicKeyBytes,
      );
      _requireAllowed(manifest.artifactUrl);
      if (await availableBytes() < manifest.minimumFreeBytes) {
        throw const ModelInstallException('insufficient_storage');
      }
      if (isCancelled?.call() ?? false) {
        throw const ModelInstallException('cancelled');
      }

      final request = http.Request('GET', manifest.artifactUrl)
        ..followRedirects = false;
      final response = await client.send(request);
      if (response.isRedirect) {
        throw const ModelInstallException('redirect_rejected');
      }
      if (response.statusCode != 200) {
        throw ModelInstallException('artifact_http_${response.statusCode}');
      }
      final sink = partial.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          if (isCancelled?.call() ?? false) {
            throw const ModelInstallException('cancelled');
          }
          received += chunk.length;
          if (received > manifest.byteSize) {
            throw const ModelInstallException('size_mismatch');
          }
          sink.add(chunk);
          onProgress((received / manifest.byteSize).clamp(0, 1));
        }
      } finally {
        await sink.close();
      }
      if (received != manifest.byteSize) {
        throw const ModelInstallException('size_mismatch');
      }
      final bytes = await partial.readAsBytes();
      if (ModelManifest.sha256Hex(bytes) != manifest.sha256) {
        throw const ModelInstallException('checksum_mismatch');
      }
      final target = File(modelPath);
      if (await target.exists()) await target.delete();
      await partial.rename(modelPath);
      await File(_metadataPath).writeAsString(jsonEncode(<String, Object>{
        'modelVersion': manifest.modelVersion,
        'byteSize': manifest.byteSize,
        'sha256': manifest.sha256,
      }));
      onProgress(1);
    } on ModelManifestException catch (error) {
      throw ModelInstallException(error.code);
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<bool> verify() async {
    try {
      final model = File(modelPath);
      final metadata = File(_metadataPath);
      if (!await model.exists() || !await metadata.exists()) return false;
      final decoded = jsonDecode(await metadata.readAsString());
      if (decoded is! Map<String, dynamic> ||
          decoded['modelVersion'] != ModelManifest.supportedModelVersion ||
          decoded['byteSize'] != await model.length()) {
        return false;
      }
      return ModelManifest.sha256Hex(await model.readAsBytes()) ==
          decoded['sha256'];
    } on Object {
      return false;
    }
  }

  Future<void> delete() async {
    for (final path in <String>[modelPath, _partialPath, _metadataPath]) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<List<int>> _readResponse(Uri uri) async {
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await client.send(request);
    if (response.isRedirect) {
      throw const ModelInstallException('redirect_rejected');
    }
    if (response.statusCode != 200) {
      throw ModelInstallException('http_${response.statusCode}');
    }
    return response.stream.toBytes();
  }

  void _requireAllowed(Uri uri) {
    if (uri.scheme != 'https' || !allowedHosts.contains(uri.host)) {
      throw const ModelInstallException('host_not_allowed');
    }
  }
}
