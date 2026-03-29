import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_models.dart';
import '../providers/auth_provider.dart';
import '../providers/analytics_provider.dart';
import '../providers/complaint_provider.dart';
import '../core/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../utils/launch_links.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CivicCare Profile — Apple Native Premium
// Worker-enhanced with performance stats, duty status, department info
// ═══════════════════════════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final profileAsync = ref.watch(profileDetailsProvider);
    final String userName =
        effectiveUser?.name ?? ref.watch(userNameProvider) ?? 'Guest';
    final userWard = ref.watch(userWardProvider);
    final complaints = ref.watch(complaintListProvider);
    final cisAsync = ref.watch(userCisProvider);

    final myComplaints =
        complaints.where((c) => c.userName == userName).toList();

    final details = profileAsync.value;
    final loadError = profileAsync.error?.toString();

    final profileContent = profileAsync.isLoading
        ? const Center(child: CircularProgressIndicator())
        : _buildContent(
            context,
            ref,
            userName,
            userWard,
            effectiveUser,
            myComplaints,
            cisAsync,
            profileDetails: details,
            loadError: loadError,
          );

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: ResponsiveLayout(
        mobile: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor:
                  AppTheme.surfaceScaffold.withValues(alpha: 0.8),
              elevation: 0,
              scrolledUnderElevation: 0,
              pinned: true,
              expandedHeight: 140,
              collapsedHeight: 60,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: AppTheme.textPrimary,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 16),
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Account',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (details != null)
                      Text(
                        (details['role'] as String? ?? 'Citizen')
                            .toUpperCase()
                            .replaceAll('FIELDMANAGER', 'FIELD MANAGER')
                            .replaceAll('FIELDASSISTANT', 'FIELD ASSISTANT'),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          body: profileContent,
        ),
        desktop: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  backgroundColor: AppTheme.surfaceScaffold,
                  elevation: 0,
                  pinned: true,
                  automaticallyImplyLeading: false,
                  title: Text(
                    'My Profile',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                    ),
                  ),
                ),
              ],
              body: profileContent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    String userName,
    String userWard,
    UserProfile? effectiveUser,
    List myComplaints,
    AsyncValue<CisResult?> cisAsync, {
    Map<String, dynamic>? profileDetails,
    String? loadError,
  }) {
    final details = profileDetails ?? {};
    final email = details['email'] as String? ?? effectiveUser?.email;
    final phone = details['phone'] as String? ?? effectiveUser?.phone ?? '--';
    final address = details['address'] as String? ?? effectiveUser?.address;
    final wp = details['worker_profile'] as Map<String, dynamic>?;
    final staffWard = wp?['ward_display'] as String?;
    final citizenWard = details['ward'] as String? ?? userWard;
    final ward = staffWard ?? citizenWard;
    final zone = details['zone'] as String?;
    final roleRaw = details['role'] as String?;
    final roleDisplay = roleRaw
        ?.replaceAll('fieldManager', 'Field Manager')
        .replaceAll('fieldAssistant', 'Field Assistant')
        .replaceAll('citizen', 'Citizen')
        .replaceAll('admin', 'Admin');
    final deptMap = wp?['department'] as Map<String, dynamic>?;
    final departmentName =
        deptMap?['name'] as String? ?? effectiveUser?.department?.name;
    final designationTitle = wp?['designation_title'] as String?;
    final isStaff = effectiveUser?.isStaff == true;
    final rating = wp?['rating'] as num?;
    final ratingsCount = wp?['ratings_count'] is int ? wp!['ratings_count'] as int : 0;
    final currentStatus = wp?['current_status'] as String?;

    return Material(
      color: Colors.transparent,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            if (loadError != null && loadError.isNotEmpty)
              _buildErrorBadge('Sync partially failed: using cached data'),

            // --- Premium Avatar Area ---
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          // Gradient ring for staff
                          border: isStaff
                              ? Border.all(color: AppTheme.primary, width: 3)
                              : null,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: CircleAvatar(
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.05),
                          child: Text(
                            (details['name'] as String? ?? userName)[0]
                                .toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 42,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ),
                      // Duty status indicator (staff only)
                      if (isStaff)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: currentStatus == 'onDuty'
                                    ? AppTheme.success
                                    : AppTheme.textSecondary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                currentStatus == 'onDuty'
                                    ? Icons.check
                                    : Icons.power_settings_new,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    details['name'] as String? ?? userName,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (roleDisplay != null)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        roleDisplay,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  // Duty status text for staff
                  if (isStaff && currentStatus != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: currentStatus == 'onDuty'
                                  ? AppTheme.success
                                  : AppTheme.textSecondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            currentStatus == 'onDuty'
                                ? 'Currently On Duty'
                                : 'Off Duty',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: currentStatus == 'onDuty'
                                  ? AppTheme.success
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Civic Impact Score (Citizens only) ──
            if (!isStaff) ...[
              _buildCisBanner(context, cisAsync),
              const SizedBox(height: 24),
            ],

            // ── Performance Stats Row (Staff only) ──
            if (isStaff) ...[
              Row(
                children: [
                  _StatTile(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFFFB800),
                    label: 'Rating',
                    value: rating != null && ratingsCount > 0
                        ? '${rating.toStringAsFixed(1)} ($ratingsCount)'
                        : '—',
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    icon: Icons.task_alt_rounded,
                    iconColor: AppTheme.success,
                    label: 'Completed',
                    value: (effectiveUser?.tasksCompleted ?? 0).toString(),
                  ),
                  const SizedBox(width: 12),
                  _StatTile(
                    icon: Icons.pending_actions_rounded,
                    iconColor: AppTheme.warning,
                    label: 'Active',
                    value: (effectiveUser?.tasksActive ?? 0).toString(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // --- Bento Section: Account Details ---
            _BentoGroup(
              title: 'ACCOUNT INFORMATION',
              children: [
                _BentoRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: email?.isNotEmpty == true ? email! : '--',
                ),
                _BentoRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: phone,
                  onValueTap: phone != '--' && phone.trim().isNotEmpty
                      ? () => launchPhoneDialer(phone)
                      : null,
                ),
                _BentoRow(
                  icon: Icons.location_on_rounded,
                  label: effectiveUser?.department == null
                      ? 'Ward / Area'
                      : 'Assigned Ward',
                  value: (zone != null &&
                          zone.isNotEmpty &&
                          ward.isNotEmpty)
                      ? '$ward • $zone'
                      : (ward.isNotEmpty ? ward : '--'),
                  showDivider: false,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // --- Bento Section: Professional (for Staff) ---
            if (departmentName != null || address != null)
              _BentoGroup(
                title: 'PROFESSIONAL DETAILS',
                children: [
                  if (departmentName != null)
                    _BentoRow(
                      icon: Icons.work_rounded,
                      label: 'Department',
                      value: designationTitle != null
                          ? '$departmentName ($designationTitle)'
                          : departmentName,
                      showDivider: address != null,
                    ),
                  if (address != null)
                    _BentoRow(
                      icon: Icons.home_rounded,
                      label: 'Address',
                      value: address,
                      showDivider: false,
                    ),
                ],
              ),

            const SizedBox(height: 20),

            // --- Bento Section: Activity ---
            _BentoGroup(
              title: 'ACTIVITY',
              children: [
                if (isStaff) ...[
                  _BentoRow(
                    icon: Icons.task_alt_rounded,
                    label: 'Tasks Completed',
                    value: effectiveUser!.tasksCompleted.toString(),
                  ),
                  _BentoRow(
                    icon: Icons.assignment_rounded,
                    label: 'Active Tasks',
                    value: effectiveUser.tasksActive.toString(),
                  ),
                ],
                _BentoRow(
                  icon: Icons.analytics_rounded,
                  label: 'Total Submissions',
                  value: myComplaints.length.toString(),
                  showDivider: false,
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // --- Logout Button ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.read(authProvider.notifier).logout();
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: AppTheme.error.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: AppTheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: GoogleFonts.inter(
                        color: AppTheme.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _buildCisBanner(BuildContext context, AsyncValue<CisResult?> cisAsync) {
    return cisAsync.when(
      data: (cis) {
        if (cis == null) return const SizedBox.shrink();

        // Determine badge tier
        String tier = 'Contributor';
        Color badgeColor = AppTheme.primary;
        if (cis.pending) {
          tier = 'Pending';
          badgeColor = AppTheme.textSecondary;
        } else if (cis.totalScore >= 80) {
          tier = 'Civic Leader';
          badgeColor = const Color(0xFFFFB800); // Gold
        } else if (cis.totalScore >= 50) {
          tier = 'Active Patriot';
          badgeColor = AppTheme.success;
        } else if (cis.totalScore < 20) {
          tier = 'Novice';
          badgeColor = AppTheme.textSecondary;
        }

        return GestureDetector(
          onTap: () {
            if (cis.pending) return;
            HapticFeedback.lightImpact();
            _showCisBreakdown(context, cis);
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary,
                  AppTheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.diamond_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Civic Impact Score',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            cis.pending ? '—' : cis.totalScore.toStringAsFixed(1),
                            style: GoogleFonts.outfit(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                          if (!cis.pending) ...[
                            const SizedBox(width: 4),
                            Text(
                              '/ 100',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tier,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
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

  Widget _buildErrorBadge(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            color: AppTheme.warning,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Performance Stat Tile (for staff profiles)
// ═══════════════════════════════════════════════════════════════════════════════

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppTheme.cardDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Bento Group & Row (shared)
// ═══════════════════════════════════════════════════════════════════════════════

class _BentoGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _BentoGroup({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: AppTheme.cardDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _BentoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool showDivider;
  final Widget? trailing;
  /// Opens dialer when set (e.g. phone row).
  final VoidCallback? onValueTap;

  const _BentoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.showDivider = true,
    this.trailing,
    this.onValueTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppTheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    onValueTap != null
                        ? InkWell(
                            onTap: onValueTap,
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                value,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppTheme.primary.withValues(alpha: 0.4),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                        : Text(
                            value,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (showDivider)
            Padding(
              padding: const EdgeInsets.only(left: 50, top: 12),
              child: Divider(
                height: 1,
                color: AppTheme.border.withValues(alpha: 0.5),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}
