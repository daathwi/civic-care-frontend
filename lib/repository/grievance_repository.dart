import 'dart:io';

import '../core/api_client.dart';

class GrievanceRepository {
  GrievanceRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  ApiClient _auth(String? token) => _client.withToken(token);

  /// Upload a photo file to the backend. Returns the server URL for the uploaded file.
  Future<String> uploadGrievancePhoto({
    required String accessToken,
    required File file,
  }) async {
    final res = await _auth(
      accessToken,
    ).uploadFile('/upload/grievance-photo', file);
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json as Map<String, dynamic>? ?? {};
    return data['url'] as String? ?? '';
  }

  /// Upload a resolution proof photo. Returns the server URL.
  Future<String> uploadResolutionPhoto({
    required String accessToken,
    required File file,
  }) async {
    final res = await _auth(
      accessToken,
    ).uploadFile('/upload/resolution-photo', file);
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json as Map<String, dynamic>? ?? {};
    return data['url'] as String? ?? '';
  }

  /// Upload a voice recording. Returns the server URL.
  Future<String> uploadGrievanceAudio({
    required String accessToken,
    required File file,
  }) async {
    final res = await _auth(
      accessToken,
    ).uploadFile('/upload/grievance-audio', file);
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json as Map<String, dynamic>? ?? {};
    return data['url'] as String? ?? '';
  }

  /// GET /grievances — optional: ward_id, ward_name, status, priority, category_dept, reporter_id, skip, limit
  Future<Map<String, dynamic>> list({
    String? accessToken,
    String? wardId,
    String? status,
    String? priority,
    String? categoryDept,
    String? reporterId,
    String? workerId,
    int skip = 0,
    int limit = 10,
  }) async {
    final q = <String, String>{'skip': '$skip', 'limit': '$limit'};
    if (wardId != null) q['ward_id'] = wardId;
    // REMOVED: ward_name filter (Strict ID filtering)
    if (status != null) q['status'] = status;
    if (priority != null) q['priority'] = priority;
    if (categoryDept != null) q['category_dept'] = categoryDept;
    if (reporterId != null) q['reporter_id'] = reporterId;
    if (workerId != null) q['worker_id'] = workerId;

    final res = await _auth(accessToken).get('/grievances', queryParameters: q);
    if (!res.isOk) throw ApiException.fromResponse(res);
    return _parsePaginatedList(res);
  }

  static Map<String, dynamic> _parsePaginatedList(ApiResponse res) {
    final body = res.json;
    if (body == null) {
      throw ApiException(
        res.statusCode,
        'Invalid response: empty or non-JSON body',
      );
    }
    if (body is Map<String, dynamic>) {
      dynamic items = body['items'] ?? body['results'];
      if (items == null && body['data'] is Map) {
        final data = body['data'] as Map;
        items = data['items'] ?? data['results'];
      }
      final list = items is List ? items : <dynamic>[];
      dynamic total = body['total'];
      if (total == null && body['data'] is Map) {
        total = (body['data'] as Map)['total'];
      }
      return {
        'items': list,
        'total': total is int
            ? total
            : (total is num ? total.toInt() : list.length),
      };
    }
    if (body is List) return {'items': body, 'total': body.length};
    throw ApiException(
      res.statusCode,
      'Invalid response: expected object or list',
    );
  }

  /// POST /grievances — requires auth. Send department_id first; category_id must belong to that department.
  Future<Map<String, dynamic>> create({
    required String? accessToken,
    required String title,
    String? description,
    required double lat,
    required double lng,
    String? address,
    String priority = 'medium',
    String? departmentId,
    String? categoryId,
    String? wardId,
    List<String> mediaUrls = const [],
    bool isSensitive = false,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      'lat': lat,
      'lng': lng,
      'priority': priority,
      'media_urls': mediaUrls,
      'is_sensitive': isSensitive,
    };
    if (description != null) body['description'] = description;
    if (address != null) body['address'] = address;
    if (departmentId != null) body['department_id'] = departmentId;
    if (categoryId != null) body['category_id'] = categoryId;
    if (wardId != null) body['ward_id'] = wardId;

    final res = await _auth(accessToken).post('/grievances', body: body);
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  /// GET /grievances/:id
  Future<Map<String, dynamic>> get(
    String grievanceId, {
    String? accessToken,
  }) async {
    final res = await _auth(accessToken).get('/grievances/$grievanceId');
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  /// PATCH /grievances/:id — status, priority, resolution_image_url, note
  Future<Map<String, dynamic>> update(
    String grievanceId, {
    required String? accessToken,
    String? status,
    String? priority,
    String? resolutionImageUrl,
    String? note,
  }) async {
    final body = <String, dynamic>{};
    if (status != null) body['status'] = status;
    if (priority != null) body['priority'] = priority;
    if (resolutionImageUrl != null) {
      body['resolution_image_url'] = resolutionImageUrl;
    }
    if (note != null) body['note'] = note;

    final res = await _auth(
      accessToken,
    ).patch('/grievances/$grievanceId', body: body.isNotEmpty ? body : null);
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  /// POST /grievances/:id/assign — body: worker_id
  Future<Map<String, dynamic>> assign(
    String grievanceId, {
    required String? accessToken,
    required String workerId,
  }) async {
    final res = await _auth(
      accessToken,
    ).post('/grievances/$grievanceId/assign', body: {'worker_id': workerId});
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  /// POST /grievances/:id/vote — body: vote_type (1, -1, 0)
  Future<Map<String, dynamic>> vote(
    String grievanceId, {
    required String? accessToken,
    required int voteType,
  }) async {
    final res = await _auth(
      accessToken,
    ).post('/grievances/$grievanceId/vote', body: {'vote_type': voteType});
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  /// GET /grievances/:id/comments
  Future<List<dynamic>> listComments(
    String grievanceId, {
    String? accessToken,
  }) async {
    final res = await _auth(
      accessToken,
    ).get('/grievances/$grievanceId/comments');
    if (!res.isOk) throw ApiException.fromResponse(res);
    final list = res.json;
    return list is List ? list : [];
  }

  /// POST /grievances/:id/comments — body: text
  Future<Map<String, dynamic>> addComment(
    String grievanceId, {
    required String? accessToken,
    required String text,
  }) async {
    final res = await _auth(
      accessToken,
    ).post('/grievances/$grievanceId/comments', body: {'text': text});
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }

  /// POST /grievances/:id/rate — body: rating (1-5). Only original reporter.
  Future<Map<String, dynamic>> rate(
    String grievanceId, {
    required String? accessToken,
    required int rating,
  }) async {
    final res = await _auth(
      accessToken,
    ).post('/grievances/$grievanceId/rate', body: {'rating': rating});
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.json as Map<String, dynamic>? ?? {};
  }
}
