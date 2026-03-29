import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import '../repository/attendance_repository.dart';
import 'auth_provider.dart';
import 'offline_provider.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (ref) => AttendanceRepository(),
);

// ────────────────────────────────────────────────────────────────────────────
// State — Backend is the ONLY source of truth. UI state derived ONLY from API.
// No local persistence. No optimistic updates.
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
    final diff = DateTime.now().difference(clockInTime!);
    // Clock skew / timezone quirks can make this negative; never show negative shift.
    if (diff.isNegative) return Duration.zero;
    return diff;
  }

  String get dutyDurationFormatted {
    final d = dutyDuration;
    final total = d.inSeconds;
    final h = (total ~/ 3600).toString().padLeft(2, '0');
    final m = ((total % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (total % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// For KPI cards — avoid `inMinutes / 60` (truncates to whole minutes → confusing 0.0 right after clock-in).
  double get dutyDurationHoursExact =>
      dutyDuration.inSeconds / 3600.0;

  /// Short label for shift summary, e.g. `45s`, `12m`, `1h 05m`.
  String get dutyDurationShortLabel {
    final sec = dutyDuration.inSeconds;
    if (sec < 60) return '${sec}s';
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
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
// Notifier — State changes ONLY from backend API responses. Non-negotiable.
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

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// Fetch status from backend. When offline, check local storage for pending clock-in.
  Future<void> fetchStatus() async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return;
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      final storage = ref.read(offlineStorageProvider);
      final local = await storage.getLocalClockIn();
      if (local != null) {
        final clockInStr = local['clock_in_time'] as String?;
        final clockInTime = clockInStr != null ? DateTime.tryParse(clockInStr) : null;
        final lat = (local['lat'] as num?)?.toDouble();
        final lng = (local['lng'] as num?)?.toDouble();
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
      }
      return;
    }
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
        _positionSub?.cancel();
        _ticker?.cancel();
        return;
      }

      final clockInStr = record['clock_in_time'] as String?;
      final clockInTime = clockInStr != null ? DateTime.tryParse(clockInStr) : null;
      final lat = (record['clock_in_lat'] is num) ? (record['clock_in_lat'] as num).toDouble() : null;
      final lng = (record['clock_in_lng'] is num) ? (record['clock_in_lng'] as num).toDouble() : null;

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

  Future<void> fetchHistory({DateTime? fromDate, DateTime? toDate}) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final data = await ref.read(attendanceRepositoryProvider).history(
            token,
            fromDate: fromDate,
            toDate: toDate,
          );
      state = state.copyWith(history: data);
    } catch (_) {}
  }

  /// Clock in. When offline, store locally and show optimistic state.
  Future<void> clockIn() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'Not authenticated');
      return;
    }
    final isOnline = ref.read(isOnlineProvider);
    try {
      final pos = await _getPosition();
      if (!isOnline) {
        await ref.read(offlineStorageProvider).setLocalClockIn(
          clockInTime: DateTime.now().toUtc().toIso8601String(),
          lat: pos.latitude,
          lng: pos.longitude,
        );
        _applyClockInFromBackend({
          'clock_in_time': DateTime.now().toUtc().toIso8601String(),
        }, pos);
        _startTracking();
        state = state.copyWith(isLoading: false);
        return;
      }
      final data = await ref.read(attendanceRepositoryProvider).clockIn(
            accessToken: token,
            lat: pos.latitude,
            lng: pos.longitude,
          );
      _applyClockInFromBackend(data, pos);
      _startTracking();
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false);
      if (e.statusCode == 409) {
        state = state.copyWith(error: 'Already clocked in today');
        await fetchStatus();
      } else {
        state = state.copyWith(error: e.userMessage);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Clock out. When offline, add to sync queue and clear local state.
  Future<void> clockOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'Not authenticated');
      return;
    }
    final isOnline = ref.read(isOnlineProvider);
    try {
      final pos = await _getPosition();
      if (!isOnline) {
        await ref.read(offlineStorageProvider).addToSyncQueue({
          'type': 'clock_out',
          'lat': pos.latitude,
          'lng': pos.longitude,
        });
        await ref.read(offlineStorageProvider).clearLocalClockIn();
        _positionSub?.cancel();
        _ticker?.cancel();
        state = const AttendanceState();
        return;
      }
      await _doClockOut(token, pos);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _doClockOut(String token, Position pos) async {
    const maxAttempts = 2;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        await ref.read(attendanceRepositoryProvider).clockOut(
              accessToken: token,
              lat: pos.latitude,
              lng: pos.longitude,
            );
        // Success: backend confirmed. Clear state.
        _positionSub?.cancel();
        _ticker?.cancel();
        state = const AttendanceState();
        return;
      } on ApiException catch (e) {
        if (e.statusCode == 404 && attempt < maxAttempts) {
          // Brief delay then retry (handles eventual consistency)
          await Future<void>.delayed(const Duration(milliseconds: 800));
          continue;
        }
        state = state.copyWith(isLoading: false);
        if (e.statusCode == 404) {
          state = state.copyWith(error: 'No active clock-in found');
          await fetchStatus();
        } else {
          state = state.copyWith(error: e.userMessage);
        }
        return;
      }
    }
  }

  void _applyClockInFromBackend(Map<String, dynamic> data, Position pos) {
    final clockInStr = data['clock_in_time'] as String?;
    final clockInTime = clockInStr != null ? DateTime.tryParse(clockInStr) : null;
    state = state.copyWith(
      isClockedIn: true,
      clockInTime: clockInTime ?? DateTime.now(),
      clockInLocation: pos,
      currentLocation: pos,
      isLoading: false,
    );
  }

  double distanceTo(double lat, double lng) {
    final loc = state.currentLocation;
    if (loc == null) return double.infinity;
    return Geolocator.distanceBetween(loc.latitude, loc.longitude, lat, lng);
  }

  bool isAtSite(double lat, double lng, {double threshold = 10.0}) {
    return distanceTo(lat, lng) <= threshold;
  }

  Future<Position> _getPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) throw 'Location services are disabled. Please enable GPS.';
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) throw 'Location permission denied.';
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied.';
    }
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
    );
  }

  void _startTracking() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((pos) {
      state = state.copyWith(currentLocation: pos);
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isClockedIn) state = state.copyWith();
    });
  }
}

final attendanceProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(AttendanceNotifier.new);
