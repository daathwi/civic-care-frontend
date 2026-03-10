import '../core/api_client.dart';

/// Auth API results. Tokens and user map from backend.
class AuthResult {
  AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;
}

class AuthRepository {
  AuthRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// POST /auth/register
  Future<AuthResult> register({
    required String name,
    required String phone,
    required String password,
    String? email,
    String? address,
    String? zoneId,
    String? wardId,
    int? wardNumber,
    double? lat,
    double? lng,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'phone': phone,
      'password': password,
      'confirm_password': password,
    };
    if (email != null) body['email'] = email;
    if (address != null) body['address'] = address;
    if (zoneId != null) body['zone_id'] = zoneId;
    if (wardId != null) body['ward_id'] = wardId;
    if (wardNumber != null) body['ward_number'] = wardNumber;
    if (lat != null) body['lat'] = lat;
    if (lng != null) body['lng'] = lng;

    final res = await _client.post('/auth/register', body: body);
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json as Map<String, dynamic>?;
    if (data == null) throw ApiException(res.statusCode, 'Invalid response');

    final user = data['user'] as Map<String, dynamic>? ?? {};
    final tokens = data['tokens'] as Map<String, dynamic>? ?? {};
    return AuthResult(
      accessToken: tokens['access_token'] as String? ?? '',
      refreshToken: tokens['refresh_token'] as String? ?? '',
      user: user,
    );
  }

  /// POST /auth/login — citizen: phone + password; staff: user_id or phone + password. Optional department UUID.
  Future<AuthResult> login({
    String? phone,
    String? userId,
    required String password,
    String? department,
  }) async {
    if (phone == null && userId == null) {
      throw ApiException(400, 'Provide phone or user_id');
    }
    final body = <String, dynamic>{
      'password': password,
    };
    if (phone != null) body['phone'] = phone;
    if (userId != null) body['user_id'] = userId;
    if (department != null) body['department'] = department;

    final res = await _client.post('/auth/login', body: body);
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json as Map<String, dynamic>?;
    if (data == null) throw ApiException(res.statusCode, 'Invalid response');

    final user = data['user'] as Map<String, dynamic>? ?? {};
    final tokens = data['tokens'] as Map<String, dynamic>? ?? {};
    return AuthResult(
      accessToken: tokens['access_token'] as String? ?? '',
      refreshToken: tokens['refresh_token'] as String? ?? '',
      user: user,
    );
  }

  /// POST /auth/refresh
  Future<AuthResult> refresh(String refreshToken) async {
    final res = await _client.post('/auth/refresh', body: {'refresh_token': refreshToken});
    if (!res.isOk) throw ApiException(res.statusCode, res.body ?? '');
    final data = res.json as Map<String, dynamic>?;
    if (data == null) throw ApiException(res.statusCode, 'Invalid response');

    final tokens = data;
    final accessToken = tokens['access_token'] as String? ?? '';
    final newRefresh = tokens['refresh_token'] as String? ?? '';
    // /auth/refresh returns TokenResponse only; get user via /auth/me with new access token
    final meClient = _client.withToken(accessToken);
    final meRes = await meClient.get('/auth/me');
    if (!meRes.isOk) throw ApiException(meRes.statusCode, meRes.body ?? '');
    final user = meRes.json as Map<String, dynamic>? ?? {};
    return AuthResult(accessToken: accessToken, refreshToken: newRefresh, user: user);
  }

  /// GET /auth/me — requires Bearer. Returns full user details.
  Future<Map<String, dynamic>> me(String accessToken) async {
    final res = await _client.withToken(accessToken).get('/auth/me');
    if (!res.isOk) throw ApiException(res.statusCode, res.body ?? '');
    final data = res.json as Map<String, dynamic>?;
    return data ?? {};
  }

  /// GET /auth/users/{user_id} — requires Bearer. Same user or admin/manager. Returns full user details.
  Future<Map<String, dynamic>> getUserById(String accessToken, String userId) async {
    final res = await _client.withToken(accessToken).get('/auth/users/$userId');
    if (!res.isOk) throw ApiException(res.statusCode, res.body ?? '');
    final data = res.json as Map<String, dynamic>?;
    return data ?? {};
  }
}
