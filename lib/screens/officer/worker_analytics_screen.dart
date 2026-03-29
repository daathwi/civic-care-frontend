import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/complaint.dart';
import '../../providers/auth_provider.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/attendance_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
class _C {
  static const teal = AppTheme.primary;
  static const tealLight = Color(0xFFE0F2F1);
  static const bg = Color(0xFFF5F6FA);
  static const card = Colors.white;
  static const textPri = Color(0xFF111827);
  static const textSec = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
  static const border = Color(0xFFE5E7EB);
  static const success = Color(0xFF10B981);
  static const successBg = Color(0xFFECFDF5);
  static const warning = Color(0xFFF59E0B);
  static const warningBg = Color(0xFFFFFBEB);
  static const info = Color(0xFF3B82F6);
  static const infoBg = Color(0xFFEFF6FF);
  static const r = 16.0;

  static BoxDecoration cardDeco() => BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(r),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// ────────────────────────────────────────────────────────────────────────────
// Screen
// ────────────────────────────────────────────────────────────────────────────

class WorkerAnalyticsScreen extends ConsumerWidget {
  const WorkerAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user!;
    final all = ref.watch(complaintListProvider);
    final att = ref.watch(attendanceProvider);

    final mine = all.where((c) => c.assignedToId == user.id).toList();
    final counts = statusCounts(mine);
    final resolved = mine
        .where((c) => c.status == ComplaintStatus.completed)
        .toList();
    final active = counts.inProgress;
    final assigned = counts.assigned;

    // Mock weekly data: each entry = tasks completed on that day
    final weekData = [2.0, 4.0, 3.0, 6.0, 5.0, resolved.length.toDouble(), 1.0];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Attendance today (capped from live state for demo)
    final todayHours = att.isClockedIn
        ? att.dutyDurationHoursExact
        : 7.5; // placeholder when not clocked in

    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(
          isWide ? 32 : 20,
        ).copyWith(top: isWide ? 28 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────────────────────
            Text(
              'My Performance',
              style: GoogleFonts.outfit(
                fontSize: isWide ? 26 : 22,
                fontWeight: FontWeight.bold,
                color: _C.textPri,
              ),
            ),
            Text(
              'Weekly summary for ${user.name}',
              style: GoogleFonts.inter(fontSize: 13, color: _C.textSec),
            ),
            const SizedBox(height: 24),

            // ── KPI Grid ───────────────────────────────────────────────────
            GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: isWide ? 2.2 : 1.4,
              children: [
                _KpiCard(
                  label: 'Resolved',
                  value: '${resolved.length}',
                  sub: 'Total tasks done',
                  icon: Icons.check_circle_outline,
                  color: _C.success,
                  bg: _C.successBg,
                ),
                _KpiCard(
                  label: 'Active',
                  value: '$active',
                  sub: 'In progress now',
                  icon: Icons.engineering_outlined,
                  color: _C.warning,
                  bg: _C.warningBg,
                ),
                _KpiCard(
                  label: 'Pending',
                  value: '$assigned',
                  sub: 'Awaiting start',
                  icon: Icons.pending_actions_outlined,
                  color: _C.info,
                  bg: _C.infoBg,
                ),
                _KpiCard(
                  label: 'Hours Today',
                  value: todayHours.toStringAsFixed(1),
                  sub: 'Hours on duty',
                  icon: Icons.timer_outlined,
                  color: _C.teal,
                  bg: _C.tealLight,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Chart ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: _C.cardDeco(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'WEEKLY COMPLETION TREND',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: _C.textMuted,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _C.tealLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'This Week',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 220,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 2,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(color: _C.border, strokeWidth: 1),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) => Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  days[v.toInt() % 7],
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _C.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: weekData
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            isCurved: true,
                            curveSmoothness: 0.35,
                            color: _C.teal,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, data, index, painter) =>
                                  FlDotCirclePainter(
                                    radius: 4,
                                    color: Colors.white,
                                    strokeWidth: 2,
                                    strokeColor: _C.teal,
                                  ),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _C.teal.withValues(alpha: 0.2),
                                  _C.teal.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Achievements ────────────────────────────────────────────────
            Text(
              'ACHIEVEMENTS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: _C.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            _AchievementTile(
              icon: Icons.speed_rounded,
              title: 'Speed Resolver',
              sub: 'Resolved 5+ tasks within 4 hours each',
              color: _C.warning,
              bg: _C.warningBg,
              unlocked: resolved.length >= 2,
            ),
            const SizedBox(height: 10),
            _AchievementTile(
              icon: Icons.military_tech_rounded,
              title: 'Streak Champion',
              sub: 'Clocked in 5 consecutive days',
              color: _C.success,
              bg: _C.successBg,
              unlocked: true,
            ),
            const SizedBox(height: 10),
            _AchievementTile(
              icon: Icons.star_rounded,
              title: 'Top Performer',
              sub: 'Resolved 10 or more tasks',
              color: _C.info,
              bg: _C.infoBg,
              unlocked: resolved.length >= 10,
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Reusable Widgets
// ────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color, bg;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _C.cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _C.textSec,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _C.textPri,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: GoogleFonts.inter(fontSize: 10, color: _C.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Color color, bg;
  final bool unlocked;

  const _AchievementTile({
    required this.icon,
    required this.title,
    required this.sub,
    required this.color,
    required this.bg,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: unlocked ? 1.0 : 0.45,
      duration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _C.cardDeco(),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: unlocked ? bg : _C.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: unlocked ? color : _C.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: _C.textPri,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.inter(fontSize: 12, color: _C.textSec),
                  ),
                ],
              ),
            ),
            Icon(
              unlocked ? Icons.check_circle : Icons.lock_outline_rounded,
              color: unlocked ? color : _C.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
