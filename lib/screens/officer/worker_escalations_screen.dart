import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/complaint.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import 'field_assistant_detail/field_assistant_task_detail.dart';

/// Worker portal: Escalated tasks assigned to me.
class WorkerEscalationsScreen extends ConsumerStatefulWidget {
  const WorkerEscalationsScreen({super.key});

  @override
  ConsumerState<WorkerEscalationsScreen> createState() =>
      _WorkerEscalationsScreenState();
}

class _WorkerEscalationsScreenState extends ConsumerState<WorkerEscalationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authProvider).user;
      if (user != null) {
        ref.read(workerEscalationsProvider.notifier).loadGrievances(
              workerId: user.id,
              status: ComplaintStatus.escalated,
              limit: 100,
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final grievanceState = ref.watch(workerEscalationsProvider);
    final escalated = grievanceState.complaints;

    final sorted = [...escalated]..sort((a, b) => a.date.compareTo(b.date));
    final isWeb = ResponsiveUtils.isDesktop(context);

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
                'Escalations',
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                              ? 'All clear — no escalated tasks assigned to you.'
                              : '${escalated.length} escalated tasks need your attention.',
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
          Expanded(
            child: grievanceState.isLoading && escalated.isEmpty
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
                              'All your tasks are within SLA.',
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
                        onRefresh: () async {
                          final user = ref.read(authProvider).user;
                          if (user != null) {
                            await ref.read(workerEscalationsProvider.notifier).loadGrievances(
                                  workerId: user.id,
                                  status: ComplaintStatus.escalated,
                                  limit: 100,
                                );
                          }
                        },
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
                          itemCount: sorted.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) => _EscalationCard(
                            complaint: sorted[index],
                            isWeb: isWeb,
                            onPop: () {
                              final user = ref.read(authProvider).user;
                              if (user != null) {
                                ref.read(workerEscalationsProvider.notifier).loadGrievances(
                                      workerId: user.id,
                                      status: ComplaintStatus.escalated,
                                      limit: 100,
                                    );
                              }
                            },
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _EscalationCard extends StatelessWidget {
  final Complaint complaint;
  final bool isWeb;
  final VoidCallback? onPop;

  const _EscalationCard({
    required this.complaint,
    required this.isWeb,
    this.onPop,
  });

  @override
  Widget build(BuildContext context) {
    final hours = DateTime.now().difference(complaint.date).inHours;
    final severity = hours > 120 ? AppTheme.error : AppTheme.warning;

    return Container(
      decoration: AppTheme.cardDecoration(
        boxShadow: [
          BoxShadow(
            color: severity.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FieldAssistantTaskDetail(complaint: complaint),
              ),
            ).then((_) => onPop?.call());
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: severity.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: severity,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            complaint.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${complaint.userName} · ${complaint.ward}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _EscalationChip(
                      icon: Icons.schedule_rounded,
                      label: '${hours}h overdue',
                      color: severity,
                    ),
                    _EscalationChip(
                      icon: Icons.category_outlined,
                      label: complaint.subCategory,
                      color: AppTheme.primary,
                    ),
                    _EscalationChip(
                      icon: Icons.assignment_ind_rounded,
                      label: complaint.status.label,
                      color: AppTheme.textSecondary,
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

class _EscalationChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _EscalationChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
