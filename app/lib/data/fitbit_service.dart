import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'secrets.dart' as secrets;

/// Fitbit OAuth 2.0 (Server / confidential client) + PKCE + REST API integration.
///
/// SETUP:
///   - App type: Server (confidential client)
///   - Callback URL: signa://fitbit-callback
///   - Default Access Type: Read-Only
///   - Client ID + Secret live in `secrets.dart` (gitignored).
///
/// Server apps require HTTP Basic auth (`base64(client_id:client_secret)`) on
/// the token endpoint. PKCE is still applied for the auth code exchange.
class FitbitService {
  FitbitService._();
  static final instance = FitbitService._();

  // ─── Configuration ────────────────────────────────────────────────────────
  static const clientId = secrets.fitbitClientId;
  static const _clientSecret = secrets.fitbitClientSecret;

  static const _redirectUri = 'signa://fitbit-callback';
  static const _scopes = 'activity sleep heartrate';
  static const _authBase = 'https://www.fitbit.com/oauth2/authorize';
  static const _tokenUrl = 'https://api.fitbit.com/oauth2/token';
  static const _callbackScheme = 'signa';

  // ─── Secure storage keys ──────────────────────────────────────────────────
  static const _keyAccessToken = 'fitbit_access_token';
  static const _keyRefreshToken = 'fitbit_refresh_token';
  static const _keyExpiresAt = 'fitbit_expires_at';

  final _storage = const FlutterSecureStorage();

  // ─── Auth state ───────────────────────────────────────────────────────────

