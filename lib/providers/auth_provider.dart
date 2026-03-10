import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../models/user_models.dart';
import '../repository/auth_repository.dart';
import '../repository/wards_repository.dart';
import '../models/ward.dart';

const String _keyAuthSession = 'auth_session';

class AuthState {
  final UserProfile? user;
  final String? accessToken;
  final String? refreshToken;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isLoading = false,
    this.error,
  });

  bool get isAuthenticated => user != null && accessToken != null;

  AuthState copyWith({
    UserProfile? user,
    String? accessToken,
    String? refreshToken,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

UserRole _roleFromString(String? v) {
  switch (v?.toLowerCase()) {
    case 'citizen':
      return UserRole.citizen;
    case 'fieldmanager':
      return UserRole.fieldManager;
    case 'fieldassistant':
      return UserRole.fieldAssistant;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.citizen;
  }
}

UserProfile _userFromMap(Map<String, dynamic> m) {
  final id = m['id'] as String? ?? '';
  final name = m['name'] as String? ?? '';
  final email = m['email'] as String?;
  final phone = m['phone'] as String? ?? '';
  final address = m['address'] as String?;
  final role = _roleFromString(m['role'] as String?);
  final ward = m['ward'] as String?;
  final zone = m['zone'] as String?;
  final wp = m['worker_profile'] as Map<String, dynamic>?;
  final staffWard = wp?['ward_display'] as String?;
  final wardDisplay = staffWard ?? ward ?? zone ?? '';

  Department? dept;
  String? departmentId;
  String? wardId;
  if (wp != null) {
    final deptIdRaw = wp['department_id'] as String?;
    if (deptIdRaw != null && deptIdRaw.toString().trim().isNotEmpty) {
      departmentId = deptIdRaw.toString().trim();
    }
    final wardIdRaw = wp['ward_id'];
    if (wardIdRaw != null && wardIdRaw.toString().trim().isNotEmpty) {
      wardId = wardIdRaw.toString().trim();
    }
    final deptMap = wp['department'] as Map<String, dynamic>?;
    if (deptMap != null &&
        (deptMap['name'] != null || deptMap['short_code'] != null)) {
      try {
        dept = Department.all.firstWhere(
          (d) =>
              d.name == deptMap['name'] ||
              d.shortCode == (deptMap['short_code'] as String?),
        );
      } catch (_) {}
    }
  }
  if (dept == null && role != UserRole.citizen) {
    dept = Department.sanitation;
  }

  // For staff, ward is from worker_profile.ward_display (or empty); for citizens, fall back to zone/dept for display
  final wardValue = wardDisplay.isNotEmpty
      ? wardDisplay
      : (wp != null ? '' : (dept?.name ?? ''));

  return UserProfile(
    id: id,
    name: name,
    email: email,
    ward: wardValue,
    phone: phone,
    address: address,
    role: role,
    department: dept,
    departmentId: departmentId,
    wardId: wardId ?? m['ward_id'] as String?,
    zoneId: m['zone_id'] as String?,
    tasksCompleted: wp?['tasks_completed'] as int? ?? 0,
    tasksActive: wp?['tasks_active'] as int? ?? 0,
  );
}

/// Reconstruct a [UserProfile] from the flat map stored by [UserProfile.toMap].
UserProfile _userProfileFromStoredMap(Map<String, dynamic> m) {
  final role = _roleFromString(m['role'] as String?);

  // Try to match a known Department by name.
  Department? dept;
  final deptName = m['department_name'] as String?;
  if (deptName != null) {
    try {
      dept = Department.all.firstWhere((d) => d.name == deptName);
    } catch (_) {}
  }
  if (dept == null && role != UserRole.citizen) {
    dept = Department.sanitation;
  }

  return UserProfile(
    id: m['id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    email: m['email'] as String?,
    ward: m['ward'] as String? ?? '',
    phone: m['phone'] as String? ?? '',
    address: m['address'] as String?,
    role: role,
    department: dept,
    departmentId: m['department_id'] as String?,
    wardId: m['ward_id'] as String?,
    zoneId: m['zone_id'] as String?,
    tasksCompleted: m['tasks_completed'] as int? ?? 0,
    tasksActive: m['tasks_active'] as int? ?? 0,
  );
}

/// True if string looks like a UUID.
bool _isUuid(String s) {
  final u = s.trim();
  if (u.length != 36) return false;
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(u);
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState();

  /// Restore session from SharedPreferences on app startup.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyAuthSession);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final userMap = map['user'] as Map<String, dynamic>?;
      if (userMap == null) return;
      final user = _userProfileFromStoredMap(userMap);
      state = state.copyWith(
        user: user,
        accessToken: map['access_token'] as String?,
        refreshToken: map['refresh_token'] as String?,
      );
      _resolveWardId();
    } catch (_) {
      // Corrupted session — ignore and start fresh.
    }
  }

  Future<void> _persistSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = <String, dynamic>{
        'user': state.user?.toMap(),
        'access_token': state.accessToken,
        'refresh_token': state.refreshToken,
      };
      await prefs.setString(_keyAuthSession, jsonEncode(map));
    } catch (_) {}
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthSession);
    } catch (_) {}
  }

  Future<void> login(
    String phoneOrUserId,
    String password, {
    Department? department,
    String? departmentId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final isStaff = _isUuid(phoneOrUserId);
      final deptId = departmentId ?? department?.id;
      AuthResult result;
      if (isStaff) {
        result = await repo.login(
          userId: phoneOrUserId,
          password: password,
          department: deptId,
        );
      } else {
        result = await repo.login(
          phone: phoneOrUserId,
          password: password,
          department: deptId,
        );
      }
      final user = _userFromMap(result.user);
      state = state.copyWith(
        user: user,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        isLoading: false,
        clearError: true,
      );
      _resolveWardId();
      _persistSession();
    } on ApiValidationException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } on ApiException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.statusCode == 401 ? 'Invalid credentials' : e.userMessage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().length > 120
            ? '${e.toString().substring(0, 120)}...'
            : e.toString(),
      );
    }
  }

  Future<void> register(
    String name,
    String phone,
    String password, {
    String? email,
    String? address,
    String? zoneId,
    String? wardId,
    int? wardNumber,
    double? lat,
    double? lng,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(authRepositoryProvider);
      final result = await repo.register(
        name: name,
        phone: phone,
        password: password,
        email: email,
        address: address,
        zoneId: zoneId,
        wardId: wardId,
        wardNumber: wardNumber,
        lat: lat,
        lng: lng,
      );
      final user = _userFromMap(result.user);
      state = state.copyWith(
        user: user,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        isLoading: false,
        clearError: true,
      );
      _resolveWardId();
      _persistSession();
    } on ApiValidationException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.userMessage);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().length > 120
            ? '${e.toString().substring(0, 120)}...'
            : e.toString(),
      );
    }
  }

  void logout() {
    state = AuthState();
    ref.read(currentPortalProvider.notifier).state = null;
    _clearSession();
  }

  /// Automatically resolve ward_id/zone_id from names if they are null.
  Future<void> _resolveWardId() async {
    final user = state.user;
    if (user == null) return;
    if (user.role != UserRole.citizen) {
      return; // Staff usually have IDs from backend
    }
    if (user.wardId != null && user.zoneId != null) return;

    try {
      final repo = WardsRepository();
      String? matchedZoneId;
      if (user.zoneId != null) {
        matchedZoneId = user.zoneId;
      }

      final wards = await repo.listWards(zoneId: matchedZoneId);

      final matchedWard = wards.firstWhere(
        (w) =>
            w.name.toUpperCase() ==
            user.ward.toUpperCase().trim(),
        orElse: () => const Ward(id: '', name: '', number: 0),
      );

      if (matchedWard.id.isNotEmpty) {
        final newWardId = matchedWard.id;
        final newZoneId = matchedWard.zoneId;

        if (newWardId != user.wardId || newZoneId != user.zoneId) {
          state = state.copyWith(
            user: user.copyWith(
              wardId: newWardId,
              zoneId: newZoneId ?? user.zoneId,
            ),
          );
          _persistSession();
        }
      }
    } catch (_) {
      // Best effort lookup failed
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

// ---------------------------------------------------------------------------
// Portal mode: staff can switch between citizen and department portal.
// In citizen portal, worker profile is hidden (effectiveUser has no department).
// ---------------------------------------------------------------------------

enum PortalMode { citizen, department }

final currentPortalProvider = StateProvider<PortalMode?>((ref) => null);

/// When true, LoginScreen opens with Department tab selected (e.g. after tapping "Department" in drawer).
final initialLoginAsDepartmentProvider = StateProvider<bool>((ref) => false);

/// Effective portal for display: citizens always citizen; staff use currentPortal (default department).
PortalMode effectivePortal(PortalMode? current, UserRole role) {
  if (role == UserRole.citizen) return PortalMode.citizen;
  return current ?? PortalMode.department;
}

/// User to display in UI. In citizen portal, staff see themselves without department (no worker profile).
final effectiveUserProvider = Provider<UserProfile?>((ref) {
  final auth = ref.watch(authProvider);
  final user = auth.user;
  if (user == null) return null;
  final current = ref.watch(currentPortalProvider);
  final portal = effectivePortal(current, user.role);
  if (portal == PortalMode.citizen && user.isStaff) {
    return user.copyWith(clearDepartment: true);
  }
  return user;
});

/// Full user details from API (GET /auth/me). Use for profile screen to show email, zone, created_at, etc.
final profileDetailsProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final auth = ref.watch(authProvider);
  final token = auth.accessToken;
  if (token == null || token.isEmpty) return null;
  try {
    final repo = ref.read(authRepositoryProvider);
    return await repo.me(token);
  } catch (_) {
    return null;
  }
});
