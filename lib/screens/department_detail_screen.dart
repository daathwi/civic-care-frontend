import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_theme.dart';
import '../providers/analytics_provider.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Department detail: stacked daily status chart and month selector.
class DepartmentDetailScreen extends ConsumerStatefulWidget {
  final String departmentId;
  final String departmentName;

  const DepartmentDetailScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
  });

  @override
  ConsumerState<DepartmentDetailScreen> createState() =>
      _DepartmentDetailScreenState();
}

class _DepartmentDetailScreenState extends ConsumerState<DepartmentDetailScreen> {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final params = (id: widget.departmentId, month: _selectedMonth, year: _selectedYear);
    final async = ref.watch(departmentDetailProvider(params));

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
          widget.departmentName,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      body: async.when(
        data: (data) {
          if (data.isEmpty) {
            return Center(
              child: Text(
                'No data available',
                style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
              ),
            );
          }
          final timeSeries = data['time_series'] as List<dynamic>? ?? [];
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              ref.invalidate(departmentDetailProvider(params));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(title: 'Select month & year'),
                  const SizedBox(height: 8),
                  _MonthYearSelector(
                    month: _selectedMonth,
                    year: _selectedYear,
                    onMonthChanged: (m) => setState(() => _selectedMonth = m),
                    onYearChanged: (y) => setState(() => _selectedYear = y),
                  ),
                  const SizedBox(height: 24),
                  if (timeSeries.isNotEmpty) ...[
                    _SectionTitle(title: 'Daily complaints by status'),
                    const SizedBox(height: 8),
                    Text(
                      '$_selectedYear · ${_monthNames[_selectedMonth - 1]} · Resolved, pending & escalated',
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _StackedStatusBarChart(data: timeSeries),
                  ],
                ],
              ),
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
              Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
              const SizedBox(height: 16),
              Text(
                'Failed to load',
                style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(departmentDetailProvider(params)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthYearSelector extends StatelessWidget {
  final int month;
  final int year;
  final ValueChanged<int> onMonthChanged;
  final ValueChanged<int> onYearChanged;

  const _MonthYearSelector({
    required this.month,
    required this.year,
    required this.onMonthChanged,
    required this.onYearChanged,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    final years = List.generate(11, (i) => now - 5 + i);
    final yearList = years.contains(year) ? years : [year, ...years]..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: month,
              decoration: InputDecoration(
                labelText: 'Month',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: List.generate(12, (i) => i + 1).map((m) {
                return DropdownMenuItem(value: m, child: Text(_monthNames[m - 1]));
              }).toList(),
              onChanged: (v) => v != null ? onMonthChanged(v) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: year,
              decoration: InputDecoration(
                labelText: 'Year',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: yearList.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
              onChanged: (v) => v != null ? onYearChanged(v) : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

/// Stacked bars: resolved (green), pending (orange), escalated (red) per day.
class _StackedStatusBarChart extends StatelessWidget {
  final List<dynamic> data;

  const _StackedStatusBarChart({required this.data});

  static const _resolved = Color(0xFF2E7D32);
  static const _pending = Color(0xFFE65100);
  static const _escalated = Color(0xFFD13212);

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    double maxSum = 1;
    for (final e in data) {
      final d = e as Map<String, dynamic>;
      final r = (d['resolved'] as num?)?.toDouble() ?? 0;
      final p = (d['pending'] as num?)?.toDouble() ?? 0;
      final es = (d['escalated'] as num?)?.toDouble() ?? 0;
      final s = r + p + es;
      if (s > maxSum) maxSum = s;
    }
    final maxY = (maxSum * 1.15).clamp(2.0, double.infinity);

    const barWidth = 12.0;
    final chartWidth = (data.length * (barWidth + 6)).clamp(400.0, 1400.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              height: 240,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: AppTheme.textSecondary.withValues(alpha: 0.15), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, _) => Text(
                          v.toInt().toString(),
                          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: data.length > 15 ? 5 : 2,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i >= 0 && i < data.length) {
                            final d = data[i] as Map<String, dynamic>;
                            int day;
                            final dayVal = d['day'];
                            if (dayVal != null) {
                              day = (dayVal as num).toInt();
                            } else {
                              final dateStr = d['date'] as String? ?? '';
                              day = dateStr.length >= 10 ? int.tryParse(dateStr.substring(8, 10)) ?? i + 1 : i + 1;
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '$day',
                                style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.grey.shade900,
                      tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (groupIndex < 0 || groupIndex >= data.length) return null;
                        final d = data[groupIndex] as Map<String, dynamic>;
                        final r = (d['resolved'] as num?)?.toInt() ?? 0;
                        final p = (d['pending'] as num?)?.toInt() ?? 0;
                        final e = (d['escalated'] as num?)?.toInt() ?? 0;
                        return BarTooltipItem(
                          'R: $r  P: $p  E: $e',
                          GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: List.generate(data.length, (i) {
                    final d = data[i] as Map<String, dynamic>;
                    final r = (d['resolved'] as num?)?.toDouble() ?? 0;
                    final p = (d['pending'] as num?)?.toDouble() ?? 0;
                    final es = (d['escalated'] as num?)?.toDouble() ?? 0;
                    final sum = r + p + es;
                    final items = <BarChartRodStackItem>[
                      if (r > 0) BarChartRodStackItem(0, r, _resolved),
                      if (p > 0) BarChartRodStackItem(r, r + p, _pending),
                      if (es > 0) BarChartRodStackItem(r + p, sum, _escalated),
                    ];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: sum,
                          width: barWidth - 2,
                          borderRadius: sum > 0
                              ? const BorderRadius.vertical(top: Radius.circular(4))
                              : BorderRadius.zero,
                          rodStackItems: items,
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _LegendDot(color: _resolved, label: 'Resolved'),
              _LegendDot(color: _pending, label: 'Pending'),
              _LegendDot(color: _escalated, label: 'Escalated'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
