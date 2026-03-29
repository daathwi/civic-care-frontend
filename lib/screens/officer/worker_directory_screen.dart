import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../../models/field_worker.dart';
import '../../providers/field_worker_provider.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../map_screen.dart';
import 'worker_detail_screen.dart';

class WorkerDirectoryScreen extends ConsumerStatefulWidget {
  const WorkerDirectoryScreen({super.key});

  @override
  ConsumerState<WorkerDirectoryScreen> createState() =>
      _WorkerDirectoryScreenState();
}

class _WorkerDirectoryScreenState extends ConsumerState<WorkerDirectoryScreen>
    with SingleTickerProviderStateMixin {
  String _search = '';
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fieldWorkerProvider.notifier).loadWorkers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(fieldWorkerProvider);

    var workers = List<FieldWorker>.from(all)
      ..sort((a, b) => a.name.compareTo(b.name));

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      workers = workers
          .where(
            (w) =>
                w.name.toLowerCase().contains(q) ||
                w.designation.toLowerCase().contains(q),
          )
          .toList();
    }

    final onDuty = workers
        .where((w) => w.status == FieldWorkerStatus.onDuty)
        .toList();
    final offDuty = workers
        .where((w) => w.status == FieldWorkerStatus.offDuty)
        .toList();
    final ranked = [...workers]
      ..sort((a, b) {
        final ar = a.ratingsCount > 0 ? a.rating : 0.0;
        final br = b.ratingsCount > 0 ? b.rating : 0.0;
        final cmp = br.compareTo(ar);
        if (cmp != 0) return cmp;
        return b.ratingsCount.compareTo(a.ratingsCount);
      });

    final isWeb = ResponsiveUtils.isDesktop(context);
    final horizontalPadding = isWeb ? 32.0 : 20.0;

    // Builder gives us parent context before our Scaffold — parent AdaptiveScaffold has the drawer
    return Builder(
      builder: (parentContext) {
        return Scaffold(
          backgroundColor: AppTheme.surfaceScaffold,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // ── Premium Glassmorphic Header (matches Grievances) ──
              SliverAppBar(
                expandedHeight: 120,
                collapsedHeight: 64,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
                  onPressed: () => Scaffold.of(parentContext).openDrawer(),
                ),
            flexibleSpace: AppTheme.glass(
              blur: 20,
              color: AppTheme.surfaceScaffold.withValues(alpha: 0.7),
              child: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
                title: Text(
                  'Workforce',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ),
          // ── Search & Filter (single source of counts) ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Single KPI: total workers (theme primary)
                  Text(
                    '${workers.length} workers',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: AppTheme.cardDecoration(
                      borderRadius: AppTheme.inputRadius,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: GoogleFonts.inter(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: 'Search by name or role...',
                        hintStyle: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Filter chips (only place with active/inactive counts)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _WorkforceChip(
                          label: 'Active',
                          count: onDuty.length,
                          selected: _tabController.index == 0,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (_tabController.index != 0) _tabController.animateTo(0);
                          },
                          accent: AppTheme.primary,
                        ),
                        const SizedBox(width: 10),
                        _WorkforceChip(
                          label: 'Inactive',
                          count: offDuty.length,
                          selected: _tabController.index == 1,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (_tabController.index != 1) _tabController.animateTo(1);
                          },
                          accent: AppTheme.primary,
                        ),
                        const SizedBox(width: 10),
                        _WorkforceChip(
                          label: 'Rankings',
                          count: ranked.length,
                          selected: _tabController.index == 2,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (_tabController.index != 2) _tabController.animateTo(2);
                          },
                          accent: AppTheme.primary,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(fieldWorkerProvider.notifier).loadWorkers();
          },
          color: AppTheme.primary,
          child: TabBarView(
            controller: _tabController,
            children: [
              _WorkerList(workers: onDuty, isWeb: isWeb),
              _WorkerList(workers: offDuty, isWeb: isWeb),
              _RankingsList(workers: ranked, isWeb: isWeb),
            ],
          ),
        ),
      ),
    );
      },
    );
  }

}

