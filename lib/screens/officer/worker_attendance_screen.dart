import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/app_theme.dart';
import '../../models/field_worker.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/auth_provider.dart';

/// Manager view of a worker's attendance with date filter.
class WorkerAttendanceScreen extends ConsumerStatefulWidget {
  final FieldWorker worker;

  const WorkerAttendanceScreen({super.key, required this.worker});

  @override
  ConsumerState<WorkerAttendanceScreen> createState() => _WorkerAttendanceScreenState();
}

class _WorkerAttendanceScreenState extends ConsumerState<WorkerAttendanceScreen> {
  List<dynamic> _records = [];
  bool _loading = true;
  String? _error;
  DateTime? _fromDate;
  DateTime? _toDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final token = ref.read(authProvider).accessToken;
    if (token == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final data = await ref.read(attendanceRepositoryProvider).workerHistory(
            token,
            widget.worker.id,
            fromDate: _fromDate,
            toDate: _toDate,
          );
      if (mounted) setState(() {
        _records = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
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
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          '${widget.worker.name} — Attendance',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.textPrimary),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppTheme.primary)))
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                        const SizedBox(height: 16),
                        Text(_error!, style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                )
              else if (_records.isEmpty)
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
                ..._records.map<Widget>((e) => _AttendanceCard(record: e)),
            ],
          ),
        ),
      ),
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
