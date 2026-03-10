import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/complaint.dart';
import '../providers/complaint_provider.dart';
import '../core/app_theme.dart';
import '../providers/connectivity_provider.dart';
import '../utils/responsive_utils.dart';
import '../widgets/civic_ui.dart';
import '../widgets/sensitive_blur_wrapper.dart';

import 'complaint_detail/complaint_detail_screen.dart';

class WardFeedScreen extends ConsumerStatefulWidget {
  const WardFeedScreen({super.key});

  @override
  ConsumerState<WardFeedScreen> createState() => _WardFeedScreenState();
}

class _WardFeedScreenState extends ConsumerState<WardFeedScreen> {
  Complaint? _selectedComplaint;
  bool _isRefreshing = false;

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await ref.read(complaintProvider.notifier).loadGrievances();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final gState = ref.watch(complaintProvider);
    final complaints = gState.complaints;
    final hasMore = gState.hasMore;
    final isLoadingMore = gState.isLoadingMore;
    final isOffline = ref.watch(connectivityProvider).valueOrNull == false;
    final showSkeleton = gState.isLoading && complaints.isEmpty;

    // Filter out resolved grievances for the community feed
    final activeComplaints = complaints
        .where((c) => c.status != ComplaintStatus.completed)
        .toList();

    return Column(
      children: [
        if (isOffline) const OfflineBanner(),
        Expanded(
          child: showSkeleton
              ? const SingleChildScrollView(child: GrievanceListSkeleton())
              : ResponsiveLayout(
                  mobile: _buildMobileLayout(
                    activeComplaints,
                    hasMore: hasMore,
                    isLoadingMore: isLoadingMore,
                  ),
                  desktop: _buildWebLayout(
                    activeComplaints,
                    hasMore: hasMore,
                    isLoadingMore: isLoadingMore,
                  ),
                ),
        ),
      ],
    );
  }

  // ── Mobile ─────────────────────────────────────────────────────────────────

  Widget _buildMobileLayout(
    List<Complaint> wardComplaints, {
    required bool hasMore,
    required bool isLoadingMore,
  }) {
    final userWard = ref.watch(userWardProvider);
    final itemCount = wardComplaints.length + (hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.primary,
      backgroundColor: Colors.white,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── Glassmorphic AppBar ─────────────────────
          SliverAppBar(
            expandedHeight: 120,
            collapsedHeight: 64,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            actions: const [SizedBox(width: 8)],
            flexibleSpace: AppTheme.glass(
              blur: 20,
              color: AppTheme.surfaceScaffold.withValues(alpha: 0.7),
              child: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.fromLTRB(60, 0, 20, 12),
                title: Text(
                  userWard,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                  ),
                ),
              ),
            ),
          ),

          if (_isRefreshing)
            const SliverToBoxAdapter(
              child: LinearProgressIndicator(
                backgroundColor: Color(0xFFE0E0E0),
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
            sliver: wardComplaints.isEmpty && !hasMore
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildPremiumEmptyState(),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      if (index == wardComplaints.length) {
                        return _buildLoadMoreButton(
                          isLoadingMore: isLoadingMore,
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _WardComplaintCard(
                          complaint: wardComplaints[index],
                        ),
                      );
                    }, childCount: itemCount),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Web ────────────────────────────────────────────────────────────────────

  Widget _buildWebLayout(
    List<Complaint> wardComplaints, {
    required bool hasMore,
    required bool isLoadingMore,
  }) {
    if (wardComplaints.isEmpty && !hasMore) return _buildPremiumEmptyState();

    final selected =
        _selectedComplaint != null &&
            wardComplaints.any((c) => c.id == _selectedComplaint!.id)
        ? wardComplaints.firstWhere((c) => c.id == _selectedComplaint!.id)
        : (wardComplaints.isNotEmpty ? wardComplaints.first : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master List
        Container(
          width: 440,
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
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'COMMUNITY FEED',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${wardComplaints.length} Active Issues',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: wardComplaints.length + (hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == wardComplaints.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: _buildLoadMoreButton(
                          isLoadingMore: isLoadingMore,
                        ),
                      );
                    }
                    final c = wardComplaints[index];
                    final isSelected = selected?.id == c.id;
                    return _buildCompactCard(c, isSelected);
                  },
                ),
              ),
            ],
          ),
        ),

        // Detail View
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

  // ── Shared UI Helpers ──────────────────────────────────────────────────────

  Widget _buildLoadMoreButton({required bool isLoadingMore}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ElevatedButton(
        onPressed: isLoadingMore
            ? null
            : () => ref.read(complaintProvider.notifier).loadMoreGrievances(),
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
                'Load More Issues',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }

  Widget _buildCompactCard(Complaint c, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => setState(() => _selectedComplaint = c),
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
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
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                      child: Text(
                        c.userName[0].toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.userName,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _timeAgo(c.date),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  c.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _miniChip(
                      (c.departmentDisplayName ?? c.category.label)
                          .toUpperCase(),
                      AppTheme.primary,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 12,
                      color: AppTheme.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${c.upvotes}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 12,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${c.comments.length}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
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

  Widget _miniChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSelectPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              Icons.touch_app_rounded,
              size: 48,
              color: Colors.grey[300],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Select an issue to inspect',
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

  Widget _buildPremiumEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.spa_rounded,
                size: 80,
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Peace in your ward',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No active community grievances found. Everything seems to be operating perfectly.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh Feed'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ward Complaint Card ──────────────────────────────────────────────────────

class _WardComplaintCard extends ConsumerWidget {
  final Complaint complaint;
  const _WardComplaintCard({required this.complaint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: AppTheme.cardDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                builder: (context) =>
                    ComplaintDetailScreen(complaint: complaint),
              ),
            );
          },
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppTheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            complaint.userName[0].toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                complaint.userName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${complaint.ward} · ${_timeAgo(complaint.date)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _priorityBadge(complaint.priority),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      complaint.title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      complaint.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppTheme.textPrimary.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoChip(
                          label:
                              (complaint.departmentDisplayName ??
                                      complaint.category.label)
                                  .toUpperCase(),
                          icon: complaint.category.icon,
                          color: AppTheme.primary,
                        ),
                        if (complaint.address.isNotEmpty)
                          _infoChip(
                            label: complaint.address,
                            icon: Icons.location_on_rounded,
                            color: AppTheme.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Image
              if (complaint.imagePath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SensitiveBlurWrapper(
                    isSensitive: complaint.isSensitive,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: complaint.imagePath.startsWith('http')
                            ? Image.network(
                                complaint.imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _imgPlaceholder(),
                              )
                            : Image.file(
                                File(complaint.imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => _imgPlaceholder(),
                              ),
                      ),
                    ),
                  ),
                ),

              // Interaction bar
              const Divider(height: 1, thickness: 1, color: AppTheme.border),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    _actionBtn(
                      icon: Icons.arrow_upward_rounded,
                      label: '${complaint.upvotes}',
                      color: AppTheme.success,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(complaintProvider.notifier)
                            .upvote(complaint.id);
                      },
                    ),
                    const SizedBox(width: 4),
                    _actionBtn(
                      icon: Icons.arrow_downward_rounded,
                      label: '${complaint.downvotes}',
                      color: AppTheme.error,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(complaintProvider.notifier)
                            .downvote(complaint.id);
                      },
                    ),
                    const Spacer(),
                    _actionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '${complaint.comments.length}',
                      color: AppTheme.primary,
                      onTap: () => _showCommentDialog(context, ref, complaint),
                      filled: true,
                    ),
                  ],
                ),
              ),

              // Comments preview
              if (complaint.comments.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceScaffold.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...complaint.comments
                          .take(1)
                          .map(
                            (com) => Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${com.userName}: ',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    com.text,
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityBadge(ComplaintPriority p) {
    final color = _priorityColor(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        p.name.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _infoChip({
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceScaffold,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: filled ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    color: AppTheme.border,
    child: const Center(child: Icon(Icons.error_outline)),
  );

  void _showCommentDialog(
    BuildContext context,
    WidgetRef ref,
    Complaint complaint,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add a Comment',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Share your thoughts...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref
                    .read(complaintProvider.notifier)
                    .addComment(complaint.id, controller.text.trim());
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Post', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

String _timeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inDays >= 7) {
    return DateFormat('MMM dd, yyyy').format(dateTime);
  } else if (difference.inDays >= 1) {
    return '${difference.inDays}d ago';
  } else if (difference.inHours >= 1) {
    return '${difference.inHours}h ago';
  } else if (difference.inMinutes >= 1) {
    return '${difference.inMinutes}m ago';
  } else {
    return 'Just now';
  }
}

Color _priorityColor(ComplaintPriority p) {
  return AppTheme.primary;
}
