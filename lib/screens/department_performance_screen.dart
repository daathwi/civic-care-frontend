import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_theme.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../repository/analytics_repository.dart';
import 'department_detail_screen.dart';

/// Citizen portal: Insights with Ward and Department sub-tabs.
class DepartmentPerformanceScreen extends ConsumerStatefulWidget {
  const DepartmentPerformanceScreen({super.key});

  @override
  ConsumerState<DepartmentPerformanceScreen> createState() =>
      _DepartmentPerformanceScreenState();
}

class _DepartmentPerformanceScreenState extends ConsumerState<DepartmentPerformanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Same iOS-style pill segment as Feed / Escalations.
  Widget _buildSegmentBar(BuildContext context) {
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
                          'Ward',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: index == 0 ? AppTheme.primary : AppTheme.textSecondary,
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
                          'Department',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: index == 1 ? AppTheme.primary : AppTheme.textSecondary,
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

  Future<void> _refreshAll() async {
    ref.invalidate(wardAnalyticsProvider(null));
    ref.invalidate(overallDepartmentAnalyticsProvider);
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Widget build(BuildContext context) {
    final wardAsync = ref.watch(wardAnalyticsProvider(null));
    final deptAsync = ref.watch(overallDepartmentAnalyticsProvider);
    final userWardId = ref.watch(authProvider).user?.wardId;

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                      Expanded(
                        child: Text(
                          'Insights',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: _buildSegmentBar(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWardTab(wardAsync, userWardId),
                _buildDepartmentTab(deptAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardTab(
    AsyncValue<List<WardAnalyticsItem>> wardAsync,
    String? userWardId,
  ) {
    return wardAsync.when(
      data: (wards) => RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.only(bottom: 120),
          child: _CitizenWardInsightsSection(
            wards: wards,
            userWardId: userWardId,
          ),
        ),
      ),
      loading: () => const Center(
        child: SizedBox(
          height: 32,
          width: 32,
          child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
        ),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Couldn\'t load ward insights',
              style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(wardAnalyticsProvider(null)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentTab(AsyncValue<List<DepartmentAnalyticsItem>> deptAsync) {
    return deptAsync.when(
      data: (list) {
        if (list.isEmpty) {
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _refreshAll,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.5,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'No department data available',
                        style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: _refreshAll,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final d = list[index];
              return _DeptPerfCard(
                id: d.id,
                name: d.name,
                dpi: d.dpi,
                performance: d.performance,
                resolved: d.resolved,
                total: d.total,
                metrics: d.metrics,
              );
            },
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
              onPressed: () => ref.invalidate(overallDepartmentAnalyticsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Citizen Insights: my ward (with rank + DPI), top 5 leaderboard, search for any ward's rank.
class _CitizenWardInsightsSection extends StatefulWidget {
  final List<WardAnalyticsItem> wards;
  final String? userWardId;

  const _CitizenWardInsightsSection({
    required this.wards,
    required this.userWardId,
  });

  @override
  State<_CitizenWardInsightsSection> createState() => _CitizenWardInsightsSectionState();
}

class _CitizenWardInsightsSectionState extends State<_CitizenWardInsightsSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _rankOf(WardAnalyticsItem w) {
    final i = widget.wards.indexWhere((x) => x.id == w.id);
    return i >= 0 ? i + 1 : 0;
  }

  WardAnalyticsItem? _wardById(String? id) {
    if (id == null || id.isEmpty) return null;
    try {
      return widget.wards.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
    }
  }

  List<WardAnalyticsItem> _searchMatches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return widget.wards.where((w) {
      final name = w.name.toLowerCase();
      final numStr = w.number != null ? '${w.number}' : '';
      return name.contains(q) || numStr.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final wards = widget.wards;
    if (wards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(
          'No ward performance data yet.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
        ),
      );
    }

    final myWard = _wardById(widget.userWardId);
    final top5 = wards.take(5).toList();
    final searchQuery = _searchController.text;
    final matches = _searchMatches(searchQuery);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.userWardId == null || widget.userWardId!.isEmpty)
            _InfoBanner(
              text: 'Link a ward in your profile to see your ward\'s rank and DPI.',
            )
          else if (myWard == null)
            _InfoBanner(
              text: 'Your ward wasn\'t found in the current rankings. Try refreshing after your profile is updated.',
            )
          else
            _MyWardCard(ward: myWard, rank: _rankOf(myWard), totalWards: wards.length),
          const SizedBox(height: 24),
          ...top5.asMap().entries.map((e) {
            final rank = e.key + 1;
            final w = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LeaderboardRow(ward: w, rank: rank),
            );
          }),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by ward name or number…',
              hintStyle: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
              prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary.withValues(alpha: 0.8)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              isDense: true,
            ),
          ),
          if (searchQuery.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            if (matches.isEmpty)
              Text(
                'No ward matches "${searchQuery.trim()}".',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
              )
            else
              ...matches.map((w) {
                final r = _rankOf(w);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SearchResultCard(ward: w, rank: r, totalWards: wards.length),
                );
              }),
          ],
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: AppTheme.primary.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, height: 1.35, color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyWardCard extends StatelessWidget {
  final WardAnalyticsItem ward;
  final int rank;
  final int totalWards;

  const _MyWardCard({
    required this.ward,
    required this.rank,
    required this.totalWards,
  });

  Color get _perfColor {
    if (ward.performance == 'Excellent') return const Color(0xFF2E7D32);
    if (ward.performance == 'Good') return const Color(0xFF388E3C);
    if (ward.performance == 'Average') return const Color(0xFFF57C00);
    if (ward.performance == 'Poor') return const Color(0xFFE64A19);
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final wardLabel = ward.number != null ? '#${ward.number} ${ward.name}' : ward.name;
    final dpi = ward.dpi;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
                      wardLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (ward.zoneName != null && ward.zoneName!.isNotEmpty)
                      Text(
                        ward.zoneName!,
                        style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _perfColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ward.performance,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _perfColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DPI',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      dpi.toStringAsFixed(1),
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    Text(
                      'Dept. performance index (ward average)',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceScaffold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'City rank',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      rank > 0 ? '#$rank of $totalWards' : '—',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(label: 'WPI', value: ward.wpi.toStringAsFixed(1)),
              const SizedBox(width: 16),
              _MiniStat(label: 'Grievances', value: '${ward.total}'),
              const SizedBox(width: 16),
              _MiniStat(label: 'Resolved', value: '${ward.resolved}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final WardAnalyticsItem ward;
  final int rank;

  const _LeaderboardRow({required this.ward, required this.rank});

  Color get _perfColor {
    if (ward.performance == 'Excellent') return const Color(0xFF2E7D32);
    if (ward.performance == 'Good') return const Color(0xFF388E3C);
    if (ward.performance == 'Average') return const Color(0xFFF57C00);
    if (ward.performance == 'Poor') return const Color(0xFFE64A19);
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final wardLabel = ward.number != null ? '#${ward.number} ${ward.name}' : ward.name;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$rank',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: rank <= 3 ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wardLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (ward.zoneName != null && ward.zoneName!.isNotEmpty)
                  Text(
                    ward.zoneName!,
                    style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _perfColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ward.performance,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _perfColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'WPI',
                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
              ),
              Text(
                ward.wpi.toStringAsFixed(0),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final WardAnalyticsItem ward;
  final int rank;
  final int totalWards;

  const _SearchResultCard({
    required this.ward,
    required this.rank,
    required this.totalWards,
  });

  Color get _perfColor {
    if (ward.performance == 'Excellent') return const Color(0xFF2E7D32);
    if (ward.performance == 'Good') return const Color(0xFF388E3C);
    if (ward.performance == 'Average') return const Color(0xFFF57C00);
    if (ward.performance == 'Poor') return const Color(0xFFE64A19);
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final wardLabel = ward.number != null ? '#${ward.number} ${ward.name}' : ward.name;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wardLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Rank #$rank of $totalWards · DPI ${ward.dpi.toStringAsFixed(1)} · WPI ${ward.wpi.toStringAsFixed(1)}',
                  style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _perfColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ward.performance,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _perfColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeptPerfCard extends StatelessWidget {
  final String id;
  final String name;
  final double dpi;
  final String performance;
  final int resolved;
  final int total;
  final Map<String, dynamic> metrics;

  const _DeptPerfCard({
    required this.id,
    required this.name,
    required this.dpi,
    required this.performance,
    required this.resolved,
    required this.total,
    required this.metrics,
  });

  Color get _perfColor {
    if (performance == 'Excellent') return const Color(0xFF2E7D32);
    if (performance == 'Good') return const Color(0xFF388E3C);
    if (performance == 'Average') return const Color(0xFFF57C00);
    if (performance == 'Poor') return const Color(0xFFE64A19);
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final pending = (metrics['pending'] as num?)?.toInt() ?? 0;
    final escalated = (metrics['escalated'] as num?)?.toInt() ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DepartmentDetailScreen(
                departmentId: id,
                departmentName: name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _perfColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  performance,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _perfColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _MetricChip(
                label: 'DPI',
                value: '${dpi.toStringAsFixed(0)}%',
                color: AppTheme.primary,
              ),
              _MetricChip(
                label: 'Resolved',
                value: '$resolved',
                color: const Color(0xFF2E7D32),
              ),
              _MetricChip(
                label: 'Pending',
                value: '$pending',
                color: const Color(0xFFE65100),
              ),
              if (escalated > 0)
                _MetricChip(
                  label: 'Escalated',
                  value: '$escalated',
                  color: AppTheme.error,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$resolved of $total resolved',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
        ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
