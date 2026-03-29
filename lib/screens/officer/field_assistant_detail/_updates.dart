part of 'field_assistant_task_detail.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Updates Section — Tab section, updates tab, assignment card, timeline,
// contact phone, bottom actions
// ═══════════════════════════════════════════════════════════════════════════════

extension _FADetailUpdates on _FieldAssistantTaskDetailState {
  Widget _buildTabSection() {
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
          HapticFeedback.selectionClick();
          _rebuildState(() => _selectedTab = index);
          if (index == 1) _scrollToBottom();
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
        // Resolution proof
        if (c.status == ComplaintStatus.completed &&
            ((c.resolutionImagePath != null &&
                    c.resolutionImagePath!.isNotEmpty) ||
                _resolutionPhoto != null)) ...[
          Text(
            'RESOLUTION PROOF',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: _resolutionPhoto != null
                ? Image.file(
                    File(_resolutionPhoto!.path),
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  )
                : (c.resolutionImagePath!.startsWith('http')
                      ? Image.network(
                          c.resolutionImagePath!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, obj, stack) => Container(
                            height: 200,
                            color: AppTheme.surface,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                size: 48,
                                color: AppTheme.textSecondary.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              color: AppTheme.surface,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: AppTheme.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                        )
                      : Image.file(
                          File(c.resolutionImagePath!),
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )),
          ),
          const SizedBox(height: 32),
        ],

        // Assignment card
        if (c.assignedTo != null) ...[
          _buildAssignmentCard(c),
          const SizedBox(height: 32),
        ],

        // Timeline
        Text(
          'TICKET TIMELINE',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 20),
        if (c.events.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No status updates recorded yet.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
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
    final isManager = userRole == UserRole.fieldManager;

    // Role-based label and name
    final String cardLabel;
    final String cardName;
    final IconData cardIcon;
    if (isManager) {
      cardLabel = 'OFFICER ASSIGNED';
      cardName = c.assignedTo ?? 'Unassigned';
      cardIcon = Icons.person;
    } else {
      // Field assistant sees who assigned them
      cardLabel = 'ASSIGNED BY';
      cardName = c.assignedByName ?? 'Management';
      cardIcon = Icons.admin_panel_settings_rounded;
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
                child: Icon(cardIcon, color: Colors.white, size: 20),
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
                  ],
                ),
              ),
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
          // Show relevant contact - manager phone for assistants, reporter phone for managers
          if (_contactPhone(c, isManager) != null) ...[
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.phone_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isManager ? 'REPORTER CONTACT' : 'MANAGER CONTACT',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _contactPhone(c, isManager)!,
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _callCitizen,
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
          if (c.status == ComplaintStatus.incompleteAssigned ||
              c.status == ComplaintStatus.ongoing ||
              c.status == ComplaintStatus.escalated) ...[
            const Divider(height: 24),
            AssignmentTimerWidget(complaint: c),
          ],
        ],
      ),
    );
  }

  /// Returns the contact phone to show based on role.
  String? _contactPhone(Complaint c, bool isManager) {
    if (isManager) {
      final p = c.reporterPhone;
      return (p != null && p.isNotEmpty) ? p : null;
    } else {
      final p = c.assignedByPhone;
      return (p != null && p.isNotEmpty) ? p : null;
    }
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
                      Text(
                        _formatEventTitle(event.title),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        DateFormat('MMM dd, hh:mm a').format(event.timestamp),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFF6B7280),
                      height: 1.4,
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

  Widget _buildBottomActions(
    Complaint c,
    bool canStartWork,
    bool canCaptureResolve,
    bool clockedIn,
    bool atSite,
  ) {
    if (c.status == ComplaintStatus.completed) return const SizedBox.shrink();

    final isPending = c.status == ComplaintStatus.incompleteAssigned;
    final canAct = isPending ? canStartWork : canCaptureResolve;
    final label = isPending ? 'START WORKING' : 'CAPTURE RESOLUTION';
    final icon = isPending
        ? Icons.play_arrow_rounded
        : Icons.camera_alt_rounded;
    final actionColor = isPending ? AppTheme.primary : Colors.teal;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _callCitizen,
              icon: const Icon(Icons.phone_rounded, size: 18),
              label: Text(
                'CITIZEN',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _isUpdating
                ? Center(
                    child: CircularProgressIndicator(
                      color: actionColor,
                      strokeWidth: 2.5,
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: canAct
                        ? (isPending ? _startTask : _captureAndResolve)
                        : null,
                    icon: Icon(icon, size: 20),
                    label: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: actionColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: actionColor.withValues(
                        alpha: 0.4,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.8,
                      ),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
