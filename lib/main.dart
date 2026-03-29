import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/api_config.dart';
import 'models/user_models.dart';
import 'utils/responsive_utils.dart';
import 'screens/api_url_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/citizen_feed_screen.dart';
import 'screens/department_performance_screen.dart';
import 'screens/history_screen.dart';
import 'screens/add_complaint_flow.dart';
import 'screens/profile_screen.dart';
import 'screens/login_screen.dart';
import 'providers/attendance_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/complaint_provider.dart';
import 'providers/message_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/field_worker_provider.dart';
import 'providers/offline_provider.dart';
import 'services/offline_sync_service.dart';
import 'screens/drawer/about_us_screen.dart';
import 'screens/drawer/faq_screen.dart';
import 'screens/drawer/contact_us_screen.dart';
import 'screens/drawer/helpline_screen.dart';
import 'screens/ward_environment_screen.dart';
import 'screens/officer/field_manager_dashboard.dart';
import 'screens/officer/manager_grievances_screen.dart';
import 'screens/officer/manager_escalations_screen.dart';
import 'screens/officer/worker_directory_screen.dart';
import 'screens/officer/field_assistant_dashboard.dart';
import 'screens/officer/field_assistant_tasks_screen.dart';
import 'screens/officer/attendance_screen.dart';
import 'screens/officer/worker_escalations_screen.dart';
import 'screens/officer/manager_worker_analytics_screen.dart';
import 'widgets/adaptive_scaffold.dart';
import 'widgets/app_logo.dart';
import 'widgets/civic_ui.dart';
import 'core/app_theme.dart';
import 'models/complaint.dart';
import 'providers/worker_nav_provider.dart';
import 'providers/portal_refresh.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadApiBaseUrlOverride();
  runApp(const ProviderScope(child: CivicCareApp()));
}

class CivicCareApp extends StatelessWidget {
  const CivicCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CivicCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        // Apple System fonts
        fontFamily: 'SF Pro Display',
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primary,
          primary: AppTheme.primary,
          secondary: AppTheme.primaryDark,
          surface: AppTheme.surfaceScaffold,
        ),
        scaffoldBackgroundColor: AppTheme.surfaceScaffold,
        textTheme:
            GoogleFonts.interTextTheme(), // Fallback if SF Pro isn't available
        appBarTheme: const AppBarTheme(
          backgroundColor: AppTheme.surfaceScaffold,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: AppTheme.textPrimary),
          titleTextStyle: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            letterSpacing: -0.4,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
            ),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.inputRadius),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
      home: const _AppEntry(),
    );
  }
}

/// Shows API URL screen first when not yet configured, then MainScreen (login or app).
class _AppEntry extends ConsumerStatefulWidget {
  const _AppEntry();

