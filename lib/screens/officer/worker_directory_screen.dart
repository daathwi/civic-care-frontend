import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/field_worker.dart';
import '../../providers/field_worker_provider.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import 'package:latlong2/latlong.dart';
import '../map_screen.dart';
import 'worker_detail_screen.dart';

class WorkerDirectoryScreen extends ConsumerStatefulWidget {
  const WorkerDirectoryScreen({super.key});

  @override
  ConsumerState<WorkerDirectoryScreen> createState() =>
      _WorkerDirectoryScreenState();
}

class _WorkerDirectoryScreenState extends ConsumerState<WorkerDirectoryScreen> {
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fieldWorkerProvider.notifier).loadWorkers();
    });
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

    final isWeb = ResponsiveUtils.isDesktop(context);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.surfaceScaffold,
        body: RefreshIndicator(
          onRefresh: () async {
            await ref.read(fieldWorkerProvider.notifier).loadWorkers();
          },
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
          slivers: [
            // ── Premium Glassmorphic Header ──────────────────
            SliverAppBar(
              expandedHeight: 120,
              collapsedHeight: 64,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  color: AppTheme.textPrimary,
                ),
                onPressed: () => Scaffold.of(context).openDrawer(),
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

            // ── Search & Stats Section ─────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isWeb ? 32 : 20,
                  16,
                  isWeb ? 32 : 20,
                  12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Row (Bento style)
                    Row(
                      children: [
                        Expanded(
                          child: _BentoStatCard(
                            count: onDuty.length,
                            label: 'ON DUTY',
                            color: AppTheme.success,
                            icon: Icons.flash_on_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BentoStatCard(
                            count: offDuty.length,
                            label: 'OFF DUTY',
                            color: AppTheme.textSecondary,
                            icon: Icons.power_settings_new_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Search Bar
                    Container(
                      decoration: AppTheme.cardDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        style: GoogleFonts.inter(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search field assistants...',
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
                    const SizedBox(height: 24),

                    // Tabs
                    TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.primary,
                      indicatorSize: TabBarIndicatorSize.label,
                      dividerColor: Colors.transparent,
                      labelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'Active'),
                        Tab(text: 'Inactive'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Tab Views ────────────────────────────────
            SliverFillRemaining(
              child: TabBarView(
                children: [
                  _WorkerList(workers: onDuty, isWeb: isWeb),
                  _WorkerList(workers: offDuty, isWeb: isWeb),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  }
}

class _BentoStatCard extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  const _BentoStatCard({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.3), size: 24),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_rounded, size: 48, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text(
              'No workers found',
              style: GoogleFonts.outfit(color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (isWeb) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(32, 12, 32, 140),
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
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
    final statusColor = isOnDuty ? AppTheme.success : AppTheme.textSecondary;

    return Container(
      decoration: AppTheme.cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerDetailScreen(worker: worker),
            ),
          ),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar with Status
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.surfaceScaffold,
                      child: Text(
                        worker.name.isNotEmpty ? worker.name[0] : '?',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Name & Info
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
                      ),
                      Text(
                        worker.designation,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            worker.lastActiveWard,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: Colors.amber[600],
                          ),
                          const SizedBox(width: 2),
                          Text(
                            worker.rating.toString(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Stats & Map Action
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isOnDuty &&
                        worker.lastActiveLat != null &&
                        worker.lastActiveLng != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: IconButton(
                          onPressed: () {
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
                            size: 20,
                          ),
                          tooltip: 'Show on Map',
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primaryLight,
                            padding: const EdgeInsets.all(8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    Text(
                      '${worker.tasksCompleted}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'TASKS',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
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
