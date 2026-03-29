import '../core/api_client.dart';
import '../models/ward_weather.dart';

class WeatherRepository {
  WeatherRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  /// GET /weather/ward — returns ward weather & air quality. Pass wardId from login response.
  Future<WardWeather> getWardWeather({
    required String accessToken,
    required String wardId,
  }) async {
    final res = await _client.withToken(accessToken).get(
          '/weather/ward',
          queryParameters: {'ward_id': wardId},
        );
    if (!res.isOk) throw ApiException.fromResponse(res);
    final data = res.json as Map<String, dynamic>? ?? {};
    return WardWeather.fromJson(data);
  }
}
