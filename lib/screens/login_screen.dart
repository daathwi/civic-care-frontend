import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api_config.dart';
import '../core/app_theme.dart';
import '../models/user_models.dart';
import '../providers/auth_provider.dart';
import '../providers/departments_provider.dart';
import '../utils/responsive_utils.dart';
import '../widgets/app_logo.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isCitizenMode = true;
  bool _obscurePassword = true;
  String? _selectedDepartmentId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final openAsDepartment = ref.read(initialLoginAsDepartmentProvider);
      if (openAsDepartment) {
        ref.read(initialLoginAsDepartmentProvider.notifier).state = false;
        setState(() => _isCitizenMode = false);
      }
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isCitizenMode &&
        (_selectedDepartmentId == null || _selectedDepartmentId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your department.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await ref
        .read(authProvider.notifier)
        .login(
          _phoneController.text.trim(),
          _passwordController.text,
          departmentId: _isCitizenMode ? null : _selectedDepartmentId,
        );

    final authState = ref.read(authProvider);
    if (authState.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.error!), backgroundColor: Colors.red),
      );
      return;
    }

    if (authState.isAuthenticated && mounted) {
      final user = authState.user!;
      if (_isCitizenMode) {
        ref.read(currentPortalProvider.notifier).state = PortalMode.citizen;
      } else {
        if (user.role == UserRole.citizen) {
          ref.read(authProvider.notifier).logout();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'This account is a citizen account. Please use Citizen login.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        ref.read(currentPortalProvider.notifier).state = PortalMode.department;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context, authState),
      desktop: _buildWebLayout(context, authState),
    );
  }

  // ── Mobile ──────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context, AuthState authState) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: Stack(
        children: [
          _buildBackgroundDecoration(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 48),
                  _buildAppLogo(),
                  const SizedBox(height: 40),
                  AppTheme.glass(
                    blur: 24,
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: _buildLoginForm(context, authState),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
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
      ],
    );
  }

  Widget _buildAppLogo() {
    return Column(
      children: [
        const AppLogo(size: 88, showLabel: true),
        const SizedBox(height: 12),
        Text(
          'Empowering Citizens. Transforming Governance.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey[800],
            letterSpacing: -0.2,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  // ── Web — two-column split ──────────────────────────────────────────────

  Widget _buildWebLayout(BuildContext context, AuthState authState) {
    return Scaffold(
      body: Stack(
        children: [
          // Background mesh
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE6F7F7), Color(0xFFF2F2F7)],
              ),
            ),
          ),
          Positioned(
            top: -200,
            left: -100,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.4),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -100,
            child: Container(
              width: 700,
              height: 700,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5E5CE6).withValues(alpha: 0.25),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Content
          Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 720),
              child: AppTheme.glass(
                blur: 30,
                color: Colors.white.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(40),
                child: Row(
                  children: [
                    // Left panel — branding
                    Expanded(
                      flex: 5,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.9),
                              AppTheme.primaryDark,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(32),
                                  ),
                                  child: const AppLogo(
                                    size: 88,
                                    showLabel: false,
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Text(
                                  'CivicCare',
                                  style: GoogleFonts.outfit(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -1,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Empowering Citizens.\nTransforming Governance.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    color: Colors.white.withValues(alpha: 0.85),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 64),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _brandStat('500+', 'Resolved'),
                                    _brandDivider(),
                                    _brandStat('42', 'Wards'),
                                    _brandDivider(),
                                    _brandStat('10K+', 'Citizens'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right panel — form
                    Expanded(
                      flex: 4,
                      child: Container(
                        color: Colors.white.withValues(
                          alpha: 0.3,
                        ), // subtle frost over the glass
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 32,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome Back',
                                  style: GoogleFonts.outfit(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Sign in to continue to CivicCare',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 48),
                                _buildLoginForm(context, authState),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _brandDivider() {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      color: Colors.white.withValues(alpha: 0.25),
    );
  }

  // ── Shared login form ───────────────────────────────────────────────────

  Widget _buildLoginForm(BuildContext context, AuthState authState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Role toggle
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _toggleTab(
                  'Citizen',
                  Icons.person_outline,
                  _isCitizenMode,
                  () => setState(() {
                    _isCitizenMode = true;
                    _selectedDepartmentId = null;
                  }),
                ),
              ),
              Expanded(
                child: _toggleTab(
                  'Department',
                  Icons.business_center_outlined,
                  !_isCitizenMode,
                  () => setState(() => _isCitizenMode = false),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Department picker (dynamic from backend)
        if (!_isCitizenMode) ...[
          Consumer(
            builder: (context, ref, _) {
              final departmentsAsync = ref.watch(departmentsProvider);
              final departments = departmentsAsync.valueOrNull ?? [];
              final loading = departmentsAsync.isLoading;
              return DropdownButtonFormField<String>(
                initialValue: _selectedDepartmentId,
                hint: Text(
                  loading ? 'Loading departments…' : 'Select Department',
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.domain_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  for (final d in departments)
                    DropdownMenuItem<String>(
                      value: d['id']?.toString(),
                      child: Text(
                        d['name']?.toString() ?? 'Department',
                        style: GoogleFonts.outfit(),
                      ),
                    ),
                ],
                onChanged: loading
                    ? null
                    : (id) => setState(() => _selectedDepartmentId = id),
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        // Credentials form
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _phoneController,
                keyboardType: _isCitizenMode
                    ? TextInputType.phone
                    : TextInputType.text,
                decoration: InputDecoration(
                  labelText: _isCitizenMode ? 'Phone Number' : 'Username',
                  prefixIcon: Icon(
                    _isCitizenMode
                        ? Icons.phone_outlined
                        : Icons.person_outline,
                    color: Colors.grey[400],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'This field is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey[400],
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'Enter your password' : null,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: authState.isLoading ? null : _handleLogin,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),

        if (_isCitizenMode) ...[
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an account? ",
                style: GoogleFonts.inter(color: Colors.black54),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: Text(
                  'Register Now',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),
        Text(
          _isCitizenMode
              ? 'Citizen: phone + password'
              : 'Department: User ID or phone + password',
          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showApiUrlDialog(context),
          child: Text(
            'Connection refused? Set API URL',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              decoration: TextDecoration.underline,
              decorationColor: Colors.grey[400],
            ),
          ),
        ),
      ],
    );
  }

  void _showApiUrlDialog(BuildContext context) {
    final controller = TextEditingController(text: apiBaseUrl);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('API base URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'http://10.0.2.2:8000 or http://YOUR_PC_IP:8000',
          ),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await setApiBaseUrlOverride(null);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Reset default'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) await setApiBaseUrlOverride(url);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _toggleTab(
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : Colors.grey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
