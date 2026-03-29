import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/complaint.dart';
import '../providers/complaint_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/auth_provider.dart';
import '../core/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../widgets/civic_ui.dart';

import 'complaint_detail/complaint_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  ComplaintStatus? _statusFilter;
  bool _isNewestFirst = true;
  Complaint? _selectedComplaint;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = ref.read(effectiveUserProvider)?.id;
      if (userId != null) {
        ref
            .read(userHistoryProvider.notifier)
            .loadGrievances(reporterId: userId);
      }
    });
  }

  Future<void> _onRefresh() async {
    final userId = ref.read(effectiveUserProvider)?.id;
    if (userId == null) return;
    setState(() => _isRefreshing = true);
    await ref
        .read(userHistoryProvider.notifier)
        .loadGrievances(reporterId: userId);
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final gState = ref.watch(userHistoryProvider);
    final complaints = gState.complaints;

    List<Complaint> filtered = complaints
        .where((c) => _statusFilter == null || c.status == _statusFilter)
        .toList();

    filtered.sort(
      (a, b) =>
          _isNewestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date),
    );

    final hasMore = gState.hasMore;
    final isLoadingMore = gState.isLoadingMore;
    final isOffline = ref.watch(connectivityProvider).valueOrNull == false;
    final showSkeleton = gState.isLoading && complaints.isEmpty;

    return Column(
      children: [
        if (isOffline) const OfflineBanner(),
        Expanded(
          child: showSkeleton
              ? const SingleChildScrollView(child: GrievanceListSkeleton())
              : ResponsiveLayout(
                  mobile: _buildMobileLayout(
                    filtered,
                    hasMore: hasMore,
                    isLoadingMore: isLoadingMore,
                    allComplaints: complaints,
                  ),
                  desktop: _buildWebLayout(
                    filtered,
                    hasMore: hasMore,
                    isLoadingMore: isLoadingMore,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(
    List<Complaint> filtered, {
    required bool hasMore,
    required bool isLoadingMore,
    required List<Complaint> allComplaints,
  }) {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          expandedHeight: 120,
          collapsedHeight: 60,
          pinned: true,
          backgroundColor: AppTheme.surfaceScaffold.withValues(alpha: 0.8),
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black87),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
            title: Text(
              'My History',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 24,
                color: Colors.black,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                _isNewestFirst ? Icons.sort_rounded : Icons.low_priority,
                color: Colors.black87,
              ),
              onPressed: () => setState(() => _isNewestFirst = !_isNewestFirst),
              tooltip: 'Toggle Sort Order',
            ),

            const SizedBox(width: 8),
          ],
        ),
        SliverToBoxAdapter(child: _buildStatusSummary(allComplaints)),
        SliverPersistentHeader(
          pinned: true,
          delegate: _SliverHeaderDelegate(
            child: Container(
              color: AppTheme.surfaceScaffold.withValues(alpha: 0.9),
              alignment: Alignment.bottomCenter,
              child: _buildFilterBar(),
            ),
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.primary,
        displacement: 20,
        child: filtered.isEmpty && !hasMore
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.5,
                  child: _buildEmptyState(),
                ),
              )
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  if (_isRefreshing)
                    const SliverToBoxAdapter(child: LinearProgressIndicator()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        if (index == filtered.length) {
                          return _buildLoadMoreButton(
                            isLoadingMore: isLoadingMore,
                          );
                        }
                        return _TicketRecordCard(complaint: filtered[index]);
                      }, childCount: filtered.length + (hasMore ? 1 : 0)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusSummary(List<Complaint> all) {
    final total = all.length;
    final resolved = all
        .where((c) => c.status == ComplaintStatus.completed)
        .length;
    final inProgress = all
        .where((c) => c.status == ComplaintStatus.ongoing)
        .length;
    final pending = total - resolved - inProgress;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _bentoCard(
                  title: 'Total Requests',
                  value: total.toString(),
                  icon: Icons.assignment_rounded,
                  color: AppTheme.primary,
                  isLarge: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _bentoCard(
                      title: 'Resolved',
                      value: resolved.toString(),
                      icon: Icons.check_circle_rounded,
                      color: const Color(0xFF10B981),
                    ),
                    const SizedBox(height: 12),
                    _bentoCard(
                      title: 'Pending',
                      value: pending.toString(),
                      icon: Icons.hourglass_empty_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bentoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    bool isLarge = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isLarge ? 20 : 12,
      ),
      height: isLarge ? 145 : 68,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLarge
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoadMoreButton({required bool isLoadingMore}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isLoadingMore
                ? null
                : () => ref
                      .read(userHistoryProvider.notifier)
                      .loadMoreGrievances(),
            icon: isLoadingMore
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline, size: 20),
            label: Text(isLoadingMore ? 'Loading...' : 'Load more'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
    );
  }

  // ── Web: Master-Detail split (same as Ward Feed) ──────────────────────

  Widget _buildWebLayout(
    List<Complaint> filtered, {
    required bool hasMore,
    required bool isLoadingMore,
  }) {
    final selected =
        _selectedComplaint != null &&
            filtered.any((c) => c.id == _selectedComplaint!.id)
        ? filtered.firstWhere((c) => c.id == _selectedComplaint!.id)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master — ticket list (left)
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              right: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 32, 32, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY COMPLAINTS',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey[400],
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${filtered.length} records found',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Filter chips (Web refined)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _filterChip(null, 'All'),
                    _filterChip(
                      ComplaintStatus.incompleteUnassigned,
                      'Pending',
                    ),
                    _filterChip(ComplaintStatus.incompleteAssigned, 'Assigned'),
                    _filterChip(ComplaintStatus.ongoing, 'In Progress'),
                    _filterChip(ComplaintStatus.completed, 'Resolved'),
                    _filterChip(ComplaintStatus.escalated, 'Escalated'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filtered.isEmpty && !hasMore
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length + (hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filtered.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: _buildLoadMoreButton(
                                isLoadingMore: isLoadingMore,
                              ),
                            );
                          }
                          final c = filtered[index];
                          final isSelected = selected?.id == c.id;
                          return _buildCompactCard(c, isSelected);
                        },
                      ),
              ),
            ],
          ),
        ),

        // Detail — right panel
        Expanded(
          child: Container(
            color: AppTheme.surfaceScaffold,
            child: selected != null
                ? ComplaintDetailScreen(complaint: selected, isEmbedded: true)
                : _buildSelectPlaceholder(),
          ),
        ),
      ],
    );
  }

  // ── Compact card for master list ──────────────────────────────────────

  Widget _buildCompactCard(Complaint c, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => setState(() => _selectedComplaint = c),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statusPill(c.status),
                    const Spacer(),
                    Text(
                      DateFormat('MMM dd').format(c.date),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  c.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniChip(
                      c.departmentDisplayName ?? c.category.label,
                      AppTheme.primary,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Colors.grey[300],
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

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSelectPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.touch_app_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'Select a complaint to view details',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared components ────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceScaffold.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
                    _filterChip(null, 'All Tickets'),
          _filterChip(ComplaintStatus.incompleteUnassigned, 'Pending'),
          _filterChip(ComplaintStatus.incompleteAssigned, 'Assigned'),
          _filterChip(ComplaintStatus.ongoing, 'In Progress'),
          _filterChip(ComplaintStatus.completed, 'Resolved'),
          _filterChip(ComplaintStatus.escalated, 'Escalated'),
        ],
      ),
    );
  }

  Widget _filterChip(ComplaintStatus? status, String label) {
    final isSelected = _statusFilter == status;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => setState(() => _statusFilter = status),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : Colors.black.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.filter_list_off, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No matching records',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 16),
          if (_statusFilter != null)
            TextButton(
              onPressed: () => setState(() => _statusFilter = null),
              child: const Text('Clear Filters'),
            ),
          ElevatedButton.icon(
            onPressed: _onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh History'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SliverHeaderDelegate({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  double get maxExtent => 80;
  @override
  double get minExtent => 80;
  @override
  bool shouldRebuild(covariant _SliverHeaderDelegate oldDelegate) =>
      oldDelegate.child != child;
}

class _TicketRecordCard extends StatelessWidget {
  final Complaint complaint;
  const _TicketRecordCard({required this.complaint});

  @override
  Widget build(BuildContext context) {
    final ticketId = '#${complaint.id.substring(0, 8).toUpperCase()}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ComplaintDetailScreen(complaint: complaint),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumbnail(complaint.imagePath, complaint.category),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _statusPill(complaint.status),
                          Text(
                            DateFormat('MMM dd').format(complaint.date),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        complaint.title,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        complaint.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              ticketId,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          _buildPriorityTag(complaint.priority),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(String path, ComplaintCategory category) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.surfaceScaffold,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: path.isNotEmpty
                ? (path.startsWith('http')
                      ? Image.network(
                          path,
                          fit: BoxFit.cover,
                          width: 64,
                          height: 64,
                          errorBuilder: (ctx, obj, stack) => Icon(
                            category.icon,
                            size: 24,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        )
                      : Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          width: 64,
                          height: 64,
                          errorBuilder: (ctx, obj, stack) => Icon(
                            category.icon,
                            size: 24,
                            color: AppTheme.textSecondary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ))
                : Icon(
                    category.icon,
                    size: 24,
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
                  ),
          ),
          if (path.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriorityTag(ComplaintPriority priority) {
    Color color;
    switch (priority) {
      case ComplaintPriority.high:
        color = const Color(0xFFE11D48);
        break;
      case ComplaintPriority.medium:
        color = const Color(0xFFD97706);
        break;
      case ComplaintPriority.low:
        color = const Color(0xFF059669);
        break;
    }
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          priority.name.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

Widget _statusPill(ComplaintStatus status) {
  final color = Color(status.colorValue);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          status.label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    ),
  );
}
