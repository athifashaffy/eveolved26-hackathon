import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';

class ModelManifestException implements Exception {
  final String code;
  const ModelManifestException(this.code);

  @override
  String toString() => 'ModelManifestException($code)';
}

class ModelManifest {
  static const supportedModelVersion = 'gemma-3-1b-it-q4km-v1';
  static const _requiredKeys = <String>{
    'schemaVersion',
    'modelVersion',
    'byteSize',
    'sha256',
    'minimumFreeBytes',
    'artifactUrl',
    'signature',
  };

  final int schemaVersion;
  final String modelVersion;
  final int byteSize;
  final String sha256;
  final int minimumFreeBytes;
  final Uri artifactUrl;

  const ModelManifest({
    required this.schemaVersion,
    required this.modelVersion,
    required this.byteSize,
    required this.sha256,
    required this.minimumFreeBytes,
    required this.artifactUrl,
  });

  static Future<ModelManifest> parseAndVerify(
    String source,
    List<int> publicKeyBytes,
  ) async {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const ModelManifestException('invalid_json');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded.keys.toSet().length != _requiredKeys.length ||
        !decoded.keys.toSet().containsAll(_requiredKeys)) {
      throw const ModelManifestException('invalid_keys');
    }
    final payload = Map<String, Object?>.from(decoded)..remove('signature');
    final signatureText = decoded['signature'];
    if (signatureText is! String) {
      throw const ModelManifestException('invalid_signature');
    }
    List<int> signatureBytes;
    try {
      signatureBytes = base64Decode(signatureText);
    } on FormatException {
      throw const ModelManifestException('invalid_signature');
    }
    final publicKey = SimplePublicKey(
      publicKeyBytes,
      type: KeyPairType.ed25519,
    );
    final verified = await Ed25519().verify(
      utf8.encode(canonicalPayload(payload)),
      signature: Signature(signatureBytes, publicKey: publicKey),
    );
    if (!verified) throw const ModelManifestException('invalid_signature');

    final schemaVersion = payload['schemaVersion'];
    final modelVersion = payload['modelVersion'];
    final byteSize = payload['byteSize'];
    final hash = payload['sha256'];
    final minimumFreeBytes = payload['minimumFreeBytes'];
    final artifact = payload['artifactUrl'];
    if (schemaVersion != 1 ||
        modelVersion != supportedModelVersion ||
        byteSize is! int ||
        byteSize <= 0 ||
        hash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash) ||
        minimumFreeBytes is! int ||
        minimumFreeBytes < byteSize ||
        artifact is! String) {
      throw const ModelManifestException('invalid_values');
    }
    final artifactUrl = Uri.tryParse(artifact);
    if (artifactUrl == null || artifactUrl.scheme != 'https') {
      throw const ModelManifestException('invalid_artifact_url');
    }
    return ModelManifest(
      schemaVersion: 1,
      modelVersion: supportedModelVersion,
      byteSize: byteSize,
      sha256: hash,
      minimumFreeBytes: minimumFreeBytes,
      artifactUrl: artifactUrl,
    );
  }

  static String canonicalPayload(Map<String, Object?> payload) {
    final sorted = SplayTreeMap<String, Object?>.from(payload);
    return jsonEncode(sorted);
  }

  static String sha256Hex(List<int> bytes) =>
      crypto.sha256.convert(bytes).toString();
}
