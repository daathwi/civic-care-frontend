import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../repository/attendance_repository.dart';
import 'auth_provider.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(),
);

// ────────────────────────────────────────────────────────────────────────────
// State
// ────────────────────────────────────────────────────────────────────────────

class AttendanceState {
  final bool isClockedIn;
  final DateTime? clockInTime;
  final Position? clockInLocation;
  final Position? currentLocation;
  final List<dynamic> history;
  final bool isLoading;
  final String? error;

  const AttendanceState({
    this.isClockedIn = false,
    this.clockInTime,
    this.clockInLocation,
    this.currentLocation,
    this.history = const [],
    this.isLoading = false,
    this.error,
  });

  Duration get dutyDuration {
    if (!isClockedIn || clockInTime == null) return Duration.zero;
    return DateTime.now().difference(clockInTime!);
  }

  String get dutyDurationFormatted {
    final d = dutyDuration;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  AttendanceState copyWith({
    bool? isClockedIn,
    DateTime? clockInTime,
    Position? clockInLocation,
    Position? currentLocation,
    List<dynamic>? history,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AttendanceState(
      isClockedIn: isClockedIn ?? this.isClockedIn,
      clockInTime: clockInTime ?? this.clockInTime,
      clockInLocation: clockInLocation ?? this.clockInLocation,
      currentLocation: currentLocation ?? this.currentLocation,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Notifier
// ────────────────────────────────────────────────────────────────────────────

class AttendanceNotifier extends Notifier<AttendanceState> {
  StreamSubscription<Position>? _positionSub;
  Timer? _ticker;

  @override
  AttendanceState build() {
    ref.onDispose(() {
      _positionSub?.cancel();
      _ticker?.cancel();
    });
    return const AttendanceState();
  }

  // ── Public actions ──────────────────────────────────────────────────────

  /// Sync with backend (e.g. on dashboard load) so UI shows Clock in vs Clock out correctly.
  Future<void> fetchStatus() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final data = await ref.read(attendanceRepositoryProvider).status(token);
      final isClockedIn = data['is_clocked_in'] as bool? ?? false;
      final record = data['current_record'] as Map<String, dynamic>?;
      if (!isClockedIn || record == null) {
        state = state.copyWith(
          isClockedIn: false,
          clockInTime: null,
          clockInLocation: null,
        );
        return;
      }
      final clockInStr = record['clock_in_time'] as String?;
      final clockInTime = clockInStr != null
          ? DateTime.tryParse(clockInStr)
          : null;
      final lat = (record['clock_in_lat'] is num)
          ? (record['clock_in_lat'] as num).toDouble()
          : null;
      final lng = (record['clock_in_lng'] is num)
          ? (record['clock_in_lng'] as num).toDouble()
          : null;
      Position? pos;
      if (lat != null && lng != null) {
        pos = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
      state = state.copyWith(
        isClockedIn: true,
        clockInTime: clockInTime ?? DateTime.now(),
        clockInLocation: pos,
        currentLocation: pos,
      );
      _startTracking();
    } catch (_) {}
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> fetchHistory() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final data = await ref.read(attendanceRepositoryProvider).history(token);
      state = state.copyWith(history: data);
    } catch (_) {}
  }

  Future<void> clockIn() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final pos = await _getPosition();
      final token = ref.read(authProvider).accessToken;
      if (token == null || token.isEmpty) {
        state = state.copyWith(isLoading: false, error: 'Not authenticated');
        return;
      }
      final data = await ref
          .read(attendanceRepositoryProvider)
          .clockIn(accessToken: token, lat: pos.latitude, lng: pos.longitude);
      final clockInStr = data['clock_in_time'] as String?;
      final backendTime = clockInStr != null
          ? DateTime.tryParse(clockInStr)
          : null;
      state = state.copyWith(
        isClockedIn: true,
        clockInTime: backendTime ?? DateTime.now(),
        clockInLocation: pos,
        currentLocation: pos,
        isLoading: false,
      );
      _startTracking();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false);
      if (e.statusCode == 409) {
        state = state.copyWith(error: 'Already clocked in today');
        await fetchStatus();
      } else {
        state = state.copyWith(error: e.message);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> clockOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final token = ref.read(authProvider).accessToken;
    if (token == null || state.clockInLocation == null) {
      state = state.copyWith(
        isLoading: false,
        error: 'Cannot clock out: missing data',
      );
      return;
    }
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .clockOut(
            accessToken: token,
            lat:
                state.currentLocation?.latitude ??
                state.clockInLocation!.latitude,
            lng:
                state.currentLocation?.longitude ??
                state.clockInLocation!.longitude,
          );
      _positionSub?.cancel();
      _ticker?.cancel();
      state = const AttendanceState();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Proximity utilities ─────────────────────────────────────────────────

  /// Returns distance in meters between the worker's current position and
  /// the given coordinates. Returns [double.infinity] if location is unknown.
  double distanceTo(double lat, double lng) {
    final loc = state.currentLocation;
    if (loc == null) return double.infinity;
    return Geolocator.distanceBetween(loc.latitude, loc.longitude, lat, lng);
  }

  /// Returns true if the worker is within [threshold] meters of the site.
  bool isAtSite(double lat, double lng, {double threshold = 10.0}) {
    return distanceTo(lat, lng) <= threshold;
  }

  // ── Private helpers ─────────────────────────────────────────────────────

  Future<Position> _getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled. Please enable GPS.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission denied.';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied.';
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
      ),
    );
  }

  void _startTracking() {
    _positionSub?.cancel();
    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3, // update every 3 meters moved
          ),
        ).listen((pos) {
          state = state.copyWith(currentLocation: pos);
        });

    // Drive the duty-duration timer every second
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isClockedIn) {
        // Trigger a rebuild by emitting a tiny state update
        state = state.copyWith();
      }
    });
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Provider
// ────────────────────────────────────────────────────────────────────────────

final attendanceProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(
      AttendanceNotifier.new,
    );