  @override
  ConsumerState<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<_AppEntry> {
  bool _loading = true;
  bool _apiUrlConfigured = false;

  @override
  void initState() {
    super.initState();
    _checkConfigured();
  }

  Future<void> _checkConfigured() async {
    final configured = await getApiUrlConfigured();
    // Restore saved auth session before showing the main UI.
    await ref.read(authProvider.notifier).init();
    if (mounted) {
      setState(() {
        _apiUrlConfigured = configured;
        _loading = false;
      });
    }
  }

  void _onApiUrlContinue() {
    setState(() => _apiUrlConfigured = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }
    if (!_apiUrlConfigured) {
      return ApiUrlScreen(onContinue: _onApiUrlContinue);
    }
    return const MainScreen();
  }
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  Widget? _overlayScreen;
  String? _overlayTitle;
  bool _portalRefreshing = false;

  Future<void> _runPortalRefresh(Future<void> Function(WidgetRef r) fn) async {
    if (_portalRefreshing) return;
    setState(() => _portalRefreshing = true);
    try {
      await fn(ref);
      if (mounted) HapticFeedback.mediumImpact();
    } finally {
      if (mounted) setState(() => _portalRefreshing = false);
    }
  }

  Future<void> _refreshCitizenPortal() =>
      _runPortalRefresh(refreshCitizenPortal);

  Future<void> _refreshManagerPortal() =>
      _runPortalRefresh(refreshManagerPortal);

  Future<void> _refreshWorkerPortal() =>
      _runPortalRefresh(refreshWorkerPortal);

  static final _citizenScreens = [
    const DashboardScreen(),
    const CitizenFeedScreen(),
    const HistoryScreen(),
    const DepartmentPerformanceScreen(),
  ];

  static const _citizenTitles = ['Overview', 'Feed', 'My Complaints', 'Insights'];

  static final _managerScreens = [
    const FieldManagerDashboard(),
    const ManagerGrievancesScreen(),
    const WorkerDirectoryScreen(),
    const ManagerEscalationsScreen(),
    const ManagerWorkerAnalyticsScreen(),
  ];

  static const _managerTitles = [
    'Dashboard',
    'Grievances',
    'Workforce',
    'Escalations',
    'Analytics',
  ];

  // Worker screens are created lazily to avoid constant rebuilds
  static final _workerScreens = [
    const FieldAssistantDashboard(),
    const FieldAssistantTasksScreen(),
    const AttendanceScreen(),
    const WorkerEscalationsScreen(),
  ];

  static const _workerTitles = ['Dashboard', 'My Tasks', 'Attendance', 'Escalations'];

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Single auth listener: load grievances on login AND clear overlay/index on any auth change.
    ref.listen(authProvider, (prev, next) {
      final wasAuth = prev?.isAuthenticated ?? false;
      final isAuth = next.isAuthenticated;
      final prevWardId = prev?.user?.wardId;
      final nextWardId = next.user?.wardId;

      // Reload grievances whenever we log in or ward_id resolves/changes.
      if (isAuth && (!wasAuth || prevWardId != nextWardId)) {
        ref.read(complaintProvider.notifier).loadGrievances();
        final user = next.user;
        final isStaff =
            user?.role == UserRole.fieldManager ||
            user?.role == UserRole.fieldAssistant ||
            user?.role == UserRole.admin;
        if (isStaff) {
          ref.read(fieldWorkerProvider.notifier).loadWorkers();
        }
      }
      if (wasAuth != isAuth) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _overlayScreen = null;
            _overlayTitle = null;
            _currentIndex = 0;
          });
        });
      }
    });

    // Global error SnackBar for grievance operations
    ref.listen<GrievanceState>(complaintProvider, (prev, next) {
      if (next.error != null && (prev == null || prev.error != next.error)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          ref.read(complaintProvider.notifier).clearError();
        });
      }
    });

    ref.listen(currentPortalProvider, (prev, next) {
      if (prev != next) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _overlayScreen = null;
            _overlayTitle = null;
            _currentIndex = 0;
          });
        });
      }
    });

    ref.listen(workerTabToSelectProvider, (prev, next) {
      if (next != null && authState.user?.role == UserRole.fieldAssistant) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _currentIndex = next.clamp(0, 3));
          ref.read(workerTabToSelectProvider.notifier).state = null;
        });
      }
    });

    ref.listen(connectivityProvider, (prev, next) {
      final wasOffline = prev?.valueOrNull == false;
      final isOnline = next.valueOrNull == true;
      if (wasOffline && isOnline && authState.isAuthenticated) {
        final token = ref.read(authProvider).accessToken;
        final workerId = ref.read(authProvider).user?.id;
        if (token != null && workerId != null) {
          final sync = OfflineSyncService(
            storage: ref.read(offlineStorageProvider),
            accessToken: token,
            workerId: workerId,
            grievanceRepo: ref.read(grievanceRepositoryProvider),
            attendanceRepo: ref.read(attendanceRepositoryProvider),
            messageRepo: ref.read(messageRepositoryProvider),
          );
          sync.sync().then((_) {
            ref.read(attendanceProvider.notifier).fetchStatus();
            ref.invalidate(pendingSyncCountProvider);
            final uid = ref.read(authProvider).user?.id;
            if (uid != null) {
              ref.read(complaintProvider.notifier).loadGrievances(workerId: uid, limit: 100);
              ref.read(workerEscalationsProvider.notifier).loadGrievances(
                workerId: uid,
                status: ComplaintStatus.escalated,
                limit: 100,
              );
            }
          });
        }
      }
    });

    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }
    // Staff can switch portal (citizen vs department). Citizens always see citizen shell.
    final role = authState.user?.role ?? UserRole.citizen;
    final currentPortal = ref.watch(currentPortalProvider);
    final portal = effectivePortal(currentPortal, role);

    if (portal == PortalMode.citizen) {
      return _buildCitizenShell(authState);
    }
    switch (role) {
      case UserRole.fieldManager:
      case UserRole.admin:
        return _buildManagerShell(authState);
      case UserRole.fieldAssistant:
        return _buildWorkerShell(authState);
      case UserRole.citizen:
        return _buildCitizenShell(authState);
    }
  }

  // ── Footer items shared by both shells ──────────────────────────────────

  void _showOverlay(String title, Widget screen) {
    setState(() {
      _overlayScreen = screen;
      _overlayTitle = title;
    });
  }

  void _clearOverlay() {
    setState(() {
      _overlayScreen = null;
      _overlayTitle = null;
    });
  }

  Widget _buildBody(Widget normalBody) {
    if (_overlayScreen != null) {
      return _overlayScreen!;
    }
    return normalBody;
  }

  String _getTitle(String normalTitle) {
    return _overlayTitle ?? normalTitle;
  }

  List<SidebarFooterItem> _footerItems({required bool useOverlay}) {
    if (useOverlay) {
      return [
        SidebarFooterItem(
          label: 'About Us',
          icon: Icons.info_outline_rounded,
          onTap: () => _showOverlay('About Us', const AboutUsScreen()),
        ),
        SidebarFooterItem(
          label: "FAQ's",
          icon: Icons.help_outline_rounded,
          onTap: () => _showOverlay("FAQ's", const FAQScreen()),
        ),
        SidebarFooterItem(
          label: 'Contact Us',
          icon: Icons.contact_support_outlined,
          onTap: () => _showOverlay('Contact Us', const ContactUsScreen()),
        ),
        SidebarFooterItem(
          label: 'MCD Helpline',
          icon: Icons.phone_forwarded_rounded,
          onTap: () => _showOverlay('MCD Helpline', const HelplineScreen()),
        ),
      ];
    }
    return [
      SidebarFooterItem(
        label: 'About Us',
        icon: Icons.info_outline_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutUsScreen()),
        ),
      ),
      SidebarFooterItem(
        label: "FAQ's",
        icon: Icons.help_outline_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FAQScreen()),
        ),
      ),
      SidebarFooterItem(
        label: 'Contact Us',
        icon: Icons.contact_support_outlined,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ContactUsScreen()),
        ),
      ),
      SidebarFooterItem(
        label: 'MCD Helpline',
        icon: Icons.phone_forwarded_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HelplineScreen()),
        ),
      ),
    ];
  }

  // ── Citizen shell (worker profile hidden: effectiveUser has no department) ──

  Widget _buildCitizenShell(AuthState authState) {
    final isWeb =
        MediaQuery.of(context).size.width >= ResponsiveUtils.sidebarBreakpoint;
    final effectiveUser = ref.watch(effectiveUserProvider);
    // Safety clamp to prevent index out of bounds during portal transitions
    final safeIndex = _currentIndex.clamp(0, _citizenScreens.length - 1);
    final normalBody = IndexedStack(
      index: safeIndex,
      children: _citizenScreens,
    );

    return AdaptiveScaffold(
      title: _getTitle(_citizenTitles[_currentIndex]),
      userName: effectiveUser?.name ?? '',
      userRole: 'CITIZEN PORTAL',
      onPortalRefresh: _refreshCitizenPortal,
      isPortalRefreshing: _portalRefreshing,
      onProfileTap: isWeb
          ? () => _showOverlay('My Account', const ProfileScreen())
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
      footerItems: _footerItems(useOverlay: isWeb),
      onLogout: () {
        ref.read(authProvider.notifier).logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
      onReportIssue: isWeb
          ? () => _showOverlay('Report Issue', const AddComplaintFlow())
          : null, // Mobile uses FAB
      useMobileAppBar: false,
      destinations: const [
        AdaptiveDestination(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
        AdaptiveDestination(
          label: 'Feed',
          icon: Icons.feed_outlined,
          selectedIcon: Icons.feed,
        ),
        AdaptiveDestination(
          label: 'History',
          icon: Icons.history_outlined,
          selectedIcon: Icons.history,
        ),
        AdaptiveDestination(
          label: 'Insights',
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics_rounded,
        ),
      ],
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) {
        _clearOverlay();
        setState(() => _currentIndex = i);
      },
      body: _buildBody(normalBody),
      mobileDrawer: _drawer(
        authState,
        isCitizenPortal: true,
        onPortalRefreshAll: _refreshCitizenPortal,
      ),
      // We remove the standard NavigationBar here because AdaptiveScaffold
      // now natively renders `_buildGlassFloatingBottomBar` using `destinations` and `selectedIndex`.
      // Ensure AdaptiveScaffold knows to use the floating bar on mobile:
      mobileBottomNavigationBar:
          const SizedBox.shrink(), // Dummy widget to trigger floating bar logic
      floatingActionButton: isWeb
          ? null
          : Padding(
              padding: const EdgeInsets.only(
                bottom: 80.0,
              ), // Above floating bar
              child: FloatingActionButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddComplaintFlow()),
                ),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation:
                    4, // iOS feels have slight drop shadow for FAR actions
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add_a_photo),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ── Manager shell ─────────────────────────────────────────────────────────

  Widget _buildManagerShell(AuthState authState) {
    final isWeb =
        MediaQuery.of(context).size.width >= ResponsiveUtils.sidebarBreakpoint;
    // Safety clamp to prevent index out of bounds during portal transitions
    final safeIndex = _currentIndex.clamp(0, _managerScreens.length - 1);
    final normalBody = IndexedStack(
      index: safeIndex,
      children: _managerScreens,
    );

    return AdaptiveScaffold(
      title: _getTitle(_managerTitles[safeIndex]),
      userName: authState.user?.name ?? '',
      userRole: 'MANAGER PORTAL',
      onPortalRefresh: _refreshManagerPortal,
      isPortalRefreshing: _portalRefreshing,
      onProfileTap: isWeb
          ? () => _showOverlay('My Account', const ProfileScreen())
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
      footerItems: _footerItems(useOverlay: isWeb),
      onLogout: () {
        ref.read(authProvider.notifier).logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
      useMobileAppBar: false,
      destinations: const [
        AdaptiveDestination(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
        ),
        AdaptiveDestination(
          label: 'Grievances',
          icon: Icons.assignment_outlined,
          selectedIcon: Icons.assignment,
        ),
        AdaptiveDestination(
          label: 'Workforce',
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
        ),
        AdaptiveDestination(
          label: 'Escalations',
          icon: Icons.warning_amber_rounded,
          selectedIcon: Icons.warning_amber,
        ),
        AdaptiveDestination(
          label: 'Analytics',
          icon: Icons.analytics_outlined,
          selectedIcon: Icons.analytics_rounded,
        ),
      ],
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) {
        _clearOverlay();
        setState(() => _currentIndex = i);
      },
      body: _buildBody(normalBody),
      mobileDrawer: _drawer(
        authState,
        isCitizenPortal: false,
        onPortalRefreshAll: _refreshManagerPortal,
      ),
      mobileBottomNavigationBar:
          const SizedBox.shrink(), // Trigger floating glass bottom bar
    );
  }

  Widget _buildWorkerShell(AuthState authState) {
    final isWeb =
        MediaQuery.of(context).size.width >= ResponsiveUtils.sidebarBreakpoint;
    final safeIndex = _currentIndex.clamp(0, _workerScreens.length - 1);
    final stack = IndexedStack(index: safeIndex, children: _workerScreens);
    final isOffline = ref.watch(connectivityProvider).valueOrNull == false;
    final normalBody = isOffline
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OfflineBanner(),
              Expanded(child: stack),
            ],
          )
        : stack;

    return AdaptiveScaffold(
      title: _workerTitles[_currentIndex],
      userName: authState.user?.name ?? '',
      userRole: 'WORKER PORTAL',
      onPortalRefresh: _refreshWorkerPortal,
      isPortalRefreshing: _portalRefreshing,
      onProfileTap: isWeb
          ? () => _showOverlay('My Account', const ProfileScreen())
          : () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
      footerItems: _footerItems(useOverlay: isWeb),
      onLogout: () {
        ref.read(authProvider.notifier).logout();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
      useMobileAppBar: false,
      destinations: const [
        AdaptiveDestination(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard_rounded,
        ),
        AdaptiveDestination(
          label: 'My Tasks',
          icon: Icons.assignment_rounded,
          selectedIcon: Icons.assignment,
        ),
        AdaptiveDestination(
          label: 'Attendance',
          icon: Icons.schedule_outlined,
          selectedIcon: Icons.schedule_rounded,
        ),
        AdaptiveDestination(
          label: 'Escalations',
          icon: Icons.warning_amber_outlined,
          selectedIcon: Icons.warning_amber_rounded,
        ),
      ],
      selectedIndex: _currentIndex,
      onDestinationSelected: (i) {
        _clearOverlay();
        ref.read(workerSelectedTabProvider.notifier).state = i;
        setState(() => _currentIndex = i);
      },
      body: _buildBody(normalBody),
      mobileDrawer: _drawer(
        authState,
        isCitizenPortal: false,
        onPortalRefreshAll: _refreshWorkerPortal,
      ),
      mobileBottomNavigationBar:
          const SizedBox.shrink(), // Trigger floating glass bottom bar
    );
  }

  // ── Shared Drawer (mobile only) ───────────────────────────────────────────

  Widget _drawer(
    AuthState authState, {
    bool isCitizenPortal = false,
    Future<void> Function()? onPortalRefreshAll,
  }) {
    final user = authState.user;
    final role = user?.role ?? UserRole.citizen;
    final isStaff = user?.isStaff ?? false;

    final String portalLabel = isCitizenPortal
        ? 'CITIZEN PORTAL'
        : role == UserRole.fieldManager
        ? 'MANAGER PORTAL'
        : role == UserRole.fieldAssistant
        ? 'WORKER PORTAL'
        : 'CITIZEN PORTAL';

    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85,
      child: Builder(
        builder: (drawerContext) {
          return AppTheme.glass(
            blur: 40,
            color: AppTheme.surfaceScaffold.withValues(alpha: 0.85),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const AppLogo(size: 32, showLabel: false),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CivicCare',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            portalLabel,
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Text(
                      'ACCOUNT',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: AppTheme.cardDecoration(),
                      child: Column(
                        children: [
                          if (onPortalRefreshAll != null) ...[
                            _drawerItem(
                              icon: Icons.sync_rounded,
                              title: 'Refresh all data',
                              onTap: () => onPortalRefreshAll(),
                            ),
                            Divider(
                              height: 1,
                              indent: 56,
                              color: AppTheme.border,
                            ),
                          ],
                          _drawerItem(
                            icon: Icons.person_outline_rounded,
                            title: 'My Profile',
                            onTap: () {
                              Navigator.push(
                                drawerContext,
                                MaterialPageRoute(
                                  builder: (_) => const ProfileScreen(),
                                ),
                              );
                            },
                          ),
                          Divider(
                            height: 1,
                            indent: 56,
                            color: AppTheme.border,
                          ),
                          _drawerItem(
                            icon: Icons.air_rounded,
                            title: 'Ward Environment',
                            onTap: () async {
                              Scaffold.of(drawerContext).closeDrawer();
                              await Navigator.push(
                                drawerContext,
                                MaterialPageRoute(
                                  builder: (_) => const WardEnvironmentScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SUPPORT',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: AppTheme.cardDecoration(),
                      child: Column(
                        children: [
                          _drawerItem(
                            icon: Icons.info_outline_rounded,
                            title: 'About Us',
                            onTap: () => Navigator.push(
                              drawerContext,
                              MaterialPageRoute(
                                builder: (_) => const AboutUsScreen(),
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            indent: 56,
                            color: AppTheme.border,
                          ),
                          _drawerItem(
                            icon: Icons.help_outline_rounded,
                            title: "FAQ's",
                            onTap: () => Navigator.push(
                              drawerContext,
                              MaterialPageRoute(
                                builder: (_) => const FAQScreen(),
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            indent: 56,
                            color: AppTheme.border,
                          ),
                          _drawerItem(
                            icon: Icons.contact_support_outlined,
                            title: 'Contact Us',
                            onTap: () => Navigator.push(
                              drawerContext,
                              MaterialPageRoute(
                                builder: (_) => const ContactUsScreen(),
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            indent: 56,
                            color: AppTheme.border,
                          ),
                          _drawerItem(
                            icon: Icons.phone_forwarded_rounded,
                            title: 'MCD Helpline',
                            onTap: () => Navigator.push(
                              drawerContext,
                              MaterialPageRoute(
                                builder: (_) => const HelplineScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isStaff) ...[
                      const SizedBox(height: 24),
                      Text(
                        'PORTAL',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: AppTheme.cardDecoration(),
                        child: _drawerItem(
                          icon: isCitizenPortal
                              ? Icons.business_center_rounded
                              : Icons.person_rounded,
                          title: isCitizenPortal
                              ? 'Switch to Department'
                              : 'Switch to Citizen',
                          onTap: () {
                            if (isCitizenPortal) {
                              ref
                                      .read(
                                        initialLoginAsDepartmentProvider
                                            .notifier,
                                      )
                                      .state =
                                  true;
                              ref.read(authProvider.notifier).logout();
                            } else {
                              ref
                                      .read(
                                        initialLoginAsDepartmentProvider
                                            .notifier,
                                      )
                                      .state =
                                  false;
                              ref.read(authProvider.notifier).logout();
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: AppTheme.cardDecoration(),
                  child: _drawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Log Out',
                    onTap: () => ref.read(authProvider.notifier).logout(),
                    color: AppTheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
    );
  },
  ),
);
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: color ?? AppTheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color ?? AppTheme.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
