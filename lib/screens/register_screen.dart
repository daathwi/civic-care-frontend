import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';
import '../repository/wards_repository.dart';
import '../models/ward.dart';
import '../core/app_theme.dart';
import '../widgets/app_logo.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _wardsRepoProvider = Provider<WardsRepository>(
  (ref) => WardsRepository(),
);

final _zonesListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final repo = ref.watch(_wardsRepoProvider);
  final list = await repo.listZones();
  return list.cast<Map<String, dynamic>>();
});

final _selectedZoneIdProvider = StateProvider<String?>((ref) => null);

final _wardListProvider = FutureProvider<List<Ward>>((ref) async {
  final zoneId = ref.watch(_selectedZoneIdProvider);
  if (zoneId == null) return [];
  final repo = ref.watch(_wardsRepoProvider);
  return await repo.listWards(zoneId: zoneId);
});

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kTotalSteps = 3;

const _stepTitles = ['Personal Info', 'Location', 'Security'];
const _stepSubtitles = [
  'Tell us about yourself',
  'Where do you live?',
  'Secure your account',
];
const _stepIcons = [
  Icons.person_outline,
  Icons.location_on_outlined,
  Icons.lock_outline,
];

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
  String? errorText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: Colors.grey[400]),
    errorText: errorText,
    suffixIcon: suffixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.9),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();

  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _addressCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmPasswordCtl = TextEditingController();

  String? _selectedZoneId;
  String? _selectedWardId;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool _isInWardCompound = false;
  bool _locationLoading = false;
  String? _locationError;

  int _currentStep = 0;

  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _addressCtl.dispose();
    _passwordCtl.dispose();
    _confirmPasswordCtl.dispose();
    super.dispose();
  }

  GlobalKey<FormState> get _currentFormKey {
    switch (_currentStep) {
      case 0:
        return _step1Key;
      case 1:
        return _step2Key;
      default:
        return _step3Key;
    }
  }

  void _goNext() {
    if (!_currentFormKey.currentState!.validate()) return;
    if (_currentStep < _kTotalSteps - 1) {
      setState(() => _currentStep++);
    } else {
      _handleRegister();
    }
  }

  void _goBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _handleRegister() async {
    setState(() {
      _nameError = null;
      _emailError = null;
      _phoneError = null;
      _passwordError = null;
    });

    await ref
        .read(authProvider.notifier)
        .register(
          _nameCtl.text.trim(),
          _phoneCtl.text.trim(),
          _passwordCtl.text,
          email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
          address: _addressCtl.text.trim().isEmpty
              ? null
              : _addressCtl.text.trim(),
          zoneId: _selectedZoneId,
          wardId: _selectedWardId,
        );

    if (!mounted) return;
    final authState = ref.read(authProvider);

    if (authState.error != null) {
      final err = authState.error!;
      if (err.contains('email')) {
        setState(() {
          _emailError = err;
          _currentStep = 0;
        });
      } else if (err.contains('phone')) {
        setState(() {
          _phoneError = err;
          _currentStep = 0;
        });
      } else if (err.contains('password')) {
        setState(() {
          _passwordError = err;
          _currentStep = 2;
        });
      } else if (err.contains('name')) {
        setState(() {
          _nameError = err;
          _currentStep = 0;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: Colors.red),
        );
      }
      return;
    }

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: Stack(
        children: [
          // Background mesh
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.3),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF007AFF).withValues(alpha: 0.2),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ),

          Positioned.fill(
            child: AppTheme.glass(
              blur: 20,
              color: Colors.white.withValues(alpha: 0.5),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top bar with back button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: _goBack,
                          ),
                          const Spacer(),
                          Text(
                            'Step ${_currentStep + 1} of $_kTotalSteps',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // App logo
                    _buildAppLogo(),
                    const SizedBox(height: 8),

                    // Step indicator
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      child: _StepIndicator(
                        currentStep: _currentStep,
                        totalSteps: _kTotalSteps,
                      ),
                    ),

                    // Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            // Step header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _stepIcons[_currentStep],
                                    color: AppTheme.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _stepTitles[_currentStep],
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _stepSubtitles[_currentStep],
                                        style: GoogleFonts.inter(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Step content
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _buildStepContent(),
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),

                    // Bottom navigation
                    _buildBottomBar(authState),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogo() {
    return const AppLogo(
      size: 72,
      showLabel: true,
      subtitle: 'Create your account',
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Step 1: Personal Info ────────────────────────────────────────────────

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        key: const ValueKey(0),
        children: [
          TextFormField(
            controller: _nameCtl,
            textCapitalization: TextCapitalization.words,
            decoration: _fieldDecoration(
              label: 'Full Name',
              icon: Icons.person_outline,
              errorText: _nameError,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your full name' : null,
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _emailCtl,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecoration(
              label: 'Email',
              icon: Icons.email_outlined,
              errorText: _emailError,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _phoneCtl,
            keyboardType: TextInputType.phone,
            decoration: _fieldDecoration(
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              errorText: _phoneError,
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter your phone number'
                : null,
          ),
        ],
      ),
    );
  }

  // ── Step 2: Location ─────────────────────────────────────────────────────

  Future<void> _fetchLocationAndFillWard() async {
    setState(() {
      _locationLoading = true;
      _locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _locationLoading = false;
          _locationError = 'Location services are disabled. Please enable GPS.';
        });
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationLoading = false;
            _locationError = 'Location permission denied.';
          });
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationLoading = false;
          _locationError =
              'Location permission permanently denied. Enable in settings.';
        });
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      final repo = ref.read(_wardsRepoProvider);
      final ward = await repo.lookupByCoordinates(
        position.latitude,
        position.longitude,
      );
      if (ward == null) {
        setState(() {
          _locationLoading = false;
          _locationError =
              'Could not find a ward at your location. Are you within Delhi?';
        });
        return;
      }
      final zoneId = ward.zoneId;
      final wardId = ward.id;
      if (zoneId == null || zoneId.isEmpty || wardId.isEmpty) {
        setState(() {
          _locationLoading = false;
          _locationError =
              'Ward lookup did not return zone/ward. Try selecting manually.';
        });
        return;
      }
      ref.read(_selectedZoneIdProvider.notifier).state = zoneId;
      setState(() {
        _selectedZoneId = zoneId;
        _selectedWardId = wardId;
        _locationLoading = false;
        _locationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationLoading = false;
        _locationError = e.toString().length > 80
            ? '${e.toString().substring(0, 80)}...'
            : e.toString();
      });
    }
  }

  Widget _buildStep2() {
    final zonesAsync = ref.watch(_zonesListProvider);
    final wardsAsync = ref.watch(_wardListProvider);

    return Form(
      key: _step2Key,
      child: Column(
        key: const ValueKey(1),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle: I am in my ward compound
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.my_location_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'I am in my ward compound',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
                Switch(
                  value: _isInWardCompound,
                  onChanged: _locationLoading
                      ? null
                      : (value) async {
                          setState(() => _isInWardCompound = value);
                          if (value) {
                            await _fetchLocationAndFillWard();
                          } else {
                            setState(() => _locationError = null);
                          }
                        },
                  activeThumbColor: AppTheme.primary,
                ),
              ],
            ),
          ),
          if (_locationLoading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Fetching location and ward...',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          if (_locationError != null) ...[
            const SizedBox(height: 8),
            Text(
              _locationError!,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.red[700]),
            ),
          ],
          const SizedBox(height: 20),

          TextFormField(
            controller: _addressCtl,
            maxLines: 3,
            minLines: 2,
            keyboardType: TextInputType.multiline,
            decoration: _fieldDecoration(
              label: 'Address',
              icon: Icons.home_outlined,
            ),
          ),
          const SizedBox(height: 18),

          zonesAsync.when(
            data: (zones) => DropdownButtonFormField<String>(
              initialValue: _selectedZoneId,
              isExpanded: true,
              decoration: _fieldDecoration(
                label: 'Zone',
                icon: Icons.map_outlined,
              ),
              items: zones.map((z) {
                final id = z['id']?.toString() ?? '';
                final name = z['name'] as String? ?? 'Zone $id';
                return DropdownMenuItem(value: id, child: Text(name));
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedZoneId = val;
                  _selectedWardId = null;
                });
                ref.read(_selectedZoneIdProvider.notifier).state = val;
              },
              validator: (v) => v == null ? 'Select a zone' : null,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(color: AppTheme.primary),
            ),
            error: (err, stack) => DropdownButtonFormField<String>(
              initialValue: null,
              decoration: _fieldDecoration(
                label: 'Zone (could not load)',
                icon: Icons.map_outlined,
              ),
              items: const [],
              onChanged: null,
            ),
          ),
          const SizedBox(height: 18),

          wardsAsync.when(
            data: (wards) => DropdownButtonFormField<String>(
              initialValue: _selectedWardId,
              isExpanded: true,
              decoration: _fieldDecoration(
                label: 'Ward',
                icon: Icons.location_city_outlined,
              ),
              items: wards.map((w) {
                final id = w.id;
                final name = w.name;
                return DropdownMenuItem(value: id, child: Text(name));
              }).toList(),
              onChanged: _selectedZoneId == null
                  ? null
                  : (val) => setState(() => _selectedWardId = val),
              validator: (v) => v == null ? 'Select a ward' : null,
            ),
            loading: () => _selectedZoneId == null
                ? DropdownButtonFormField<String>(
                    initialValue: null,
                    decoration: _fieldDecoration(
                      label: 'Ward',
                      icon: Icons.location_city_outlined,
                    ),
                    items: const [],
                    onChanged: null,
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(color: AppTheme.primary),
                  ),
            error: (err, stack) => DropdownButtonFormField<String>(
              initialValue: null,
              decoration: _fieldDecoration(
                label: 'Ward (could not load)',
                icon: Icons.location_city_outlined,
              ),
              items: const [],
              onChanged: null,
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Security ─────────────────────────────────────────────────────

  Widget _buildStep3() {
    return Form(
      key: _step3Key,
      child: Column(
        key: const ValueKey(2),
        children: [
          TextFormField(
            controller: _passwordCtl,
            obscureText: _obscurePassword,
            decoration: _fieldDecoration(
              label: 'Password',
              icon: Icons.lock_outline,
              errorText: _passwordError,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) =>
                (v == null || v.length < 6) ? 'At least 6 characters' : null,
          ),
          const SizedBox(height: 18),

          TextFormField(
            controller: _confirmPasswordCtl,
            obscureText: _obscureConfirm,
            decoration: _fieldDecoration(
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                onPressed: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _passwordCtl.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primary.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Password must be at least 6 characters.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Bottom bar ───────────────────────────────────────────────────────────

  Widget _buildBottomBar(AuthState authState) {
    final isFirst = _currentStep == 0;
    final isLast = _currentStep == _kTotalSteps - 1;
    final isLoading = authState.isLoading;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Previous button
          if (!isFirst)
            TextButton.icon(
              onPressed: isLoading ? null : _goBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              label: Text(
                'Back',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          if (isFirst) const SizedBox(width: 16),

          const Spacer(),

          // Next / Register button
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: isLoading ? null : _goNext,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? 'Register' : 'Next',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step indicator
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          final stepBefore = i ~/ 2;
          final done = stepBefore < currentStep;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: done ? AppTheme.primary : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }
        final step = i ~/ 2;
        final isActive = step == currentStep;
        final isDone = step < currentStep;
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppTheme.primary
                : isActive
                ? AppTheme.primary.withValues(alpha: 0.12)
                : Colors.grey[200],
            border: isActive
                ? Border.all(color: AppTheme.primary, width: 2)
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : Text(
                    '${step + 1}',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isActive ? AppTheme.primary : Colors.grey[500],
                    ),
                  ),
          ),
        );
      }),
    );
  }
}
