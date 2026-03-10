import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/complaint.dart';
import '../../providers/complaint_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/civic_ui.dart';
import '../../widgets/sensitive_blur_wrapper.dart';
import 'field_assistant_detail/field_assistant_task_detail.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CivicCare Worker Tasks — Social Feed Style (Matching Citizen Ward Feed)
// ═══════════════════════════════════════════════════════════════════════════════

class FieldAssistantTasksScreen extends ConsumerStatefulWidget {
  const FieldAssistantTasksScreen({super.key});

  @override
  ConsumerState<FieldAssistantTasksScreen> createState() =>
      _FieldAssistantTasksScreenState();
}

class _FieldAssistantTasksScreenState
    extends ConsumerState<FieldAssistantTasksScreen> {
  Complaint? _selectedTask;
  bool _isRefreshing = false;
  int _sortIndex = 0; // 0=All, 1=Pending, 2=In Progress, 3=Resolved

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await ref.read(complaintProvider.notifier).loadGrievances();
    if (mounted) setState(() => _isRefreshing = false);
  }

  List<Complaint> _filterTasks(List<Complaint> all) {
    final authState = ref.read(authProvider);
    final currentUser = authState.user;
    // Only show tasks assigned to the worker
    final myTasks = all.where((c) {
      if (currentUser == null) return false;
      return c.assignedToId == currentUser.id ||
          c.assignedTo == currentUser.name;
    }).toList();

    switch (_sortIndex) {
      case 1:
        return myTasks
            .where((c) => c.status == ComplaintStatus.incompleteAssigned)
            .toList();
      case 2:
        return myTasks
            .where((c) => c.status == ComplaintStatus.ongoing)
            .toList();
      case 3:
        return myTasks
            .where((c) => c.status == ComplaintStatus.completed)
            .toList();
      default:
        return myTasks;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allComplaints = ref.watch(complaintListProvider);
    final filteredTasks = _filterTasks(allComplaints);
    final showSkeleton =
        ref.watch(complaintProvider).isLoading && allComplaints.isEmpty;

    return Column(
      children: [
        Expanded(
          child: showSkeleton
              ? const SingleChildScrollView(
                  child: GrievanceListSkeleton(),
                )
              : ResponsiveLayout(
                  mobile: _buildMobileLayout(filteredTasks),
                  desktop: _buildWebLayout(filteredTasks, allComplaints),
                ),
        ),
      ],
    );
  }

  // ── Mobile Layout ──────────────────────────────────────────────────────────

  Widget _buildMobileLayout(List<Complaint> tasks) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.primary,
      backgroundColor: Colors.white,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Glassmorphic AppBar
          SliverAppBar(
            expandedHeight: 120,
            collapsedHeight: 64,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon:
                  const Icon(Icons.menu_rounded, color: AppTheme.textPrimary),
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
                  'My Tasks',
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
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _buildFilterChips(),
            ),
          ),

          // Task count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                '${tasks.length} Task${tasks.length == 1 ? '' : 's'}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),

          // Task cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
            sliver: tasks.isEmpty
                ? SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _TaskFeedCard(
                          task: tasks[index],
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FieldAssistantTaskDetail(
                                  complaint: tasks[index],
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    }, childCount: tasks.length),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Web Layout (master-detail) ─────────────────────────────────────────────

  Widget _buildWebLayout(
      List<Complaint> tasks, List<Complaint> allComplaints) {
    final selected = _selectedTask != null &&
            tasks.any((c) => c.id == _selectedTask!.id)
        ? tasks.firstWhere((c) => c.id == _selectedTask!.id)
        : (tasks.isNotEmpty ? tasks.first : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Master List
        Container(
          width: 440,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              right:
                  BorderSide(color: Colors.black.withValues(alpha: 0.05)),
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
                      'ASSIGNED TASKS',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tasks.length} Active Tasks',
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _buildFilterChips(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: tasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final c = tasks[index];
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
                ? FieldAssistantTaskDetail(
                    key: ValueKey(selected.id),
                    complaint: selected,
                    isEmbedded: true,
                  )
                : _buildSelectPlaceholder(),
          ),
        ),
      ],
    );
  }

  // ── Filter Chips ───────────────────────────────────────────────────────────

  Widget _buildFilterChips() {
    final labels = ['All', 'Pending', 'In Progress', 'Resolved'];
    final icons = [
      Icons.list_rounded,
      Icons.schedule_rounded,
      Icons.bolt_rounded,
      Icons.check_circle_rounded,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(labels.length, (i) {
          final isSelected = _sortIndex == i;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _sortIndex = i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary
                        : AppTheme.border,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color:
                                AppTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      icons[i],
                      size: 14,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      labels[i],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Web Compact Card ───────────────────────────────────────────────────────

  Widget _buildCompactCard(Complaint c, bool isSelected) {
    final statusColor = Color(c.status.colorValue);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: isSelected
            ? AppTheme.primary.withValues(alpha: 0.04)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => setState(() => _selectedTask = c),
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
                      backgroundColor:
                          AppTheme.primary.withValues(alpha: 0.1),
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
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
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
                      c.status.label.toUpperCase(),
                      statusColor,
                    ),
                    const Spacer(),
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

  // ── Empty / Placeholder ────────────────────────────────────────────────────

  Widget _buildEmptyState() {
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
                Icons.task_alt_rounded,
                size: 80,
                color: AppTheme.primary.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _sortIndex == 0
                  ? 'No tasks assigned'
                  : 'No ${['', 'pending', 'in-progress', 'resolved'][_sortIndex]} tasks',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _sortIndex == 0
                  ? 'New tasks will appear here when assigned by your manager.'
                  : 'Try switching to a different filter.',
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
              label: const Text('Refresh'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle:
                    GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
            ),
          ],
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
            'Select a task to view details',
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

// ═══════════════════════════════════════════════════════════════════════════════
// Task Feed Card (social media style — matching citizen _WardComplaintCard)
// ═══════════════════════════════════════════════════════════════════════════════

class _TaskFeedCard extends ConsumerWidget {
  final Complaint task;
  final VoidCallback onTap;

  const _TaskFeedCard({required this.task, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = Color(task.status.colorValue);

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
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reporter info + status + time
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor:
                              AppTheme.primary.withValues(alpha: 0.1),
                          child: Text(
                            task.userName[0].toUpperCase(),
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
                                task.userName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                '${task.ward} · ${_timeAgo(task.date)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                task.status.label.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Title
                    Text(
                      task.title,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                        color: AppTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Description preview
                    Text(
                      task.description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color:
                            AppTheme.textPrimary.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 16),

                    // Info chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoChip(
                          label: (task.departmentDisplayName ??
                                  task.category.label)
                              .toUpperCase(),
                          icon: task.category.icon,
                          color: AppTheme.primary,
                        ),
                        _priorityChip(task.priority),
                        if (task.address.isNotEmpty)
                          _infoChip(
                            label: task.address,
                            icon: Icons.location_on_rounded,
                            color: AppTheme.textSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Image
              if (task.imagePath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: SensitiveBlurWrapper(
                    isSensitive: task.isSensitive,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: task.imagePath.startsWith('http')
                            ? Image.network(
                                task.imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, s) =>
                                    _imgPlaceholder(),
                              )
                            : Image.file(
                                File(task.imagePath),
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, s) =>
                                    _imgPlaceholder(),
                              ),
                      ),
                    ),
                  ),
                ),

              // Interaction bar
              const Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.border,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    _actionBtn(
                      icon: Icons.arrow_upward_rounded,
                      label: '${task.upvotes}',
                      color: AppTheme.success,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(complaintProvider.notifier)
                            .upvote(task.id);
                      },
                    ),
                    const SizedBox(width: 4),
                    _actionBtn(
                      icon: Icons.arrow_downward_rounded,
                      label: '${task.downvotes}',
                      color: AppTheme.error,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref
                            .read(complaintProvider.notifier)
                            .downvote(task.id);
                      },
                    ),
                    const Spacer(),
                    _actionBtn(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: '${task.comments.length}',
                      color: AppTheme.primary,
                      onTap: onTap,
                      filled: true,
                    ),
                  ],
                ),
              ),

              // Comment preview
              if (task.comments.isNotEmpty)
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
                      ...task.comments.take(1).map(
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
                      if (task.comments.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'View all ${task.comments.length} comments',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityChip(ComplaintPriority p) {
    final color = _priorityColor(p);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 12, color: color),
          const SizedBox(width: 6),
          Text(
            p.name.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
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
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color:
                filled ? color.withValues(alpha: 0.1) : Colors.transparent,
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
}

// ── Helpers ──────────────────────────────────────────────────────────────────

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
  switch (p) {
    case ComplaintPriority.high:
      return const Color(0xFFFF3B30);
    case ComplaintPriority.medium:
      return const Color(0xFFFF9500);
    case ComplaintPriority.low:
      return const Color(0xFF34C759);
  }
}
