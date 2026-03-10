import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/complaint.dart';
import '../../providers/complaint_provider.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../complaint_detail/complaint_detail_screen.dart';

class ManagerEscalationsScreen extends ConsumerStatefulWidget {
  const ManagerEscalationsScreen({super.key});

  @override
  ConsumerState<ManagerEscalationsScreen> createState() =>
      _ManagerEscalationsScreenState();
}

class _ManagerEscalationsScreenState
    extends ConsumerState<ManagerEscalationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(complaintProvider.notifier).loadGrievances(limit: 100);
    });
  }

  @override
  Widget build(BuildContext context) {
    final grievanceState = ref.watch(complaintProvider);
    final all = grievanceState.complaints;

    // API already filters by ward_id and category_dept (IDs)
    final myComplaints = all;

    final escalated = myComplaints.where((c) {
      if (c.status == ComplaintStatus.completed) return false;
      return DateTime.now().difference(c.date).inHours > 48;
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    final isWeb = ResponsiveUtils.isDesktop(context);

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 120,
          collapsedHeight: 60,
          pinned: true,
          backgroundColor: AppTheme.surfaceScaffold,
          scrolledUnderElevation: 0,
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
              'Escalations',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                fontSize: 24,
              ),
            ),
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppTheme.surfaceScaffold,
            padding: EdgeInsets.fromLTRB(
              isWeb ? 32 : 20,
              isWeb ? 8 : 4,
              isWeb ? 32 : 20,
              12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    gradient: escalated.isEmpty
                        ? LinearGradient(
                            colors: [
                              AppTheme.success.withValues(alpha: 0.08),
                              AppTheme.success.withValues(alpha: 0.04),
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              AppTheme.error.withValues(alpha: 0.1),
                              AppTheme.error.withValues(alpha: 0.04),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: escalated.isEmpty
                          ? AppTheme.success.withValues(alpha: 0.2)
                          : AppTheme.error.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        escalated.isEmpty
                            ? Icons.check_circle_rounded
                            : Icons.error_rounded,
                        color: escalated.isEmpty
                            ? AppTheme.success
                            : AppTheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          escalated.isEmpty
                              ? 'All clear — no SLA breaches right now.'
                              : '${escalated.length} grievances need immediate attention.',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: escalated.isEmpty
                                ? AppTheme.success
                                : AppTheme.error,
                          ),
                        ),
                      ),
                      if (escalated.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.error,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${escalated.length}',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────────────────────
          Expanded(
            child: grievanceState.isLoading && all.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary),
                  )
                : escalated.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.verified_rounded,
                            size: 52,
                            color: AppTheme.success,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No escalations',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'All grievances are within SLA.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () =>
                        ref.read(complaintProvider.notifier).loadGrievances(),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        isWeb ? 32 : 20,
                        8,
                        isWeb ? 32 : 20,
                        140,
                      ),
                      itemCount: escalated.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _EscalationCard(
                        complaint: escalated[index],
                        isWeb: isWeb,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Escalation card ─────────────────────────────────────────────────────────
class _EscalationCard extends StatelessWidget {
  final Complaint complaint;
  final bool isWeb;
  const _EscalationCard({required this.complaint, required this.isWeb});

  @override
  Widget build(BuildContext context) {
    final hours = DateTime.now().difference(complaint.date).inHours;
    final statusColor = Color(complaint.status.colorValue);
    final severity = hours > 120 ? AppTheme.error : AppTheme.warning;

    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ComplaintDetailScreen(complaint: complaint),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(
              color: severity.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Severity bar
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [severity, severity.withValues(alpha: 0.4)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complaint.title,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${complaint.userName}  ·  ${complaint.subCategory}  ·  ${complaint.ward}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Overdue badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: severity.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: severity.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '${hours}h overdue',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: severity,
                      ),
                    ),
                  ),
                  if (isWeb) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        complaint.status.label,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
