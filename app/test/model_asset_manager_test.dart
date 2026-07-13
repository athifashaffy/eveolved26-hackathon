import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:signa/coach/model_asset_manager.dart';
import 'package:signa/coach/model_manifest.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late SimpleKeyPair keyPair;
  late SimplePublicKey publicKey;
  final artifact = utf8.encode('verified local gemma fixture');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('signa-model-test-');
    keyPair = await Ed25519().newKeyPair();
    publicKey = await keyPair.extractPublicKey();
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<String> signedManifest({
    Uri? artifactUrl,
    String? sha256,
    int? byteSize,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final payload = <String, Object?>{
      'schemaVersion': 1,
      'modelVersion': ModelManifest.supportedModelVersion,
      'byteSize': byteSize ?? artifact.length,
      'sha256': sha256 ?? ModelManifest.sha256Hex(artifact),
      'minimumFreeBytes': artifact.length + 1024,
      'artifactUrl':
          (artifactUrl ?? Uri.parse('https://models.signa.example/gemma.gguf'))
              .toString(),
      ...extra,
    };
    final signature = await Ed25519().sign(
      utf8.encode(ModelManifest.canonicalPayload(payload)),
      keyPair: keyPair,
    );
    return jsonEncode(<String, Object?>{
      ...payload,
      'signature': base64Encode(signature.bytes),
    });
  }

  test('downloads and atomically verifies a signed fixed-version model',
      () async {
    final manifest = await signedManifest();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('manifest.json')) {
        return http.Response(manifest, 200);
      }
      return http.Response.bytes(artifact, 200);
    });
    final manager = ModelAssetManager(
      client: client,
      modelDirectory: directory,
      publicKeyBytes: publicKey.bytes,
      allowedHosts: const <String>{'models.signa.example'},
      availableBytes: () async => 2 * 1024 * 1024 * 1024,
    );
    final progress = <double>[];

    await manager.download(
      Uri.parse('https://models.signa.example/manifest.json'),
      progress.add,
    );

    expect(await manager.modelStatus(), ModelInstallStatus.ready);
    expect(await manager.verify(), isTrue);
    expect(progress.last, 1);
    expect(await File(manager.modelPath).readAsBytes(), artifact);
  });

  test('rejects unknown manifest keys and corrupt artifacts', () async {
    final unknown = await signedManifest(extra: const {'trackingId': 'no'});
    final corruptManifest = await signedManifest();
    var currentManifest = unknown;
    final client = MockClient((request) async =>
        request.url.path.endsWith('manifest.json')
            ? http.Response(currentManifest, 200)
            : http.Response.bytes(utf8.encode('corrupt'), 200));
    final manager = ModelAssetManager(
      client: client,
      modelDirectory: directory,
      publicKeyBytes: publicKey.bytes,
      allowedHosts: const <String>{'models.signa.example'},
      availableBytes: () async => 2 * 1024 * 1024 * 1024,
    );

    await expectLater(
      manager.download(
        Uri.parse('https://models.signa.example/manifest.json'),
        (_) {},
      ),
      throwsA(isA<ModelInstallException>()),
    );
    currentManifest = corruptManifest;
    await expectLater(
      manager.download(
        Uri.parse('https://models.signa.example/manifest.json'),
        (_) {},
      ),
      throwsA(isA<ModelInstallException>()),
    );
    expect(await manager.modelStatus(), isNot(ModelInstallStatus.ready));
  });

  test('rejects non-allowlisted artifact host and supports deletion', () async {
    final hostile = await signedManifest(
      artifactUrl: Uri.parse('https://tracker.example/model.gguf'),
    );
    final client = MockClient((request) async => http.Response(hostile, 200));
    final manager = ModelAssetManager(
      client: client,
      modelDirectory: directory,
      publicKeyBytes: publicKey.bytes,
      allowedHosts: const <String>{'models.signa.example'},
      availableBytes: () async => 2 * 1024 * 1024 * 1024,
    );

    await expectLater(
      manager.download(
        Uri.parse('https://models.signa.example/manifest.json'),
        (_) {},
      ),
      throwsA(isA<ModelInstallException>()),
    );
    await File(manager.modelPath).writeAsBytes(artifact);
    await manager.delete();
    expect(await manager.modelStatus(), ModelInstallStatus.notInstalled);
  });
}
