import 'package:url_launcher/url_launcher.dart';

/// Opens the system dialer with [raw] phone number (digits and leading + kept).
Future<void> launchPhoneDialer(String? raw) async {
  if (raw == null || raw.trim().isEmpty) return;
  final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
  if (digits.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: digits);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Opens Google Maps with directions to [lat], [lng] (works on iOS/Android via https).
Future<void> launchGoogleMapsDirections(double lat, double lng) async {
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
  );
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
