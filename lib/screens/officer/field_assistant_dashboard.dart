import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/complaint.dart';
import '../../models/user_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/worker_nav_provider.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/ward_weather_widget.dart';
import '../map_screen.dart';


// ═══════════════════════════════════════════════════════════════════════════════
// CivicCare Worker Dashboard — Apple Native Premium Redesign
// ═══════════════════════════════════════════════════════════════════════════════

// ── Helpers ───────────────────────────────────────────────────────────────────

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

const _dayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _dayAbbr = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtDate(DateTime d) =>
    '${_dayNames[d.weekday - 1]}, ${_monthNames[d.month - 1]} ${d.day}';

String _fmtTime12(DateTime dt) {
  final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
  final m = dt.minute.toString().padLeft(2, '0');
  final ap = dt.hour >= 12 ? 'PM' : 'AM';
  return '$h:$m $ap';
}

String _timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

// ═══════════════════════════════════════════════════════════════════════════════
// Main Dashboard
// ═══════════════════════════════════════════════════════════════════════════════

class FieldAssistantDashboard extends ConsumerStatefulWidget {
  const FieldAssistantDashboard({super.key});

  @override
  ConsumerState<FieldAssistantDashboard> createState() =>
      _FieldAssistantDashboardState();
}

class _FieldAssistantDashboardState
    extends ConsumerState<FieldAssistantDashboard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  Timer? _minuteTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(attendanceProvider.notifier).fetchStatus();
        ref.read(attendanceProvider.notifier).fetchHistory();
        ref.read(complaintProvider.notifier).loadGrievances(workerId: user.id);
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AttendanceState>(attendanceProvider, (prev, next) {
      if (next.error == null) return;
      if (prev != null && prev.error == next.error) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        ref.read(attendanceProvider.notifier).clearError();
      });
    });

    ref.listen(workerSelectedTabProvider, (prev, next) {
      if (next == 0) {
        final user = ref.read(authProvider).user;
        if (user != null) {
          ref.read(complaintProvider.notifier).loadGrievances(workerId: user.id);
          ref.read(attendanceProvider.notifier).fetchStatus();
          ref.read(attendanceProvider.notifier).fetchHistory();
        }
      }
    });

    final user = ref.watch(authProvider).user!;
    final complaints = ref.watch(complaintListProvider);
    final mine = complaints.where((c) => c.assignedToId == user.id).toList();
    final pad = ResponsiveUtils.isMobile(context) ? 20.0 : 32.0;

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await Future.wait([
            ref
                .read(complaintProvider.notifier)
                .loadGrievances(workerId: user.id),
            ref.read(attendanceProvider.notifier).fetchStatus(),
            ref.read(attendanceProvider.notifier).fetchHistory(),
          ]);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            // ── iOS Large Title App Bar ───────────────────────────────────
            SliverAppBar(
              expandedHeight: 120,
              collapsedHeight: 60,
              pinned: true,
              backgroundColor: AppTheme.surfaceScaffold,
              scrolledUnderElevation: 0,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.black87),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
              actions: const [SizedBox(width: 8)],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
                title: Text(
                  'Dashboard',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                  ),
                ),
              ),
            ),

            // ── Greeting Hero Banner ─────────────────────────────────────
            SliverToBoxAdapter(child: _HeroBanner(user: user)),

            // ── Dashboard Content ────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 24),

                  // Attendance Card
                  _AttendanceCard(pulseCtrl: _pulseCtrl),
                  const SizedBox(height: 20),
                  const WardWeatherWidget(),
                  const SizedBox(height: 28),

                  // Task Summary
                  _SectionLabel(label: 'My Workload'),
                  const SizedBox(height: 12),
                  _TaskSummaryRow(mine: mine),
                  const SizedBox(height: 28),

                  // Performance
                  _SectionLabel(label: 'Performance'),
                  const SizedBox(height: 12),
                  _PerformanceSection(mine: mine),
                  const SizedBox(height: 28),

                  // Quick Actions
                  _SectionLabel(label: 'Quick Actions'),
                  const SizedBox(height: 12),
                  _QuickActionsRow(),
                  const SizedBox(height: 28),

                  // Recent Activity
                  _SectionLabel(label: 'Recent Activity'),
                  const SizedBox(height: 12),
                  _RecentActivitySection(mine: mine),

                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 120,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Section Label
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 1. Hero Banner — Clean, light, Apple native
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroBanner extends StatelessWidget {
  final UserProfile user;
  const _HeroBanner({required this.user});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: AppTheme.cardDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _greeting(),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  _fmtTime12(now),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              user.name.split(' ').first,
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                height: 1.2,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Pill(
                  icon: Icons.badge_outlined,
                  label: user.department?.assistantTitle ?? 'Field Assistant',
                ),
                if (user.ward.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _Pill(
                    icon: Icons.location_on_outlined,
                    label: user.ward,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _fmtDate(now),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 2. Attendance Card
// ═══════════════════════════════════════════════════════════════════════════════

class _AttendanceCard extends ConsumerWidget {
  final AnimationController pulseCtrl;
  const _AttendanceCard({required this.pulseCtrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final att = ref.watch(attendanceProvider);
    final notifier = ref.read(attendanceProvider.notifier);

    return Container(
      decoration: AppTheme.cardDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: att.isClockedIn
            ? _ClockedInView(att: att, notifier: notifier)
            : _ClockedOutView(
                att: att,
                notifier: notifier,
                pulseCtrl: pulseCtrl,
              ),
      ),
    );
  }
}

// ── Clocked In ───────────────────────────────────────────────────────────────

class _ClockedInView extends StatelessWidget {
  final AttendanceState att;
  final AttendanceNotifier notifier;
  const _ClockedInView({required this.att, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ON DUTY',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  Text(
                    'Shift Active',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            _LiveDot(),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          att.dutyDurationFormatted,
          style: GoogleFonts.outfit(
            fontSize: 44,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            letterSpacing: 0.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          'Hours · Minutes · Seconds',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceScaffold,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ClockStat(
                  icon: Icons.login_rounded,
                  label: 'Clocked In',
                  value: att.clockInTime != null
                      ? _fmtTime12(att.clockInTime!)
                      : '--:--',
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppTheme.border,
              ),
              Expanded(
                child: _ClockStat(
                  icon: Icons.gps_fixed_rounded,
                  label: 'Location',
                  value: att.currentLocation != null ? 'Tracking' : 'Waiting...',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: att.isLoading
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    notifier.clockOut();
                  },
            icon: att.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.logout_rounded, size: 20),
            label: Text(
              att.isLoading ? 'Processing...' : 'End Shift',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Live',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ClockStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Clocked Out ──────────────────────────────────────────────────────────────

class _ClockedOutView extends StatelessWidget {
  final AttendanceState att;
  final AttendanceNotifier notifier;
  final AnimationController pulseCtrl;
  const _ClockedOutView({
    required this.att,
    required this.notifier,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.fingerprint_rounded,
                color: AppTheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to start?',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Clock in to begin your shift',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: AnimatedBuilder(
            animation: pulseCtrl,
            builder: (context, child) {
              final scale = 1.0 + (pulseCtrl.value * 0.012);
              return Transform.scale(
                scale: att.isLoading ? 1.0 : scale,
                child: child,
              );
            },
            child: ElevatedButton.icon(
              onPressed: att.isLoading
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      notifier.clockIn();
                    },
              icon: att.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(
                att.isLoading ? 'Connecting...' : 'Start Shift',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 3. Task Summary Row
// ═══════════════════════════════════════════════════════════════════════════════

class _TaskSummaryRow extends StatelessWidget {
  final List<Complaint> mine;
  const _TaskSummaryRow({required this.mine});

  @override
  Widget build(BuildContext context) {
    final c = statusCounts(mine);
    final active = c.inProgress;
    final pending = c.assigned;
    final completed = c.resolved;
    final escalated = c.escalated;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.bolt_rounded,
            iconBg: AppTheme.warning.withValues(alpha: 0.12),
            iconColor: AppTheme.warning,
            count: active,
            label: 'Active',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.schedule_rounded,
            iconBg: AppTheme.info.withValues(alpha: 0.12),
            iconColor: AppTheme.info,
            count: pending,
            label: 'Pending',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_rounded,
            iconBg: AppTheme.success.withValues(alpha: 0.12),
            iconColor: AppTheme.success,
            count: completed,
            label: 'Done',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.warning_amber_rounded,
            iconBg: AppTheme.error.withValues(alpha: 0.12),
            iconColor: AppTheme.error,
            count: escalated,
            label: 'Escalated',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg, iconColor;
  final int count;
  final String label;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(
            '$count',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 4. Performance Section
// ═══════════════════════════════════════════════════════════════════════════════

class _PerformanceSection extends ConsumerWidget {
  final List<Complaint> mine;
  const _PerformanceSection({required this.mine});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final att = ref.watch(attendanceProvider);
    final total = mine.length;
    final resolved = statusCounts(mine).resolved;
    final rate = total == 0 ? 0.0 : resolved / total;
    final shiftHrs = att.isClockedIn ? att.dutyDurationHoursExact : 0.0;
    final today = DateTime.now().weekday;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _CompletionRingCard(
            rate: rate,
            resolved: resolved,
            total: total,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            children: [
              _ShiftHoursCard(
                hoursProgress: shiftHrs,
                durationLabel: att.isClockedIn ? att.dutyDurationShortLabel : '0s',
              ),
              const SizedBox(height: 12),
              _WeeklyCard(today: today),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompletionRingCard extends StatelessWidget {
  final double rate;
  final int resolved;
  final int total;
  const _CompletionRingCard({
    required this.rate,
    required this.resolved,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: [
          SizedBox(
            width: 88,
            height: 88,
            child: CustomPaint(
              painter: _RingPainter(
                progress: rate,
                trackColor: AppTheme.surface,
                progressColor: AppTheme.primary,
                strokeWidth: 9,
              ),
              child: Center(
                child: Text(
                  '${(rate * 100).toInt()}%',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Completion',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$resolved of $total tasks',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftHoursCard extends StatelessWidget {
  /// Fraction of an 8h shift (0–∞; bar clamps at 100%).
  final double hoursProgress;
  /// Human-readable elapsed time (not decimal hours — avoids 0.56 vs 0.0 confusion).
  final String durationLabel;

  const _ShiftHoursCard({
    required this.hoursProgress,
    required this.durationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bar = (hoursProgress / 8).clamp(0.0, 1.0);
    final fullShift = hoursProgress >= 8;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.access_time_filled_rounded,
                size: 15,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Shift Hours',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                durationLabel,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  height: 1,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 2),
                child: Text(
                  '/ 8h',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: bar,
              minHeight: 6,
              backgroundColor: AppTheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                fullShift ? AppTheme.success : AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyCard extends ConsumerWidget {
  final int today;
  const _WeeklyCard({required this.today});

  bool _hasRecordForDay(List<dynamic> history, DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return history.any((r) => r['date'] == dateStr);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(attendanceProvider).history;
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final dayNum = i + 1;
              final dayDate = monday.add(Duration(days: i));
              final hasRecord = _hasRecordForDay(history, dayDate);
              final isToday = dayNum == today;

              return Expanded(
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primary
                          : hasRecord
                              ? AppTheme.primaryLight
                              : AppTheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _dayAbbr[i],
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isToday
                              ? Colors.white
                              : hasRecord
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final bar = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        bar,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}

// ═══════════════════════════════════════════════════════════════════════════════
// 5. Quick Actions
// ═══════════════════════════════════════════════════════════════════════════════

class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.task_alt_rounded,
            label: 'Tasks',
            color: AppTheme.primary,
            bg: AppTheme.primaryLight,
            onTap: () {
              ref.read(workerTabToSelectProvider.notifier).state = 1;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.schedule_rounded,
            label: 'Attendance',
            color: AppTheme.success,
            bg: AppTheme.success.withValues(alpha: 0.10),
            onTap: () {
              ref.read(workerTabToSelectProvider.notifier).state = 2;
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            icon: Icons.map_rounded,
            label: 'Map View',
            color: AppTheme.info,
            bg: AppTheme.info.withValues(alpha: 0.10),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MapScreen()),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color, bg;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// 6. Recent Activity
// ═══════════════════════════════════════════════════════════════════════════════

class _RecentActivitySection extends StatelessWidget {
  final List<Complaint> mine;
  const _RecentActivitySection({required this.mine});

  @override
  Widget build(BuildContext context) {
    final sorted = List<Complaint>.from(mine)
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = sorted.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mine.length > 5)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'View all',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ),
        if (recent.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            decoration: AppTheme.cardDecoration(),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_rounded,
                  size: 44,
                  color: AppTheme.textSecondary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 14),
                Text(
                  'No recent activity',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tasks will appear here as they come in',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: AppTheme.cardDecoration(),
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  _ActivityRow(complaint: recent[i]),
                  if (i < recent.length - 1)
                    Divider(
                      height: 1,
                      indent: 44,
                      endIndent: 20,
                      color: AppTheme.border.withValues(alpha: 0.6),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final Complaint complaint;
  const _ActivityRow({required this.complaint});

  Color get _priorityColor {
    switch (complaint.priority) {
      case ComplaintPriority.high:
        return AppTheme.error;
      case ComplaintPriority.medium:
        return AppTheme.warning;
      case ComplaintPriority.low:
        return AppTheme.success;
    }
  }

  Color get _statusColor {
    switch (complaint.status) {
      case ComplaintStatus.completed:
        return AppTheme.success;
      case ComplaintStatus.ongoing:
        return AppTheme.warning;
      case ComplaintStatus.incompleteAssigned:
        return AppTheme.info;
      case ComplaintStatus.incompleteUnassigned:
        return AppTheme.textSecondary;
      case ComplaintStatus.escalated:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complaint.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${complaint.status.label}  ·  ${_timeAgo(complaint.date)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _priorityColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              complaint.priority.name.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _priorityColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
