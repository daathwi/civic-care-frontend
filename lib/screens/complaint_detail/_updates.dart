part of 'complaint_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Updates Section — Tab section, updates tab, timeline items, assignment card,
// bottom actions, assign dialog
// ═══════════════════════════════════════════════════════════════════════════════

extension _ComplaintDetailUpdates on _ComplaintDetailScreenState {
  Widget _buildTabSection(Complaint c) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceScaffold,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          _tabButton(0, 'Updates', Icons.update_rounded),
          _tabButton(1, 'Comments', Icons.forum_rounded),
        ],
      ),
    );
  }

  Widget _tabButton(int index, String label, IconData icon) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _rebuildState(() => _selectedTab = index);
          if (index == 1) {
            _scrollToBottom();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpdatesTab(Complaint c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (c.status == ComplaintStatus.completed &&
            c.resolutionImagePath != null &&
            c.resolutionImagePath!.isNotEmpty) ...[
          Text(
            'RESOLUTION PROOF',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.grey[400],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: c.resolutionImagePath!.startsWith('http')
                ? Image.network(
                    c.resolutionImagePath!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, obj, stack) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[100],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                  )
                : Image.file(
                    File(c.resolutionImagePath!),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(height: 32),
        ],

        // ── Citizen Rating Card ────────────────────────────────────────────
        if (c.status == ComplaintStatus.completed) ...[
          _buildCitizenRatingCard(c),
          const SizedBox(height: 24),
        ],

        if (c.assignedTo != null) ...[
          _buildAssignmentCard(c),
          const SizedBox(height: 32),
        ],
        Text(
          'TICKET TIMELINE',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.grey[400],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 20),
        if (c.events.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No status updates recorded yet.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            ),
          )
        else
          ...c.events.asMap().entries.map((entry) {
            bool isLast = entry.key == c.events.length - 1;
            return _buildTimelineItem(entry.value, isLast);
          }),
      ],
    );
  }

  Widget _buildAssignmentCard(Complaint c) {
    final userRole = ref.watch(authProvider).user?.role;
    final isCitizen = userRole == UserRole.citizen;
    final isManager = userRole == UserRole.fieldManager;
    final workers = ref.watch(fieldWorkerProvider);
    final assignedWorker = c.assignedToId != null
        ? workers.where((w) => w.id == c.assignedToId).firstOrNull
        : null;

    // Role-based label
    final String cardLabel;
    if (isManager) {
      cardLabel = 'OFFICER ASSIGNED';
    } else if (isCitizen) {
      cardLabel = 'FIELD OFFICER';
    } else {
      // Field assistant
      cardLabel = 'ASSIGNED BY';
    }

    // For field assistant, the card shows the manager/admin who assigned
    final String cardName;
    if (userRole == UserRole.fieldAssistant) {
      cardName = c.assignedByName ?? 'Management';
    } else {
      cardName = c.assignedTo ?? 'Unassigned';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary,
                child: Icon(
                  userRole == UserRole.fieldAssistant
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cardName,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (assignedWorker != null && assignedWorker.ratingsCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, size: 14, color: Colors.amber[700]),
                            const SizedBox(width: 4),
                            Text(
                              '${assignedWorker.rating.toStringAsFixed(1)} (${assignedWorker.ratingsCount})',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (!isCitizen)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          grievanceId: c.id,
                          grievanceTitle: c.title,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.forum_rounded, size: 16),
                  label: const Text('STAFF CHAT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          // Show worker contact details (visible to all including citizens)
          if (c.workerContact != null && c.workerContact!.isNotEmpty) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  c.workerContact!,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => launchPhoneDialer(c.workerContact),
                  icon: const Icon(Icons.call, size: 14),
                  label: const Text('CALL'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineItem(ComplaintEvent event, bool isLast) {
    final accent = eventAccentColor(event.title);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(event.icon, size: 18, color: accent),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFFE5E7EB)),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _formatEventTitle(event.title),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, hh:mm a').format(event.timestamp),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatEventTitle(String title) {
    if (title.isEmpty) return title;
    switch (title.toLowerCase()) {
      case 'inprogress':
        return 'In progress';
      case 'resolved':
        return 'Resolved';
      case 'pending':
        return 'Pending';
      default:
        return title;
    }
  }

  Widget _buildBottomActions(Complaint c) {
    final effectiveUser = ref.watch(effectiveUserProvider);
    final user = ref.watch(authProvider).user;
    final isManager =
        user?.role == UserRole.fieldManager || user?.role == UserRole.admin;
    final isUnassigned = c.status == ComplaintStatus.incompleteUnassigned;
    final isCompleted = c.status == ComplaintStatus.completed;
    final inDepartmentPortal = effectiveUser?.department != null;
    final hasAssignment = c.assignedTo != null && c.assignedTo!.isNotEmpty;

    if (!isManager || !inDepartmentPortal || isCompleted) {
      return const SizedBox.shrink();
    }

    // Show ASSIGN for unassigned, REASSIGN for already-assigned
    if (!isUnassigned && !hasAssignment) {
      return const SizedBox.shrink();
    }

    final buttonLabel = hasAssignment ? 'REASSIGN OFFICER' : 'ASSIGN OFFICER';
    final buttonIcon = hasAssignment ? Icons.swap_horiz_rounded : Icons.person_add_rounded;
    final buttonColor = Colors.teal;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.teal.withValues(alpha: 0.1), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () {
          final workers = ref.read(fieldWorkerProvider);
          _showAssignDialog(c, workers);
        },
        icon: Icon(buttonIcon),
        label: Text(
          buttonLabel,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _showAssignDialog(Complaint c, List<FieldWorker> allWorkers) {
    FieldWorker? selected;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final user = ref.read(effectiveUserProvider) ??
              ref.read(authProvider).user;
          final complaintDeptId = c.category.name.toLowerCase();
          final filteredByDept = allWorkers.where((w) {
            return w.department.id.contains(complaintDeptId) || 
                   complaintDeptId.contains(w.department.id);
          }).toList();

          final filtered = filteredByDept.isNotEmpty ? filteredByDept : allWorkers.toList();

          // Sort so those in the same ward come first (already mostly filtered by API, but extra safety)
          filtered.sort((a, b) {
            final aInWard = a.lastActiveWard == c.ward;
            final bInWard = b.lastActiveWard == c.ward;
            if (aInWard && !bInWard) return -1;
            if (!aInWard && bInWard) return 1;
            return 0;
          });

          if (selected != null && !filtered.contains(selected)) selected = null;

          return SafeArea(
            bottom: false,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assign Field Assistant',
                            style: GoogleFonts.outfit(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            c.title,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  filteredByDept.isNotEmpty
                      ? 'Showing experts in ${c.category.label} (in ${user?.ward ?? "your ward"}).'
                      : 'No specialists in ${c.category.label} found. Showing all available assistants in ${user?.ward ?? "your ward"}.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                Flexible(
                  child: filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'No field assistants available in this ward',
                              style: GoogleFonts.inter(color: Colors.grey[500]),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            final w = filtered[idx];
                            final isSelected = selected == w;
                            return InkWell(
                              onTap: () => setSheet(() => selected = w),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.teal.withValues(alpha: 0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected ? Colors.teal.withValues(alpha: 0.3) : Colors.grey.shade200,
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: isSelected ? Colors.teal.withValues(alpha: 0.15) : Colors.grey.shade100,
                                      child: Text(
                                        w.name[0],
                                        style: TextStyle(
                                          color: isSelected ? Colors.teal[800] : Colors.grey[700],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            w.name,
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isSelected ? Colors.teal[900] : Colors.grey[800],
                                            ),
                                          ),
                                           Text(
                                             '${w.department.shortCode} • ${w.designation} • ${w.phone}',
                                             style: GoogleFonts.inter(
                                               fontSize: 12,
                                               color: isSelected ? Colors.teal[700] : Colors.grey[600],
                                             ),
                                           ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                          const SizedBox(width: 4),
                                          Text(
                                            w.ratingsCount > 0
                                                ? '${w.rating.toStringAsFixed(1)} (${w.ratingsCount})'
                                                : '—',
                                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.amber[800], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.person_add_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                        label: _loadingId != null
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Confirm Assignment',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: selected == null || _loadingId != null
                            ? null
                            : () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final navigator = Navigator.of(ctx);
                                setSheet(() => _loadingId = selected!.id);
                                HapticFeedback.mediumImpact();
                                
                                final error = await ref
                                    .read(complaintProvider.notifier)
                                    .assignWorker(
                                      c.id,
                                      selected!.id,
                                      selected!.name,
                                      selected!.phone,
                                    );
                                
                                if (mounted) {
                                  setSheet(() => _loadingId = null);
                                  navigator.pop();
                                  
                                  if (error != null) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            const Icon(Icons.error_outline, color: Colors.white),
                                            const SizedBox(width: 8),
                                            Expanded(child: Text('Assignment failed: $error')),
                                          ],
                                        ),
                                        backgroundColor: AppTheme.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${selected!.name} assigned successfully!',
                                        ),
                                        backgroundColor: AppTheme.success,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    );
                                  }
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ));
        },
      ),
    );
  }

  // ── Citizen Rating Card ──────────────────────────────────────────────────

  Widget _buildCitizenRatingCard(Complaint c) {
    final user = ref.watch(authProvider).user;
    final isReporter = user != null && c.reporterId == user.id;

    // Not the reporter — NEVER show rating input or results to other citizens
    if (!isReporter) return const SizedBox.shrink();

    // Already rated — show static display
    if (c.citizenRating != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'YOUR RATING',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.teal[800],
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return Icon(
                  i < c.citizenRating! ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.teal[600],
                  size: 32,
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              c.citizenRating! < 3
                  ? 'Ticket reopened based on your feedback.'
                  : 'Thank you for your feedback!',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.teal[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Show interactive star rating
    return _CitizenRatingInput(
      complaintId: c.id,
      reopenCount: c.reopenCount,
      onRated: () {
        // Refresh after rating
        ref.read(complaintProvider.notifier).refreshGrievanceDetail(c.id);
      },
    );
  }
}

// ── Interactive Star Rating Widget ───────────────────────────────────────────

class _CitizenRatingInput extends ConsumerStatefulWidget {
  final String complaintId;
  final int reopenCount;
  final VoidCallback onRated;

  const _CitizenRatingInput({
    required this.complaintId,
    required this.reopenCount,
    required this.onRated,
  });

  @override
  ConsumerState<_CitizenRatingInput> createState() => _CitizenRatingInputState();
}

class _CitizenRatingInputState extends ConsumerState<_CitizenRatingInput> {
  int _hoveredStar = 0;
  bool _isSubmitting = false;

  Future<void> _submitRating(int rating) async {
    setState(() => _isSubmitting = true);
    final err = await ref
        .read(complaintProvider.notifier)
        .rateGrievance(widget.complaintId, rating);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Rating failed: $err')),
            ],
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      Complaint? updatedComplaint;
      for (final c in ref.read(complaintProvider).complaints) {
        if (c.id == widget.complaintId) {
          updatedComplaint = c;
          break;
        }
      }
      final msg = rating < 3
          ? ((updatedComplaint?.status == ComplaintStatus.escalated)
              ? 'Ticket escalated after repeated low-rating feedback ($rating/5).'
              : 'Ticket reopened based on your rating ($rating/5).')
          : 'Thank you for rating! ($rating/5)';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      widget.onRated();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.rate_review_rounded, color: Colors.teal[600], size: 32),
          const SizedBox(height: 12),
          Text(
            'HOW WAS THE RESOLUTION?',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.teal[800],
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Your feedback helps improve civic services.',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.teal[900]?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starNum = i + 1;
              return GestureDetector(
                onTap: _isSubmitting ? null : () => setState(() => _hoveredStar = starNum),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: starNum <= _hoveredStar ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      starNum <= _hoveredStar
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: starNum <= _hoveredStar
                          ? Colors.teal[500]
                          : Colors.teal[200],
                      size: 40,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_hoveredStar > 0) ...[
            const SizedBox(height: 8),
            Text(
              _hoveredStar < 3
                  ? ((widget.reopenCount + 1) >= 3
                      ? 'This is the 3rd reopen feedback. Ticket will be escalated.'
                      : 'This will reopen the ticket for review.')
                  : _hoveredStar == 3
                      ? 'Average'
                      : _hoveredStar == 4
                          ? 'Good job!'
                          : 'Excellent work!',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _hoveredStar < 3 ? Colors.orange[700] : Colors.teal[700],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: _isSubmitting
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.teal,
                        strokeWidth: 2.5,
                      ),
                    )
                  : ElevatedButton(
                      onPressed: () => _submitRating(_hoveredStar),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _hoveredStar < 3
                            ? ((widget.reopenCount + 1) >= 3
                                ? 'SUBMIT & ESCALATE'
                                : 'SUBMIT & REOPEN')
                            : 'SUBMIT RATING',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
