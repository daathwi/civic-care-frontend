import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/analytics_provider.dart';
import '../../repository/analytics_repository.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';

class EscalationPriorityScreen extends ConsumerStatefulWidget {
  final String? wardId;
  final String? zoneId;

  const EscalationPriorityScreen({
    super.key,
    this.wardId,
    this.zoneId,
  });

  @override
  ConsumerState<EscalationPriorityScreen> createState() => _EscalationPriorityScreenState();
}

class _EscalationPriorityScreenState extends ConsumerState<EscalationPriorityScreen> {
  @override
  Widget build(BuildContext context) {
    final priorityAsync = ref.watch(escalationPriorityProvider((
      wardId: widget.wardId,
      zoneId: widget.zoneId,
    )));

    final isWeb = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            collapsedHeight: 64,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: AppTheme.glass(
              blur: 20,
              color: AppTheme.surfaceScaffold.withValues(alpha: 0.7),
              child: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 16),
                title: Text(
                  'Priority Analysis',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withValues(alpha: 0.1),
                        AppTheme.surfaceScaffold,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: priorityAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        size: 52,
                        color: AppTheme.success,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'No Escalations Found',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }

            final avgEps = items.map((e) => e.epsTotal).reduce((a, b) => a + b) / items.length;

            return Column(
              children: [
                // Summary bar
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWeb ? 32 : 20, vertical: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                                'AVERAGE PRIORITY SCORE',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${avgEps.toStringAsFixed(1)}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                '${items.length} ACTIVE',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      isWeb ? 32 : 20,
                      8,
                      isWeb ? 32 : 20,
                      100,
                    ),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _PriorityGrievanceCard(
                      item: items[index],
                      isWeb: isWeb,
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
          error: (err, stack) => Center(
            child: Text('Error loading priority data: $err'),
          ),
        ),
      ),
    );
  }
}

class _PriorityGrievanceCard extends StatelessWidget {
  final EscalationPriorityItem item;
  final bool isWeb;

  const _PriorityGrievanceCard({required this.item, required this.isWeb});

  Color _getLevelColor(String level) {
    switch (level.toLowerCase()) {
      case 'critical':
        return AppTheme.error;
      case 'high':
        return Colors.orange;
      case 'moderate':
        return Colors.amber;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(item.escalationLevel);

    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          onTap: () {
            // Find the full complaint object from the complaintProvider to navigate to detail
            // Note: In a real app we might fetch detail directly by ID if not in provider.
            // For now we'll just show the breakdown or provide a way to get the full object.
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${item.wardName} · ${item.ageHours.toInt()}h since creation',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: levelColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: levelColor.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        item.escalationLevel.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: levelColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // EPS Breakdown
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Priority Score',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${item.epsTotal.toInt()}%',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: levelColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Multi-segment progress bar
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppTheme.textSecondary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Row(
                                children: [
                                  // Age (30%)
                                  if (item.epsAge > 0)
                                    Flexible(
                                      flex: (item.epsAge * 100).toInt(),
                                      child: Container(color: Colors.blue),
                                    ),
                                  // Reopen (25%)
                                  if (item.epsReopen > 0)
                                    Flexible(
                                      flex: (item.epsReopen * 100).toInt(),
                                      child: Container(color: Colors.purple),
                                    ),
                                  // Votes (25%)
                                  if (item.epsVotes > 0)
                                    Flexible(
                                      flex: (item.epsVotes * 100).toInt(),
                                      child: Container(color: Colors.green),
                                    ),
                                  // Severity (20%)
                                  if (item.epsSeverity > 0)
                                    Flexible(
                                      flex: (item.epsSeverity * 100).toInt(),
                                      child: Container(color: Colors.orange),
                                    ),
                                  // Empty space
                                  Spacer(flex: ((100 - item.epsTotal) * 100).toInt()),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Legend
                Wrap(
                  spacing: 12,
                  children: [
                    _MiniLegend(label: 'Age', color: Colors.blue),
                    _MiniLegend(label: 'Reopen', color: Colors.purple),
                    _MiniLegend(label: 'Votes', color: Colors.green),
                    _MiniLegend(label: 'Severity', color: Colors.orange),
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

class _MiniLegend extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniLegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
