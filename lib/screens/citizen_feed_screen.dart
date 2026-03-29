import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/complaint.dart';
import '../providers/complaint_provider.dart';
import '../core/app_theme.dart';
import '../utils/responsive_utils.dart';
import 'ward_feed_screen.dart';
import 'complaint_detail/complaint_detail_screen.dart';

/// Citizen portal: Feed and Escalations tabs. Feed = ward feed; Escalations = API status=escalated.
/// iOS-style: icon-only horizontal segmented control below the app bar.
class CitizenFeedScreen extends ConsumerStatefulWidget {
  const CitizenFeedScreen({super.key});

  @override
  ConsumerState<CitizenFeedScreen> createState() => _CitizenFeedScreenState();
}

class _CitizenFeedScreenState extends ConsumerState<CitizenFeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
    if (_tabController.index == 1 && !_tabController.indexIsChanging) {
      ref.read(citizenEscalationsProvider.notifier).loadGrievances(
            limit: 100,
            status: ComplaintStatus.escalated,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = ResponsiveUtils.isDesktop(context);
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final wardName = ref.watch(userWardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        // Top safe area to avoid status bar / overflow
        SafeArea(
          top: true,
          bottom: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hamburger + Ward name row — bigger app bar area
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary, size: 26),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      padding: const EdgeInsets.all(14),
                      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 48),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            wardName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: CupertinoColors.label,
                              fontSize: 24,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // iOS-style segment bar: below ward name (height 50 to avoid Cupertino overflow)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _buildSegmentBar(context, isIOS),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            children: [
              const WardFeedScreen(hideAppBar: true),
              _CitizenEscalationsTab(isWeb: isWeb),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentBar(BuildContext context, bool isIOS) {
    final index = _tabController.index;
    const margin = 6.0;

    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final half = w / 2;
          final pillWidth = half - 2 * margin;

          return Stack(
            children: [
              // Sliding pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                left: margin + index * half,
                top: margin,
                bottom: margin,
                width: pillWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              // Labels on top
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (index != 0) {
                          HapticFeedback.lightImpact();
                          _tabController.animateTo(0);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Feed',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: index == 0
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (index != 1) {
                          HapticFeedback.lightImpact();
                          _tabController.animateTo(1);
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Text(
                          'Escalations',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: index == 1
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

}

class _CitizenEscalationsTab extends ConsumerStatefulWidget {
  final bool isWeb;

  const _CitizenEscalationsTab({required this.isWeb});

  @override
  ConsumerState<_CitizenEscalationsTab> createState() =>
      _CitizenEscalationsTabState();
}

class _CitizenEscalationsTabState extends ConsumerState<_CitizenEscalationsTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(citizenEscalationsProvider.notifier).loadGrievances(
            limit: 100,
            status: ComplaintStatus.escalated,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(citizenEscalationsProvider);
    final escalated = state.complaints;
    final sorted = [...escalated]..sort((a, b) => a.date.compareTo(b.date));

    if (state.isLoading && escalated.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (escalated.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 56,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No escalations',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'All ward grievances are within SLA.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => ref.read(citizenEscalationsProvider.notifier).loadGrievances(
            limit: 100,
            status: ComplaintStatus.escalated,
          ),
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          widget.isWeb ? 32 : 20,
          16,
          widget.isWeb ? 32 : 20,
          140,
        ),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) => _CitizenEscalationCard(
          complaint: sorted[index],
          isWeb: widget.isWeb,
        ),
      ),
    );
  }
}

class _CitizenEscalationCard extends StatelessWidget {
  final Complaint complaint;
  final bool isWeb;

  const _CitizenEscalationCard({
    required this.complaint,
    required this.isWeb,
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
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ComplaintDetailScreen(complaint: complaint),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
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
                          if (isWeb) ...[
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(complaint.date),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
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
                    _chip(
                      '${hours}h overdue',
                      severity,
                      Icons.schedule_rounded,
                    ),
                    _chip(
                      complaint.subCategory,
                      AppTheme.primary,
                      Icons.category_outlined,
                    ),
                    _chip(
                      complaint.status.label,
                      AppTheme.error,
                      Icons.warning_amber_rounded,
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

  Widget _chip(String label, Color color, IconData icon) {
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