  Future<bool> isAuthenticated() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token == null) return false;
    // Check expiry
    final expiresAtStr = await _storage.read(key: _keyExpiresAt);
    if (expiresAtStr != null) {
      final expiresAt = DateTime.parse(expiresAtStr);
      if (DateTime.now().isAfter(expiresAt)) {
        return await _refreshToken();
      }
    }
    return true;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }

  // ─── OAuth 2.0 PKCE flow ──────────────────────────────────────────────────

  Future<bool> authenticate() async {
    final verifier = _generateCodeVerifier();
    final challenge = _generateCodeChallenge(verifier);

    final uri = Uri.parse(_authBase).replace(queryParameters: {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'scope': _scopes,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    try {
      final result = await FlutterWebAuth2.authenticate(
        url: uri.toString(),
        callbackUrlScheme: _callbackScheme,
      );

      final code = Uri.parse(result).queryParameters['code'];
      if (code == null) return false;

      return await _exchangeCode(code: code, verifier: verifier);
    } catch (_) {
      return false;
    }
  }

  Map<String, String> _tokenHeaders() {
    final basic = base64.encode(utf8.encode('$clientId:$_clientSecret'));
    return {
      'Content-Type': 'application/x-www-form-urlencoded',
      'Authorization': 'Basic $basic',
    };
  }

  Future<bool> _exchangeCode({
    required String code,
    required String verifier,
  }) async {
    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: _tokenHeaders(),
      body: {
        'grant_type': 'authorization_code',
        'redirect_uri': _redirectUri,
        'code': code,
        'code_verifier': verifier,
      },
    );

    if (response.statusCode != 200) return false;
    return _saveTokens(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<bool> _refreshToken() async {
    final refreshToken = await _storage.read(key: _keyRefreshToken);
    if (refreshToken == null) return false;

    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: _tokenHeaders(),
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      },
    );

    if (response.statusCode != 200) {
      await logout();
      return false;
    }
    return _saveTokens(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<bool> _saveTokens(Map<String, dynamic> json) async {
    final accessToken = json['access_token'] as String?;
    final refreshToken = json['refresh_token'] as String?;
    final expiresIn = json['expires_in'] as int? ?? 28800;

    if (accessToken == null) return false;

    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    await _storage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _keyRefreshToken, value: refreshToken);
    }
    await _storage.write(key: _keyExpiresAt, value: expiresAt.toIso8601String());
    return true;
  }

  Future<String?> _validAccessToken() async {
    if (!await isAuthenticated()) return null;
    return _storage.read(key: _keyAccessToken);
  }

  // ─── Fitbit Web API ───────────────────────────────────────────────────────

  /// Returns up to [days] days of StabilityReadings from Fitbit.
  Future<List<StabilityReading>?> fetchReadings({int days = 30}) async {
    final token = await _validAccessToken();
    if (token == null) return null;

    final headers = {'Authorization': 'Bearer $token'};
    final endDate = _dateStr(DateTime.now());
    final startDate = _dateStr(DateTime.now().subtract(Duration(days: days)));

    try {
      final results = await Future.wait([
        _getSteps(headers, startDate, endDate),
        _getSleep(headers, startDate, endDate),
        _getHeartRate(headers, startDate, endDate),
      ]);

      final stepsMap = results[0];
      final sleepMap = results[1];
      final hrMap = results[2];

      // Build readings for each date
      final allDates = <String>{
        ...stepsMap.keys,
        ...sleepMap.keys,
        ...hrMap.keys,
      };

      final readings = <StabilityReading>[];
      for (final dateStr in allDates) {
        final steps = stepsMap[dateStr] ?? 0;
        final sleepMin = sleepMap[dateStr] ?? 0;
        final restingHr = hrMap[dateStr] ?? 0;

        // Estimate HRV from resting HR (rough inverse: HRV ≈ 1000/HR * 3)
        // Fitbit premium users get actual HRV; for standard we estimate
        final estimatedHrv = restingHr > 0
            ? ((1000 / restingHr) * 3).clamp(20.0, 80.0).toInt()
            : 40;

        final sleepScore = (sleepMin / 480 * 100).clamp(0, 100).toInt();
        final normHrv = (estimatedHrv / 60).clamp(0.0, 1.0);
        final normSleep = sleepScore / 100.0;
        final score = (normHrv * 0.6 + normSleep * 0.4).clamp(0.0, 1.0);

        readings.add(StabilityReading(
          date: DateTime.parse(dateStr),
          score: score,
          hrvMs: estimatedHrv,
          sleepMinutes: sleepMin,
          sleepScore: sleepScore,
          steps: steps,
        ));
      }

      readings.sort((a, b) => a.date.compareTo(b.date));
      return readings.isEmpty ? null : readings;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, int>> _getSteps(
    Map<String, String> headers,
    String startDate,
    String endDate,
  ) async {
    final url =
        'https://api.fitbit.com/1/user/-/activities/steps/date/$startDate/$endDate.json';
    final res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode != 200) return {};

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['activities-steps'] as List? ?? [];
    return {
      for (final item in list)
        (item['dateTime'] as String): int.tryParse(item['value'] as String? ?? '0') ?? 0
    };
  }

  Future<Map<String, int>> _getSleep(
    Map<String, String> headers,
    String startDate,
    String endDate,
  ) async {
    final url =
        'https://api.fitbit.com/1.2/user/-/sleep/date/$startDate/$endDate.json';
    final res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode != 200) return {};

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['sleep'] as List? ?? [];

    // Sum minutes asleep per date
    final result = <String, int>{};
    for (final item in list) {
      final date = item['dateOfSleep'] as String? ?? '';
      final minutes = item['minutesAsleep'] as int? ?? 0;
      result[date] = (result[date] ?? 0) + minutes;
    }
    return result;
  }

  Future<Map<String, int>> _getHeartRate(
    Map<String, String> headers,
    String startDate,
    String endDate,
  ) async {
    final url =
        'https://api.fitbit.com/1/user/-/activities/heart/date/$startDate/$endDate.json';
    final res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode != 200) return {};

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['activities-heart'] as List? ?? [];

    return {
      for (final item in list)
        (item['dateTime'] as String): (item['value'] as Map?)?['restingHeartRate'] as int? ?? 0
    };
  }

  // ─── PKCE helpers ─────────────────────────────────────────────────────────

  static String _generateCodeVerifier() {
    final rand = Random.secure();
    final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
