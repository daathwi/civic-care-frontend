import 'package:shared_preferences/shared_preferences.dart';

/// Compile-time default. 10.0.2.2 = Android emulator's alias for host.
const String _defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8000',
);

const String apiPrefix = '/api/v1';

const String _keyApiBaseUrl = 'api_base_url';
const String _keyApiUrlConfigured = 'api_url_configured';

/// Runtime override (e.g. your PC IP). Call [loadApiBaseUrlOverride] at startup.
String? _apiBaseUrlOverride;

/// Call from main() before runApp so API uses saved override (e.g. http://192.168.1.5:8000).
Future<void> loadApiBaseUrlOverride() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    _apiBaseUrlOverride = prefs.getString(_keyApiBaseUrl);
  } catch (_) {
    _apiBaseUrlOverride = null;
  }
}

/// Whether user has passed the API URL screen (so we show login next time).
Future<bool> getApiUrlConfigured() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyApiUrlConfigured) ?? false;
  } catch (_) {
    return false;
  }
}

/// Call after user taps Continue on API URL screen.
Future<void> setApiUrlConfigured(bool value) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyApiUrlConfigured, value);
  } catch (_) {}
}

/// Current base URL: saved override, or compile-time default.
String get apiBaseUrl => _apiBaseUrlOverride ?? _defaultApiBaseUrl;

/// Convert a server-relative path (e.g. `/photos/grievances/abc.jpg`) to a full
/// URL reachable from the device. Already-absolute URLs are returned as-is.
String toFullPhotoUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  final base = apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
  final rel = path.startsWith('/') ? path : '/$path';
  return '$base$rel';
}

/// Save a custom base URL (e.g. for "Connection refused" fix: use your PC's IP).
Future<void> setApiBaseUrlOverride(String? url) async {
  _apiBaseUrlOverride = url;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (url == null) {
      await prefs.remove(_keyApiBaseUrl);
    } else {
      await prefs.setString(_keyApiBaseUrl, url);
    }
  } catch (_) {}
}
