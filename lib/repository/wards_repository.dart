import '../core/api_client.dart';
import '../models/ward.dart';

class WardsRepository {
  WardsRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// GET /wards/lookup?lat=&lng=
  Future<Ward?> lookupByCoordinates(double lat, double lng) async {
    final res = await _client.get(
      '/wards/lookup',
      queryParameters: {'lat': lat.toString(), 'lng': lng.toString()},
    );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json as Map<String, dynamic>? ?? {};
    if (data['found'] == true && data['ward'] != null) {
      return Ward.fromJson(data['ward']);
    }
    return null;
  }

  /// GET /zones
  Future<List<dynamic>> listZones() async {
    final res = await _client.get('/zones');
    if (!res.isOk) throw ApiException.fromResponse(res);
    final list = res.json;
    return list is List ? list : [];
  }

  /// GET /wards — optional zone_id
  Future<List<Ward>> listWards({String? zoneId}) async {
    final q = zoneId != null ? {'zone_id': zoneId} : null;
    final res = await _client.get('/wards', queryParameters: q);
    if (!res.isOk) throw ApiException.fromResponse(res);
    final list = res.json;
    if (list is List) {
      return list.map((e) => Ward.fromJson(e)).toList();
    }
    return [];
  }

  /// GET /wards/:id
  Future<Ward> getWard(String id) async {
    final res = await _client.get('/wards/$id');
    if (!res.isOk) throw ApiException.fromResponse(res);
    return Ward.fromJson(res.json as Map<String, dynamic>);
  }

  /// GET /departments
  Future<List<dynamic>> listDepartments() async {
    final res = await _client.get('/departments');
    if (!res.isOk) throw ApiException.fromResponse(res);
    final list = res.json;
    return list is List ? list : [];
  }

  /// GET /departments/:id/categories
  Future<List<dynamic>> listCategories(String departmentId) async {
    final res = await _client.get('/departments/$departmentId/categories');
    if (!res.isOk) throw ApiException.fromResponse(res);
    final list = res.json;
    return list is List ? list : [];
  }

  /// GET /categories (all categories with dept_name)
  Future<List<dynamic>> listAllCategories() async {
    final res = await _client.get('/categories');
    if (!res.isOk) throw ApiException.fromResponse(res);
    final list = res.json;
    return list is List ? list : [];
  }
}
