import '../core/api_client.dart';

class AttendanceRepository {
  AttendanceRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// POST /attendance/clock-in — body: lat, lng
  Future<Map<String, dynamic>> clockIn({
    required String accessToken,
    required double lat,
    required double lng,
  }) async {
    final res = await _client
        .withToken(accessToken)
        .post('/attendance/clock-in', body: {'lat': lat, 'lng': lng});
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  /// POST /attendance/clock-out — body: lat, lng
  Future<Map<String, dynamic>> clockOut({
    required String accessToken,
    required double lat,
    required double lng,
  }) async {
    final res = await _client
        .withToken(accessToken)
        .post('/attendance/clock-out', body: {'lat': lat, 'lng': lng});
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> status(String accessToken) async {
    final res = await _client.withToken(accessToken).get('/attendance/status');
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  /// GET /attendance/history
  Future<List<dynamic>> history(String accessToken) async {
    final res = await _client.withToken(accessToken).get('/attendance/history');
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    return data is List ? data : [];
  }
}
