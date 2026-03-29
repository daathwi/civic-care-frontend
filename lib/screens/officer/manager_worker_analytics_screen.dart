import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_theme.dart';
import '../../providers/analytics_provider.dart';
import '../../repository/analytics_repository.dart';
import '../../utils/responsive_utils.dart';

/// Manager portal: Workforce performance — compact overview, insights, and team list.
class ManagerWorkerAnalyticsScreen extends ConsumerStatefulWidget {
  const ManagerWorkerAnalyticsScreen({super.key});

  @override
  ConsumerState<ManagerWorkerAnalyticsScreen> createState() =>
      _ManagerWorkerAnalyticsScreenState();
}

class _ManagerWorkerAnalyticsScreenState
    extends ConsumerState<ManagerWorkerAnalyticsScreen> {
  int _periodDays = 30;

  /// Use date-only to keep params stable across rebuilds (avoids infinite refetch).
  DateTime get _fromDate => DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ).subtract(Duration(days: _periodDays));
  DateTime get _toDate => DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

  @override
  Widget build(BuildContext context) {
    final params = (
      departmentId: null as String?,
      wardId: null as String?,
      fromDate: _fromDate,
      toDate: _toDate,
    );
    final async = ref.watch(workerAnalyticsProvider(params));
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final horizontalPadding = isDesktop ? 32.0 : 20.0;

    Future<void> onRefresh() async {
      ref.invalidate(workerAnalyticsProvider(params));
    }

    final dataSlivers = async.when<List<Widget>>(
      data: (workers) {
        if (workers.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 80),
                child: _buildEmptyState(),
              ),
            ),
          ];
        }
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 0),
              child: _buildTeamOverview(workers),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 12),
              child: Row(
                children: [
                  Text(
                    'Team',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${workers.length}',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 80),
            sliver: SliverList.separated(
              itemCount: workers.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final w = workers[index];
                return _WorkerAnalyticsCard(
                  worker: w,
                  onTap: () => _openWorkerDetail(w),
                );
              },
            ),
          ),
        ];
      },
      loading: () => [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
      ],
      error: (e, _) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildErrorState(e),
          ),
        ),
      ],
    );

    const scrollPhysics =
        AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics());

    final headerBelowBar = SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontalPadding, isDesktop ? 8 : 12, horizontalPadding, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              Text(
                'Workforce performance',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Text(
                'Team performance & field output',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                _PeriodChip(
                  label: '7d',
                  selected: _periodDays == 7,
                  onTap: () => setState(() => _periodDays = 7),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: '30d',
                  selected: _periodDays == 30,
                  onTap: () => setState(() => _periodDays = 30),
                ),
                const SizedBox(width: 8),
                _PeriodChip(
                  label: '90d',
                  selected: _periodDays == 90,
                  onTap: () => setState(() => _periodDays = 90),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppTheme.primary,
        child: CustomScrollView(
          physics: scrollPhysics,
          slivers: [
            if (!isDesktop)
              SliverAppBar(
                expandedHeight: 120,
                collapsedHeight: 64,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
                flexibleSpace: AppTheme.glass(
                  blur: 20,
                  color: AppTheme.surfaceScaffold.withValues(alpha: 0.7),
                  child: FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
                    title: Text(
                      'Analytics',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
              ),
            headerBelowBar,
            ...dataSlivers,
          ],
        ),
      ),
    );
  }

  Widget _buildTeamOverview(List<WorkerAnalyticsItem> workers) {
    final totalResolved = workers.fold<int>(0, (s, w) => s + w.periodResolved);
    final totalSlaOk = workers.fold<int>(0, (s, w) => s + w.periodSlaOk);
    final totalResolvedForSla =
        workers.fold<int>(0, (s, w) => s + w.periodResolved);
    final slaPct = totalResolvedForSla > 0
        ? (totalSlaOk / totalResolvedForSla * 100).round()
        : 100;
    final rated = workers.where((w) => w.periodAvgRating != null).toList();
    final avgRating = rated.isEmpty
        ? 0.0
        : rated.map((w) => w.periodAvgRating!).fold<double>(0, (s, r) => s + r) /
            rated.length;
    final avgAtt = workers.isEmpty
        ? 0.0
        : workers.map((w) => w.attendanceRate).fold<double>(0, (s, r) => s + r) /
            workers.length;
    final insight = _teamInsightLine(workers);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 22, color: AppTheme.primary.withValues(alpha: 0.9)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Last $_periodDays days · ${workers.length} ${_pluralize(workers.length, 'worker', 'workers')}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 360;
              final stats = [
                _QuickStat(value: '$totalResolved', label: 'Resolved', color: AppTheme.success),
                _QuickStat(value: '$slaPct%', label: 'SLA hit', color: AppTheme.primary),
                _QuickStat(value: '${(avgAtt * 100).round()}%', label: 'Attendance', color: AppTheme.info),
                _QuickStat(
                  value: avgRating > 0 ? avgRating.toStringAsFixed(1) : '—',
                  label: 'Avg rating',
                  color: AppTheme.warning,
                ),
              ];
              if (narrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: stats[0]),
                        Container(width: 1, height: 44, color: AppTheme.border.withValues(alpha: 0.6)),
                        Expanded(child: stats[1]),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: AppTheme.border.withValues(alpha: 0.6)),
                    ),
                    Row(
                      children: [
                        Expanded(child: stats[2]),
                        Container(width: 1, height: 44, color: AppTheme.border.withValues(alpha: 0.6)),
                        Expanded(child: stats[3]),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: stats[0]),
                  Container(width: 1, height: 40, color: AppTheme.border.withValues(alpha: 0.6)),
                  Expanded(child: stats[1]),
                  Container(width: 1, height: 40, color: AppTheme.border.withValues(alpha: 0.6)),
                  Expanded(child: stats[2]),
                  Container(width: 1, height: 40, color: AppTheme.border.withValues(alpha: 0.6)),
                  Expanded(child: stats[3]),
                ],
              );
            },
          ),
          if (insight.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.tips_and_updates_outlined, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.35,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _pluralize(int n, String one, String many) => n == 1 ? one : many;

  /// One line: who stands out on volume and SLA (if data allows).
  String _teamInsightLine(List<WorkerAnalyticsItem> workers) {
    if (workers.isEmpty) return '';
    final byVol = List<WorkerAnalyticsItem>.from(workers)
      ..sort((a, b) => b.periodResolved.compareTo(a.periodResolved));
    final bySla = List<WorkerAnalyticsItem>.from(workers)
      ..sort((a, b) => b.slaRate.compareTo(a.slaRate));
    final topVol = byVol.first;
    final topSla = bySla.first;
    final totalRes = workers.fold<int>(0, (s, w) => s + w.periodResolved);
    if (totalRes == 0) {
      return 'No grievances resolved in this window — extend the period or review assignments.';
    }
    if (topVol.id == topSla.id) {
      return '${topVol.name} leads on output (${topVol.periodResolved} resolved) and SLA (${(topVol.slaRate * 100).round()}%).';
    }
    return '${topVol.name} most resolved (${topVol.periodResolved}). ${topSla.name} strongest SLA (${(topSla.slaRate * 100).round()}%).';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No worker data for this period',
              style: GoogleFonts.inter(
                fontSize: 17,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object e) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text(
              e.toString().length > 80
                  ? '${e.toString().substring(0, 80)}…'
                  : e.toString(),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(workerAnalyticsProvider((
                departmentId: null,
                wardId: null,
                fromDate: _fromDate,
                toDate: _toDate,
              ))),
              icon: const Icon(Icons.refresh),
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

  void _openWorkerDetail(WorkerAnalyticsItem worker) {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _WorkerDetailAnalyticsScreen(
          workerId: worker.id,
          workerName: worker.name,
          fromDate: _fromDate,
          toDate: _toDate,
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _QuickStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _WorkerAnalyticsCard extends StatelessWidget {
  final WorkerAnalyticsItem worker;
  final VoidCallback onTap;

  const _WorkerAnalyticsCard({
    required this.worker,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ward = worker.wardName?.trim();
    final subtitle = [
      if (ward != null && ward.isNotEmpty) ward,
      if (worker.designation.isNotEmpty) worker.designation,
    ].join(' · ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                child: Text(
                  worker.name.isNotEmpty ? worker.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worker.name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Text(
                      '${worker.periodResolved} resolved · ${(worker.slaRate * 100).round()}% SLA · ${(worker.attendanceRate * 100).round()}% att.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _StatusBadge(status: worker.status),
                  const SizedBox(height: 6),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOnDuty = status.toLowerCase() == 'onduty';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOnDuty
            ? AppTheme.success.withValues(alpha: 0.12)
            : AppTheme.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isOnDuty ? 'On duty' : 'Off duty',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isOnDuty ? AppTheme.success : AppTheme.textSecondary,
        ),
      ),
    );
  }
}

/// Full-screen worker detail analytics.
class _WorkerDetailAnalyticsScreen extends ConsumerWidget {
  final String workerId;
  final String workerName;
  final DateTime fromDate;
  final DateTime toDate;

  const _WorkerDetailAnalyticsScreen({
    required this.workerId,
    required this.workerName,
    required this.fromDate,
    required this.toDate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (
      workerId: workerId,
      fromDate: fromDate,
      toDate: toDate,
    );
    final async = ref.watch(workerDetailAnalyticsProvider(params));

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          workerName,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: async.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text('No data'));
          }
          final metrics = data['metrics'] as Map<String, dynamic>? ?? {};
          final timeSeries =
              (data['time_series'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          final ratingSeries =
              (data['rating_series'] as List?)?.cast<Map<String, dynamic>>() ??
                  [];
          final attendance =
              (data['attendance'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMetricsRow(metrics),
                const SizedBox(height: 24),
                if (timeSeries.isNotEmpty) ...[
                  Text(
                    'RESOLUTION TREND',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Daily count of grievances this worker resolved. Shows productivity over the selected period.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _buildResolutionChart(timeSeries),
                  const SizedBox(height: 24),
                ],
                if (ratingSeries.isNotEmpty) ...[
                  Text(
                    'RATINGS TREND',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Average citizen rating (1–5) given each day for resolved grievances. Tracks service quality over time.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _buildRatingChart(ratingSeries),
                  const SizedBox(height: 24),
                ],
                if (attendance.isNotEmpty) ...[
                  Text(
                    'ATTENDANCE',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Days this worker clocked in and out. Duration shows hours worked per day.',
                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _buildAttendanceList(attendance),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(workerDetailAnalyticsProvider(params)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow(Map<String, dynamic> metrics) {
    final tasksCompleted = (metrics['tasks_completed'] as num?)?.toInt() ?? 0;
    final tasksActive = (metrics['tasks_active'] as num?)?.toInt() ?? 0;
    final rating = (metrics['rating'] as num?)?.toDouble();
    final ratingsCount = (metrics['ratings_count'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _DetailMetric(label: 'Completed', value: '$tasksCompleted'),
          _DetailMetric(label: 'Active', value: '$tasksActive'),
          _DetailMetric(
            label: 'Rating',
            value: rating != null ? '${rating.toStringAsFixed(1)} ($ratingsCount)' : '—',
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionChart(List<Map<String, dynamic>> timeSeries) {
    final spots = <FlSpot>[];
    for (var i = 0; i < timeSeries.length; i++) {
      final v = (timeSeries[i]['resolved'] as num?)?.toDouble() ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    final maxY = spots.map((s) => s.y).fold<double>(0, (a, b) => a > b ? a : b) + 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: timeSeries.length > 14 ? (timeSeries.length / 7) : 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= 0 && i < timeSeries.length) {
                    final d = timeSeries[i]['date'] as String? ?? '';
                    if (d.length >= 10) return Text(d.substring(5), style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textSecondary));
                  }
                  return const SizedBox();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (timeSeries.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingChart(List<Map<String, dynamic>> ratingSeries) {
    final spots = <FlSpot>[];
    for (var i = 0; i < ratingSeries.length; i++) {
      final v = (ratingSeries[i]['avg_rating'] as num?)?.toDouble();
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      height: 160,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.border, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) => Text(
                  v.toStringAsFixed(1),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: ratingSeries.length > 14 ? (ratingSeries.length / 7) : 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i >= 0 && i < ratingSeries.length) {
                    final d = ratingSeries[i]['date'] as String? ?? '';
                    if (d.length >= 10) return Text(d.substring(5), style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textSecondary));
                  }
                  return const SizedBox();
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (ratingSeries.length - 1).toDouble(),
          minY: 0,
          maxY: 5.5,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.warning,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.warning.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceList(List<Map<String, dynamic>> attendance) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        children: attendance.take(14).map((a) {
          final date = a['date'] as String? ?? '';
          final hours = a['duration_hours'];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  hours != null ? '${hours}h' : '—',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final String label, value;

  const _DetailMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
