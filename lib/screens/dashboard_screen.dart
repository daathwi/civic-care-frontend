import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../core/app_theme.dart';
import '../models/complaint.dart';
import '../models/user_models.dart';
import '../providers/analytics_provider.dart';
import '../providers/complaint_provider.dart';
import '../providers/connectivity_provider.dart';
import '../utils/responsive_utils.dart';
import '../widgets/civic_ui.dart';

import 'complaint_detail/complaint_detail_screen.dart';
import 'council_directory_screen.dart';
import 'drawer/helpline_screen.dart';
import 'map_screen.dart';
import '../widgets/ward_weather_widget.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await ref.read(complaintProvider.notifier).loadGrievances();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final gState = ref.watch(complaintProvider);
    final complaints = gState.complaints;
    final userName = ref.watch(userNameProvider);
    final isOffline = ref.watch(connectivityProvider).valueOrNull == false;
    final cisAsync = ref.watch(userCisProvider);

    // Show shimmer on first load (no data yet)
    final showSkeleton = gState.isLoading && complaints.isEmpty;

    // Data Aggregation (statusCounts ensures consistency with filter chips)
    final counts = statusCounts(complaints);
    final resolved = counts.resolved;
    final inProgress = counts.assigned + counts.inProgress; // "In Work" = assigned + ongoing
    final pending = counts.pending;
    final escalated = counts.escalated;

    return Column(
      children: [
        if (isOffline) const OfflineBanner(),
        Expanded(
          child: showSkeleton
              ? _buildSkeletonLayout()
              : gState.error != null && complaints.isEmpty
              ? CivicErrorState(
                  message: gState.error!,
                  onRetry: () =>
                      ref.read(complaintProvider.notifier).loadGrievances(),
                )
              : ResponsiveLayout(
                  mobile: _buildMobileLayout(
                    userName,
                    resolved,
                    inProgress,
                    pending,
                    escalated,
                    complaints,
                    cisAsync,
                  ),
                  desktop: _buildWebLayout(
                    userName,
                    resolved,
                    inProgress,
                    pending,
                    escalated,
                    complaints,
                    cisAsync,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SizedBox(height: 40),
          DashboardKpiSkeleton(),
          SizedBox(height: 24),
          GrievanceListSkeleton(count: 3),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
    String userName,
    int resolved,
    int inProgress,
    int pending,
    int escalated,
    List<Complaint> complaints,
    AsyncValue<CisResult?> cisAsync,
  ) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.surfaceScaffold,
            scrolledUnderElevation: 0,
            pinned: true,
            expandedHeight: 120,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.black87),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
              title: Text(
                'Welcome',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 24,
                ),
              ),
            ),
            actions: [
              if (_isRefreshing)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),

              const SizedBox(width: 8),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeCard(context, userName, cisAsync),
                  const SizedBox(height: 20),
                  const WardWeatherWidget(),
                  const SizedBox(height: 32),

                  _buildSectionHeader('SYSTEM OVERVIEW'),
                  const SizedBox(height: 16),
                  _buildBentoGrid(
                    resolved,
                    inProgress,
                    pending,
                    escalated,
                    complaints.length,
                  ),
                  const SizedBox(height: 32),

                  _buildSectionHeader('QUICK ACTIONS'),
                  const SizedBox(height: 16),
                  _buildQuickActions(),
                  const SizedBox(height: 32),

                  _buildRecentActivity(complaints),
                  const SizedBox(height: 120), // Bottom padding for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebLayout(
    String userName,
    int resolved,
    int inProgress,
    int pending,
    int escalated,
    List<Complaint> complaints,
    AsyncValue<CisResult?> cisAsync,
  ) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Web hero: slim banner
              _buildWebHeroBanner(context, userName, cisAsync),
              const SizedBox(height: 24),
              const WardWeatherWidget(),
              const SizedBox(height: 32),
              // Web KPI: horizontal strip
              _buildSectionHeader('SYSTEM OVERVIEW'),
              const SizedBox(height: 16),
              _buildWebKpiStrip(
                resolved,
                inProgress,
                pending,
                escalated,
                complaints.length,
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Activity
                  Expanded(flex: 3, child: _buildRecentActivity(complaints)),
                  const SizedBox(width: 32),
                  // Right Column: Actions
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('QUICK ACTIONS'),
                        const SizedBox(height: 16),
                        _buildWebQuickActions(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWebHeroBanner(BuildContext context, String name, AsyncValue<CisResult?> cisAsync) {
    return cisAsync.when(
      data: (cis) {
        final double scoreValue = cis?.totalScore ?? 0.0;
        final String scoreStr = scoreValue > 0 ? scoreValue.toStringAsFixed(1) : '-';
        String tier = 'Contributor';
        if (scoreValue >= 80) tier = 'Civic Leader';
        else if (scoreValue >= 50) tier = 'Active Patriot';
        else if (scoreValue < 20 && scoreValue > 0) tier = 'Novice';

        return GestureDetector(
          onTap: () {
            if (cis != null && !cis.pending) {
              HapticFeedback.lightImpact();
              _showCisBreakdown(context, cis);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Community Performance',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Welcome back, $name',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 56,
                            height: 56,
                            child: CircularProgressIndicator(
                              value: scoreValue / 100,
                              strokeWidth: 6,
                              color: Colors.white,
                              backgroundColor: Colors.white.withValues(alpha: 0.15),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Text(
                            scoreStr,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Civic Impact Score',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            cis != null && !cis.pending ? tier : 'Pending',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildFallbackWelcomeCard(name),
    );
  }

  Widget _buildWebKpiStrip(
      int resolved, int active, int pending, int escalated, int total) {
    return Row(
      children: [
        Expanded(
          child: _webKpiCard(
            'Resolved',
            resolved,
            const Color(0xFF2E7D32),
            Icons.task_alt_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _webKpiCard(
            'Pending',
            pending,
            const Color(0xFFE65100),
            Icons.hourglass_empty_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _webKpiCard(
            'In Work',
            active,
            const Color(0xFF1565C0),
            Icons.engineering_rounded,
          ),
        ),
        if (escalated > 0) ...[
          const SizedBox(width: 16),
          Expanded(
            child: _webKpiCard(
              'Escalated',
              escalated,
              AppTheme.error,
              Icons.warning_rounded,
            ),
          ),
        ],
        const SizedBox(width: 16),
        Expanded(
          child: _webKpiCard(
            'Total',
            total,
            const Color(0xFF7B1FA2),
            Icons.analytics_rounded,
          ),
        ),
      ],
    );
  }

  Widget _webKpiCard(String label, int value, Color accent, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.grey[400],
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebQuickActions() {
    return Column(
      children: [
        _webActionTile(
          icon: Icons.map_rounded,
          label: 'Open Map Hub',
          color: Colors.blue,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MapScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _webActionTile(
          icon: Icons.support_agent_rounded,
          label: 'Contact Support',
          color: Colors.deepOrange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelplineScreen()),
          ),
        ),
        const SizedBox(height: 12),
        _webActionTile(
          icon: Icons.verified_user_rounded,
          label: 'Council Directory',
          color: Colors.teal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CouncilDirectoryScreen()),
          ),
        ),
      ],
    );
  }

  Widget _webActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey[300],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Colors.grey[500],
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, String name, AsyncValue<CisResult?> cisAsync) {
    return cisAsync.when(
      data: (cis) {
        final double scoreValue = cis?.totalScore ?? 0.0;
        final String scoreStr = scoreValue > 0 ? scoreValue.toStringAsFixed(1) : '-';
        
        String tier = 'Contributor';
        if (scoreValue >= 80) tier = 'Civic Leader';
        else if (scoreValue >= 50) tier = 'Active Patriot';
        else if (scoreValue < 20 && scoreValue > 0) tier = 'Novice';

        return GestureDetector(
          onTap: () {
            if (cis != null && !cis.pending) {
              HapticFeedback.lightImpact();
              _showCisBreakdown(context, cis);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          cis != null && !cis.pending
                              ? 'Civic Impact: $tier'
                              : 'Civic Impact: Pending',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: CircularProgressIndicator(
                        value: scoreValue / 100,
                        strokeWidth: 6,
                        color: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text(
                      scoreStr,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildFallbackWelcomeCard(name),
    );
  }

  Widget _buildFallbackWelcomeCard(String name) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back,',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showCisBreakdown(BuildContext context, CisResult cis) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Score Methodology Breakdown',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your 100-point Civic Impact Score quantifies your contribution using five verified metrics.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Metrics
                _buildBreakdownRow(
                  'Ward Contribution Ratio (WCR)',
                  'Active grievances reported in your ward.',
                  cis.breakdown['WCR'] ?? 0,
                  30.0,
                  Icons.report_gmailerrorred_rounded,
                ),
                _buildBreakdownRow(
                  'Upvote Genesis Impact (UGI)',
                  'Community validation of your reports.',
                  cis.breakdown['UGI'] ?? 0,
                  20.0,
                  Icons.thumb_up_alt_rounded,
                ),
                _buildBreakdownRow(
                  'Civic Validation Participation (CVP)',
                  'Your upvoting activity across the platform.',
                  cis.breakdown['CVP'] ?? 0,
                  20.0,
                  Icons.how_to_vote_rounded,
                ),
                _buildBreakdownRow(
                  'Consistency Index (CI)',
                  'Sustained engagement since registration.',
                  cis.breakdown['CI'] ?? 0,
                  15.0,
                  Icons.calendar_month_rounded,
                ),
                _buildBreakdownRow(
                  'Noise Prevention Factor (NPF)',
                  'Report authenticity & spam avoidance.',
                  cis.breakdown['NPF'] ?? 0,
                  15.0,
                  Icons.verified_user_rounded,
                ),
                
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBreakdownRow(
    String title,
    String desc,
    double value,
    double max,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${value.toStringAsFixed(1)} / ${max.toInt()}',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: value / max,
                  backgroundColor: AppTheme.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoGrid(
      int resolved, int active, int pending, int escalated, int total) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _bentoItem(
                'RESOLVED',
                resolved.toString(),
                const Color(0xFFE8F5E9),
                const Color(0xFF2E7D32),
                Icons.task_alt_rounded,
                'Issues Closed',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bentoItem(
                'PENDING',
                pending.toString(),
                const Color(0xFFFFF3E0),
                const Color(0xFFE65100),
                Icons.hourglass_empty_rounded,
                'Awaiting Verification',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _bentoItem(
                'IN WORK',
                active.toString(),
                const Color(0xFFE3F2FD),
                const Color(0xFF1565C0),
                Icons.engineering_rounded,
                'Active Fixes',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _bentoItem(
                'TOTAL',
                total.toString(),
                const Color(0xFFF3E5F5),
                const Color(0xFF7B1FA2),
                Icons.analytics_rounded,
                'Community Reports',
              ),
            ),
          ],
        ),
        if (escalated > 0) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bentoItem(
                  'ESCALATED',
                  escalated.toString(),
                  AppTheme.error.withValues(alpha: 0.1),
                  AppTheme.error,
                  Icons.warning_rounded,
                  'SLA Breach',
                ),
              ),
              const SizedBox(width: 12),
              const Spacer(),
            ],
          ),
        ],
      ],
    );
  }

  Widget _bentoItem(
    String label,
    String value,
    Color bg,
    Color accent,
    IconData icon,
    String subtext,
  ) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                const Spacer(),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                    color: accent,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _actionTile(
            icon: Icons.map_rounded,
            label: 'Map Hub',
            color: Colors.blue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            icon: Icons.support_agent_rounded,
            label: 'Helpline',
            color: Colors.deepOrange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelplineScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _actionTile(
            icon: Icons.verified_user_rounded,
            label: 'Council',
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CouncilDirectoryScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity(List<Complaint> complaints) {
    final recent = [...complaints]..sort((a, b) => b.date.compareTo(a.date));
    final displayList = recent.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('LIVE ACTIVITY'),
        const SizedBox(height: 16),
        ...displayList.map((c) => _activityItem(c)),
      ],
    );
  }

  Widget _activityItem(Complaint c) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ComplaintDetailScreen(complaint: c),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            _statusCircle(c.status),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${c.ward} • ${DateFormat('hh:mm a').format(c.date)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusCircle(ComplaintStatus status) {
    final color = Color(status.colorValue);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }
}
