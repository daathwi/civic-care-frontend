import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/complaint.dart';
import '../../providers/complaint_provider.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../complaint_detail/complaint_detail_screen.dart';
import '../map_screen.dart';

class ManagerGrievancesScreen extends ConsumerStatefulWidget {
  const ManagerGrievancesScreen({super.key});

  @override
  ConsumerState<ManagerGrievancesScreen> createState() =>
      _ManagerGrievancesScreenState();
}

class _ManagerGrievancesScreenState
    extends ConsumerState<ManagerGrievancesScreen> {
  String _searchQuery = '';
  ComplaintStatus? _statusFilter = ComplaintStatus.incompleteUnassigned;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(managerGrievancesProvider.notifier).loadGrievances(
        limit: 10,
        status: ComplaintStatus.incompleteUnassigned,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final grievanceState = ref.watch(managerGrievancesProvider);
    final allComplaints = grievanceState.complaints;

    var filtered = List<Complaint>.from(allComplaints);

    // Removed client-side status filtering as it's now server-side for pagination-friendliness.
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.description.toLowerCase().contains(q) ||
                c.userName.toLowerCase().contains(q),
          )
          .toList();
    }
    filtered.sort((a, b) => b.date.compareTo(a.date));

    final isWeb = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await ref.read(managerGrievancesProvider.notifier).loadGrievances(
                limit: 10,
                status: _statusFilter,
              );
        },
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
                    'Grievances',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            ),
  
            // ── Search & Filter Panel ─────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  isWeb ? 32 : 20,
                  16,
                  isWeb ? 32 : 20,
                  24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: AppTheme.cardDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: GoogleFonts.inter(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search grievances...',
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
                    Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'All',
                            selected: _statusFilter == null,
                            onTap: () {
                              setState(() => _statusFilter = null);
                              ref
                                  .read(managerGrievancesProvider.notifier)
                                  .loadGrievances(limit: 10, status: null);
                            },
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'Pending',
                            selected:
                                _statusFilter ==
                                ComplaintStatus.incompleteUnassigned,
                            onTap: () {
                              setState(
                                () => _statusFilter =
                                    ComplaintStatus.incompleteUnassigned,
                              );
                              ref
                                  .read(managerGrievancesProvider.notifier)
                                  .loadGrievances(
                                    limit: 10,
                                    status: ComplaintStatus.incompleteUnassigned,
                                  );
                            },
                            accent: AppTheme.primary,
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'In Progress',
                            selected: _statusFilter == ComplaintStatus.ongoing,
                            onTap: () {
                              setState(
                                () => _statusFilter = ComplaintStatus.ongoing,
                              );
                              ref
                                  .read(managerGrievancesProvider.notifier)
                                  .loadGrievances(
                                    limit: 10,
                                    status: ComplaintStatus.ongoing,
                                  );
                            },
                            accent: AppTheme.primary,
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'Assigned',
                            selected:
                                _statusFilter ==
                                ComplaintStatus.incompleteAssigned,
                            onTap: () {
                              setState(
                                () => _statusFilter =
                                    ComplaintStatus.incompleteAssigned,
                              );
                              ref
                                  .read(managerGrievancesProvider.notifier)
                                  .loadGrievances(
                                    limit: 10,
                                    status: ComplaintStatus.incompleteAssigned,
                                  );
                            },
                            accent: AppTheme.primary,
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'Resolved',
                            selected: _statusFilter == ComplaintStatus.completed,
                            onTap: () {
                              setState(
                                () => _statusFilter = ComplaintStatus.completed,
                              );
                              ref
                                  .read(managerGrievancesProvider.notifier)
                                  .loadGrievances(
                                    limit: 10,
                                    status: ComplaintStatus.completed,
                                  );
                            },
                            accent: AppTheme.primary,
                          ),
                          const SizedBox(width: 10),
                          _FilterChip(
                            label: 'Escalated',
                            selected:
                                _statusFilter == ComplaintStatus.escalated,
                            onTap: () {
                              setState(
                                () => _statusFilter =
                                    ComplaintStatus.escalated,
                              );
                              ref
                                  .read(managerGrievancesProvider.notifier)
                                  .loadGrievances(
                                    limit: 10,
                                    status: ComplaintStatus.escalated,
                                  );
                            },
                            accent: AppTheme.error,
                          ),
                        ],
                      ),
                    ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MapScreen(
                                    grievanceSourceProvider:
                                        managerGrievancesProvider,
                                    searchQuery: _searchQuery.isEmpty
                                        ? null
                                        : _searchQuery,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.map_rounded,
                                    size: 20,
                                    color: AppTheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Map',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
  
            // ── Grievance List ─────────────────────────
            if (grievanceState.isLoading && allComplaints.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isWeb ? 32 : 20,
                  0,
                  isWeb ? 32 : 20,
                  140,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      if (i == filtered.length) {
                        return _buildLoadMoreButton(
                          isLoadingMore: grievanceState.isLoadingMore,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _GrievanceCard(complaint: filtered[i]),
                      );
                    },
                    childCount: filtered.length + (grievanceState.hasMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton({required bool isLoadingMore}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: ElevatedButton(
        onPressed: isLoadingMore
            ? null
            : () => ref
                .read(managerGrievancesProvider.notifier)
                .loadMoreGrievances(),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          foregroundColor: AppTheme.primary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              )
            : Text(
                'View More Grievances',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(
            'No grievances found',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
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

class _GrievanceCard extends StatelessWidget {
  final Complaint complaint;
  const _GrievanceCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final statusColor = Color(complaint.status.colorValue);
    final priorityColor = _priorityColor(complaint.priority);

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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ComplaintDetailScreen(complaint: complaint),
            ),
          ),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    complaint.category.icon,
                    color: statusColor,
                    size: 22,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${complaint.userName} · ${DateFormat('MMM dd').format(complaint.date)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      // Removed AI RECOMMENDED badge as assignments are automatic now
                    ],
                  ),
                ),

                // Status Pill
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        complaint.priority.name.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: priorityColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      complaint.status.label,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
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

  Color _priorityColor(ComplaintPriority p) {
    return AppTheme.primary;
  }
}
