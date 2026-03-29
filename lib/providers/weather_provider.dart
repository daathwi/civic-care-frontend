import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../models/ward_weather.dart';
import '../providers/auth_provider.dart';
import '../repository/weather_repository.dart';

/// Short, user-facing text when [wardWeatherProvider] fails (avoid raw [ApiException.toString]).
String weatherLoadErrorMessage(Object error) {
  if (error is ApiException) {
    final m = error.message;
    if (error.statusCode >= 500) {
      if (m.toLowerCase().contains('weather')) {
        return 'Forecast service is temporarily unavailable. Tap to retry.';
      }
      return error.userMessage;
    }
    if (error.statusCode == 0) {
      return m.isNotEmpty ? m : 'Check your connection and try again.';
    }
    return m.isNotEmpty ? m : error.userMessage;
  }
  final raw = error.toString();
  if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
    return 'No internet connection. Try again when you’re online.';
  }
  return raw.length > 140 ? '${raw.substring(0, 140)}…' : raw;
}

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository();
});

/// Ward weather & air quality. Returns null if no ward or API error.
final wardWeatherProvider = FutureProvider<WardWeather?>((ref) async {
  final auth = ref.watch(authProvider);
  final token = auth.accessToken;
  // Use effectiveUser so staff in citizen portal still get their ward
  final user = ref.watch(effectiveUserProvider) ?? auth.user;

  if (token == null || token.isEmpty) {
    if (kDebugMode) debugPrint('[Weather] No token, skipping');
    return null;
  }

  // Ward: citizen has user.wardId, staff has worker_profile.ward_id (both in user.wardId)
  final wardId = user?.wardId;
  if (wardId == null || wardId.isEmpty) {
    if (kDebugMode) debugPrint('[Weather] No wardId for user ${user?.id}, skipping');
    return null;
  }

  try {
    final repo = ref.read(weatherRepositoryProvider);
    final data = await repo.getWardWeather(accessToken: token, wardId: wardId);
    if (kDebugMode) debugPrint('[Weather] Loaded for ward ${data.wardName}');
    return data;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[Weather] API error: $e');
      debugPrint('[Weather] Stack: $st');
    }
    rethrow; // Surface error so UI can show retry
  }
});