/// Filter chip matching grievance screen style; uses AppTheme.primary.
class _WorkforceChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  const _WorkforceChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : AppTheme.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Rankings tab: workers sorted by rating with card design based on rating tier.
class _RankingsList extends StatelessWidget {
  final List<FieldWorker> workers;
  final bool isWeb;
  const _RankingsList({required this.workers, required this.isWeb});

  @override
  Widget build(BuildContext context) {
    if (workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events_outlined, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 20),
              Text(
                'No workers to rank',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Workers will appear here when assigned',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (isWeb) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: workers.asMap().entries.map((e) {
            return SizedBox(
              width: 320,
              child: _RankingWorkerCard(worker: e.value, rank: e.key + 1),
            );
          }).toList(),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: workers.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _RankingWorkerCard(worker: workers[i], rank: i + 1),
      ),
    );
  }
}

/// Ranking card — neutral design, no tier coloring.
class _RankingWorkerCard extends StatelessWidget {
  final FieldWorker worker;
  final int rank;
  const _RankingWorkerCard({required this.worker, required this.rank});

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        worker.lastActiveLat != null && worker.lastActiveLng != null;

    return Container(
      decoration: AppTheme.cardDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkerDetailScreen(worker: worker),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$rank',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: AppTheme.textSecondary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        worker.designation,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            worker.ratingsCount > 0
                                ? '${worker.rating.toStringAsFixed(1)} (${worker.ratingsCount} ratings)'
                                : 'No ratings yet',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasLocation)
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapScreen(
                            initialCenter: LatLng(
                              worker.lastActiveLat!,
                              worker.lastActiveLng!,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.map_rounded, color: AppTheme.primary, size: 20),
                    tooltip: 'Show on Map',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkerList extends StatelessWidget {
  final List<FieldWorker> workers;
  final bool isWeb;
  const _WorkerList({required this.workers, required this.isWeb});

  @override
  Widget build(BuildContext context) {
    if (workers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.textSecondary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.people_outline_rounded,
                  size: 48,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No workers found',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Workers will appear here when assigned',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (isWeb) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 32),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: workers
              .map((w) => SizedBox(width: 320, child: _WorkerCard(worker: w)))
              .toList(),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      itemCount: workers.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _WorkerCard(worker: workers[i]),
      ),
    );
  }
}

class _WorkerCard extends StatelessWidget {
  final FieldWorker worker;
  const _WorkerCard({required this.worker});

  @override
  Widget build(BuildContext context) {
    final isOnDuty = worker.status == FieldWorkerStatus.onDuty;
    final accent = isOnDuty ? AppTheme.primary : AppTheme.textSecondary;
    final hasLocation =
        worker.lastActiveLat != null && worker.lastActiveLng != null;

    return Container(
      decoration: AppTheme.cardDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WorkerDetailScreen(worker: worker),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isOnDuty
                        ? Icons.person_pin_circle_rounded
                        : Icons.person_off_rounded,
                    color: accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _buildMetaString(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        isOnDuty ? 'Active' : 'Inactive',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    if (isOnDuty && hasLocation) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapScreen(
                                initialCenter: LatLng(
                                  worker.lastActiveLat!,
                                  worker.lastActiveLng!,
                                ),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.map_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        tooltip: 'Show on Map',
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryLight,
                          padding: const EdgeInsets.all(6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _buildMetaString() {
    final parts = <String>[worker.designation];
    if (worker.lastActiveWard.isNotEmpty) {
      parts.add(worker.lastActiveWard);
    }
    if (worker.ratingsCount > 0) {
      parts.add('★ ${worker.rating.toStringAsFixed(1)} (${worker.ratingsCount})');
    } else {
      parts.add('★ —');
    }
    return parts.join(' · ');
  }
}
