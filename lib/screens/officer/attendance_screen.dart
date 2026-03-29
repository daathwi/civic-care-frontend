import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/app_theme.dart';
import '../../providers/attendance_provider.dart';

/// Worker's own attendance history with date filter.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(attendanceProvider.notifier).fetchStatus();
      ref.read(attendanceProvider.notifier).fetchHistory();
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final from = _fromDate ?? now.subtract(const Duration(days: 30));
    final to = _toDate ?? now;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (picked != null && mounted) {
      setState(() {
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      ref.read(attendanceProvider.notifier).fetchHistory(
            fromDate: picked.start,
            toDate: picked.end,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(attendanceProvider).history;
    final isEmbedded = !Navigator.canPop(context);

    final content = RefreshIndicator(
      onRefresh: () async {
        await ref.read(attendanceProvider.notifier).fetchHistory(
              fromDate: _fromDate,
              toDate: _toDate,
            );
      },
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date filter
            Material(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_rounded, color: AppTheme.primary, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _fromDate != null && _toDate != null
                                  ? '${DateFormat('MMM d').format(_fromDate!)} – ${DateFormat('MMM d, yyyy').format(_toDate!)}'
                                  : 'Last 30 days',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                            ),
                            Text(
                              'Tap to change date range',
                              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (history.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_rounded, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No attendance records',
                        style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...history.map<Widget>((e) => _AttendanceCard(record: e)),
          ],
        ),
      ),
    );

    if (isEmbedded) {
      return NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
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
                  'Attendance',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
        body: content,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceScaffold,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Attendance',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.textPrimary),
        ),
      ),
      body: content,
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final dynamic record;

  const _AttendanceCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateStr = record['date'] as String?;
    final clockIn = record['clock_in_time'] as String?;
    final clockOut = record['clock_out_time'] as String?;
    final duration = record['total_duration_seconds'] as int?;
    DateTime? date;
    if (dateStr != null) date = DateTime.tryParse(dateStr);
    final dayLabel = date != null ? DateFormat('EEEE, MMM d').format(date) : dateStr ?? '--';
    final inTime = clockIn != null ? DateFormat('h:mm a').format(DateTime.tryParse(clockIn) ?? DateTime.now()) : '--';
    final outTime = clockOut != null ? DateFormat('h:mm a').format(DateTime.tryParse(clockOut) ?? DateTime.now()) : '--';
    final hours = duration != null ? (duration / 3600).toStringAsFixed(1) : '--';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.schedule_rounded, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dayLabel, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('In $inTime · Out $outTime', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Text('$hours h', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
        ],
      ),
    );
  }
}
