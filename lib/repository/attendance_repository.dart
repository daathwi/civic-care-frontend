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

  /// GET /attendance/history?from_date=&to_date=
  Future<List<dynamic>> history(
    String accessToken, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final params = <String, String>{};
    if (fromDate != null) params['from_date'] = _dateStr(fromDate);
    if (toDate != null) params['to_date'] = _dateStr(toDate);
    final q = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final res = await _client.withToken(accessToken).get('/attendance/history$q');
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    return data is List ? data : [];
  }

  /// GET /attendance/worker/{workerId} (Manager)
  Future<List<dynamic>> workerHistory(
    String accessToken,
    String workerId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final params = <String, String>{};
    if (fromDate != null) params['from_date'] = _dateStr(fromDate);
    if (toDate != null) params['to_date'] = _dateStr(toDate);
    final q = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final res = await _client.withToken(accessToken).get('/attendance/worker/$workerId$q');
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json;
    return data is List ? data : [];
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
