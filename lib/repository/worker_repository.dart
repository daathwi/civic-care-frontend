import '../core/api_client.dart';

class WorkerRepository {
  WorkerRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// GET /workers — optional department, ward_id, status, sort_by, skip, limit
  Future<Map<String, dynamic>> list({
    String? accessToken,
    String? department,
    String? wardId,
    String? status,
    String? sortBy,
    int skip = 0,
    int limit = 50,
  }) async {
    final q = <String, String>{'skip': '$skip', 'limit': '$limit'};
    if (department != null) q['department'] = department;
    if (wardId != null) q['ward_id'] = wardId;
    if (status != null) q['status'] = status;
    if (sortBy != null) q['sort_by'] = sortBy;

    final res = await _client.withToken(accessToken).get('/workers', queryParameters: q);
    if (!res.isOk) throw ApiException.fromResponse(res);
    return _parsePaginatedList(res);
  }

  static Map<String, dynamic> _parsePaginatedList(ApiResponse res) {
    final body = res.json;
    if (body == null) throw ApiException(res.statusCode, 'Invalid response: empty or non-JSON body');
    if (body is Map<String, dynamic>) {
      dynamic items = body['items'] ?? body['results'];
      if (items == null && body['data'] is Map) items = (body['data'] as Map)['items'] ?? (body['data'] as Map)['results'];
      final list = items is List ? items : <dynamic>[];
      dynamic total = body['total'];
      if (total == null && body['data'] is Map) total = (body['data'] as Map)['total'];
      return {'items': list, 'total': total is int ? total : (total is num ? total.toInt() : list.length)};
    }
    if (body is List) return {'items': body, 'total': body.length};
    throw ApiException(res.statusCode, 'Invalid response: expected object or list');
  }

  /// GET /workers/:id
  Future<Map<String, dynamic>> get(String workerId, {String? accessToken}) async {
    final res = await _client.withToken(accessToken).get('/workers/$workerId');
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }
}
