import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/complaint.dart';
import '../../models/user_models.dart';
import '../../models/field_worker.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/field_worker_provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../complaint_detail/complaint_detail_screen.dart';
import '../map_screen.dart';


// ─── Helpers ─────────────────────────────────────────────────────────────────
String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

String _timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

Color _priorityColor(ComplaintPriority p) {
  return AppTheme.primary;
}

// ─── Main Widget ──────────────────────────────────────────────────────────────
class FieldManagerDashboard extends ConsumerStatefulWidget {
  const FieldManagerDashboard({super.key});

  @override
  ConsumerState<FieldManagerDashboard> createState() =>
      _FieldManagerDashboardState();
}

class _FieldManagerDashboardState extends ConsumerState<FieldManagerDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(complaintProvider.notifier).loadGrievances(limit: 100);
      ref.read(fieldWorkerProvider.notifier).loadWorkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user!;
    final dept = user.department ?? Department.sanitation;
    final grievanceState = ref.watch(complaintProvider);
    final allComplaints = grievanceState.complaints;
    final workers = ref.watch(fieldWorkerProvider);

    // Show full-screen loader on first load (empty + loading)
    if (grievanceState.isLoading && allComplaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 16),
            Text(
              'Loading dashboard…',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    // Show error state when load failed and we have no data
    if (grievanceState.error != null && allComplaints.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                grievanceState.error!,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Check that the API URL is correct (e.g. your PC IP if on device) and the server is running.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(complaintProvider.notifier).clearError();
                  ref
                      .read(complaintProvider.notifier)
                      .loadGrievances(limit: 100);
                  ref.read(fieldWorkerProvider.notifier).loadWorkers();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final workerLoadError = ref.watch(fieldWorkerLoadErrorProvider);

    // No client-side filtering: API already filters by ward_id and category_dept (IDs)
    final myComplaints = allComplaints;
    final myWorkers = workers;

    final apiReturnedNoData =
        allComplaints.isEmpty && workers.isEmpty && workerLoadError == null;

    final resolved = myComplaints
        .where((c) => c.status == ComplaintStatus.completed)
        .length;
    final assigned = myComplaints
        .where((c) => c.status == ComplaintStatus.incompleteAssigned)
        .length;
    final pending = myComplaints
        .where((c) => c.status == ComplaintStatus.incompleteUnassigned)
        .length;
    final inProgress = myComplaints
        .where((c) => c.status == ComplaintStatus.ongoing)
        .length;
    final onDuty = myWorkers
        .where((w) => w.status == FieldWorkerStatus.onDuty)
        .length;
    final escalated = myComplaints.where((c) {
      if (c.status == ComplaintStatus.completed) return false;
      return DateTime.now().difference(c.date).inHours > 48;
    }).length;

    return ResponsiveLayout(
      mobile: _MobileLayout(
        user: user,
        dept: dept,
        complaints: myComplaints,
        workers: myWorkers,
        resolved: resolved,
        assigned: assigned,
        pending: pending,
        inProgress: inProgress,
        onDuty: onDuty,
        escalated: escalated,
        workerLoadError: workerLoadError,
        apiReturnedNoData: apiReturnedNoData,
      ),
      desktop: _WebLayout(
        user: user,
        dept: dept,
        complaints: myComplaints,
        workers: myWorkers,
        resolved: resolved,
        assigned: assigned,
        pending: pending,
        inProgress: inProgress,
        onDuty: onDuty,
        escalated: escalated,
        workerLoadError: workerLoadError,
        apiReturnedNoData: apiReturnedNoData,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MOBILE
// ═══════════════════════════════════════════════════════════════════════════════
class _MobileLayout extends ConsumerWidget {
  final UserProfile user;
  final Department dept;
  final List<Complaint> complaints;
  final List<FieldWorker> workers;
  final int resolved, assigned, pending, inProgress, onDuty, escalated;
  final String? workerLoadError;
  final bool apiReturnedNoData;

  const _MobileLayout({
    required this.user,
    required this.dept,
    required this.complaints,
    required this.workers,
    required this.resolved,
    required this.assigned,
    required this.pending,
    required this.inProgress,
    required this.onDuty,
    required this.escalated,
    this.workerLoadError,
    this.apiReturnedNoData = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = complaints.length;
    final score = total == 0 ? 0 : (resolved / total * 100).toInt();
    final recent = [...complaints]..sort((a, b) => b.date.compareTo(a.date));

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.read(complaintProvider.notifier).loadGrievances(limit: 100);
        ref.read(fieldWorkerProvider.notifier).loadWorkers();
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
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
              onPressed: () => Scaffold.of(context).openDrawer(),
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
            actions: const [SizedBox(width: 8)],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Welcome Card ──────────────────────
                  Container(
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
                                _greeting(),
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.name.split(' ')[0],
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _DeptBadge(dept: dept, isWeb: false),
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
                                value: score / 100,
                                strokeWidth: 6,
                                color: Colors.white,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                strokeCap: StrokeCap.round,
                              ),
                            ),
                            Text(
                              '$score',
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
                  const SizedBox(height: 32),

                  _SectionLabel('SYSTEM OVERVIEW'),
                  const SizedBox(height: 16),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _BentoCard(
                              title: 'RESOLVED',
                              value: resolved,
                              icon: Icons.task_alt_rounded,
                              color: AppTheme.success,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BentoCard(
                              title: 'PENDING',
                              value: pending,
                              icon: Icons.hourglass_empty_rounded,
                              color: AppTheme.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _BentoCard(
                              title: 'IN WORK',
                              value: inProgress,
                              icon: Icons.engineering_rounded,
                              color: AppTheme.info,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _BentoCard(
                              title: 'ASSIGNED',
                              value: assigned,
                              icon: Icons.assignment_ind_rounded,
                              color: const Color(0xFF5E5CE6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  _SectionLabel('WORKFORCE'),
                  const SizedBox(height: 14),
                  _WorkforceCard(
                    total: workers.length,
                    onDuty: onDuty,
                    offDuty: workers.length - onDuty,
                  ),
                  const SizedBox(height: 32),

                  _SectionLabel('WARD HOTSPOTS'),
                  const SizedBox(height: 14),
                  _WardMapCard(complaints: complaints, dept: dept, height: 260),
                  const SizedBox(height: 32),

                  _SectionLabel('RECENT ACTIVITY'),
                  const SizedBox(height: 14),
                  ...recent.take(6).map((c) => _ActivityTile(complaint: c)),
                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WEB / TABLET
// ═══════════════════════════════════════════════════════════════════════════════
class _WebLayout extends ConsumerWidget {
  final UserProfile user;
  final Department dept;
  final List<Complaint> complaints;
  final List<FieldWorker> workers;
  final int resolved, assigned, pending, inProgress, onDuty, escalated;
  final String? workerLoadError;
  final bool apiReturnedNoData;

  const _WebLayout({
    required this.user,
    required this.dept,
    required this.complaints,
    required this.workers,
    required this.resolved,
    required this.assigned,
    required this.pending,
    required this.inProgress,
    required this.onDuty,
    required this.escalated,
    this.workerLoadError,
    this.apiReturnedNoData = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = complaints.length;
    final score = total == 0 ? 0 : (resolved / total * 100).toInt();
    final recent = [...complaints]..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Web Hero Banner ─────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 32,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                            'Departmental Performance',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.name,
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
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
                                  value: score / 100,
                                  strokeWidth: 6,
                                  color: Colors.white,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.15,
                                  ),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Text(
                                '$score%',
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
                                'Impact Score',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              _DeptBadge(dept: dept, isWeb: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (escalated > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: AppTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Attention!',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$escalated grievances have exceeded the 48h SLA response time.',
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

              _SectionLabel('SYSTEM OVERVIEW'),
              const SizedBox(height: 16),
              // ── Web KPI Strip ─────────────────────
              Row(
                children: [
                  Expanded(
                    child: _BentoCard(
                      title: 'RESOLVED',
                      value: resolved,
                      icon: Icons.task_alt_rounded,
                      color: AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BentoCard(
                      title: 'PENDING',
                      value: pending,
                      icon: Icons.hourglass_empty_rounded,
                      color: AppTheme.warning,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BentoCard(
                      title: 'IN WORK',
                      value: inProgress,
                      icon: Icons.engineering_rounded,
                      color: AppTheme.info,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BentoCard(
                      title: 'ASSIGNED',
                      value: assigned,
                      icon: Icons.assignment_ind_rounded,
                      color: const Color(0xFF5E5CE6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left — Map & Activity
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('WARD HOTSPOTS'),
                        const SizedBox(height: 16),
                        _WardMapCard(
                          complaints: complaints,
                          dept: dept,
                          height: 440,
                        ),
                        const SizedBox(height: 32),
                        _SectionLabel('RECENT ACTIVITY'),
                        const SizedBox(height: 16),
                        ...recent
                            .take(10)
                            .map((c) => _ActivityTile(complaint: c)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Right — Workforce
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionLabel('WORKFORCE'),
                        const SizedBox(height: 16),
                        _WorkforceCard(
                          total: workers.length,
                          onDuty: onDuty,
                          offDuty: workers.length - onDuty,
                        ),
                        const SizedBox(height: 32),
                        _SectionLabel('QUICK ACTIONS'),
                        const SizedBox(height: 16),
                        _webActionTile(
                          icon: Icons.map_rounded,
                          label: 'WARD ANALYTICS',
                          color: Colors.blue,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MapScreen(),
                            ),
                          ),
                        ),
                        _webActionTile(
                          icon: Icons.groups_rounded,
                          label: 'STAFF DIRECTORY',
                          color: Colors.teal,
                          onTap: () {},
                        ),
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: AppTheme.textPrimary.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _BentoCard extends StatefulWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color color;

  const _BentoCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  State<_BentoCard> createState() => _BentoCardState();
}

class _BentoCardState extends State<_BentoCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${widget.value}',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkforceCard extends StatelessWidget {
  final int total, onDuty, offDuty;
  const _WorkforceCard({
    required this.total,
    required this.onDuty,
    required this.offDuty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '$total Field Assistants',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          _dot(AppTheme.success, '$onDuty On Duty'),
          const SizedBox(width: 16),
          _dot(AppTheme.textSecondary, '$offDuty Off'),
        ],
      ),
    );
  }

  Widget _dot(Color c, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _WardMapCard extends StatelessWidget {
  final List<Complaint> complaints;
  final Department dept;
  final double height;
  const _WardMapCard({
    required this.complaints,
    required this.dept,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final center = complaints.isNotEmpty
        ? LatLng(complaints.first.latitude, complaints.first.longitude)
        : const LatLng(28.6139, 77.2090);

    return Container(
      height: height,
      decoration: AppTheme.cardDecoration(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(initialCenter: center, initialZoom: 14.0),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.grievance_app',
                ),
                MarkerLayer(
                  markers: complaints.map((c) {
                    return Marker(
                      point: LatLng(c.latitude, c.longitude),
                      width: 34,
                      height: 34,
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ComplaintDetailScreen(complaint: c),
                          ),
                        ),
                        child: _MapDot(
                          color: Color(c.status.colorValue),
                          icon: c.category.icon,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(initialComplaints: complaints),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.fullscreen_rounded,
                      size: 20,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4),
                  ],
                ),
                child: Text(
                  '${complaints.length} ${dept.name} points',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapDot extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _MapDot({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 14),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final Complaint complaint;
  const _ActivityTile({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final statusColor = Color(complaint.status.colorValue);
    final pc = _priorityColor(complaint.priority);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplaintDetailScreen(complaint: complaint),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    complaint.category.icon,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.title,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 10,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${complaint.ward} · ${_timeAgo(complaint.date)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: pc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        complaint.priority.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: pc,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      complaint.status.label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AssignButton extends ConsumerStatefulWidget {
  final Complaint complaint;
  final List<FieldWorker> workers;
  const _AssignButton({required this.complaint, required this.workers});

  @override
  ConsumerState<_AssignButton> createState() => _AssignButtonState();
}

class _AssignButtonState extends ConsumerState<_AssignButton> {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.primary,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showAssignSheet(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'ASSIGN',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  void _showAssignSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _AssignDialog(
        complaint: widget.complaint,
        workers: widget.workers,
        onAssign: (worker) async {
          final err = await ref
              .read(complaintProvider.notifier)
              .assignWorker(
                widget.complaint.id,
                worker.id,
                worker.name,
                worker.phone,
              );
          if (!ctx.mounted) return;
          Navigator.of(ctx).pop();
          if (err != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(err), backgroundColor: AppTheme.error),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Assigned to ${worker.name}'),
                backgroundColor: AppTheme.success,
              ),
            );
          }
        },
      ),
    );
  }
}

class _AssignDialog extends StatefulWidget {
  final Complaint complaint;
  final List<FieldWorker> workers;
  final Future<void> Function(FieldWorker worker) onAssign;
  const _AssignDialog({
    required this.complaint,
    required this.workers,
    required this.onAssign,
  });

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  String? _loadingId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign Field Assistant',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            widget.complaint.title,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.workers.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No field assistants available.',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.workers.length,
                itemBuilder: (_, i) {
                  final w = widget.workers[i];
                  final isOnline = w.status == FieldWorkerStatus.onDuty;
                  final isLoading = _loadingId == w.id;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    leading: CircleAvatar(
                      backgroundColor: isOnline
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : Colors.grey[100],
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primary,
                              ),
                            )
                          : Text(
                              w.name[0],
                              style: TextStyle(
                                color: isOnline
                                    ? AppTheme.success
                                    : Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    title: Text(
                      w.name,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      '${w.designation}  ·  ${w.tasksActive} active',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: isOnline
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.success,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'ON DUTY',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : null,
                    enabled: _loadingId == null,
                    onTap: () async {
                      setState(() => _loadingId = w.id);
                      await widget.onAssign(w);
                      if (mounted) setState(() => _loadingId = null);
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _DeptBadge extends StatelessWidget {
  final Department dept;
  final bool isWeb;
  const _DeptBadge({required this.dept, this.isWeb = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(dept.icon, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            dept.shortCode,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
