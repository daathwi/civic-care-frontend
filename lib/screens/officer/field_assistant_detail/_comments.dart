part of 'field_assistant_task_detail.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Comments / Discussion Room — Worker-differentiated bubbles
// ═══════════════════════════════════════════════════════════════════════════════

extension _FADetailComments on _FieldAssistantTaskDetailState {
  Widget _buildDiscussionRoom(Complaint c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              const Icon(
                Icons.forum_rounded,
                size: 16,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                'DISCUSSION ROOM',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: const Color(0xFF6B7280),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${c.comments.length} MESSAGES',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF4B5563),
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 480,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Interaction header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      '${c.comments.length} Comments • ${c.upvotes - c.downvotes} Net Votes',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    CivicVoteButton(
                      isUpvote: true,
                      count: c.upvotes,
                      onPressed: () =>
                          ref.read(complaintProvider.notifier).upvote(c.id),
                    ),
                    const SizedBox(width: 10),
                    CivicVoteButton(
                      isUpvote: false,
                      count: c.downvotes,
                      onPressed: () =>
                          ref.read(complaintProvider.notifier).downvote(c.id),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // Comments list
              Expanded(
                child: c.comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 40,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No activity yet.\nBe the first to say something.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: Colors.grey[400],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Scrollbar(
                        controller: _commentScrollController,
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _commentScrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: c.comments.length,
                          itemBuilder: (_, i) =>
                              _buildCommentItem(c.comments[i]),
                        ),
                      ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),

              // Inline comment input
              _buildCommentInput(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentItem(Comment comment) {
    if (comment.userName.toLowerCase() == 'system' ||
        comment.text.startsWith('System:')) {
      return Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            comment.text.replaceAll('System:', '').trim(),
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final currentUserId = ref.read(authProvider).user?.id ?? '';
    final isWorker = comment.userId == currentUserId;

    // Worker comments: teal tinted. Other: neutral.
    final bgColor = isWorker
        ? AppTheme.primary.withValues(alpha: 0.06)
        : Colors.transparent;
    final avatarBg = isWorker
        ? AppTheme.primary
        : AppTheme.primary.withValues(alpha: 0.1);
    final avatarTextColor = isWorker ? Colors.white : AppTheme.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: isWorker ? const EdgeInsets.all(12) : EdgeInsets.zero,
      decoration: isWorker
          ? BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.10),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: avatarBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                comment.userName.isNotEmpty
                    ? comment.userName[0].toUpperCase()
                    : '?',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: avatarTextColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      comment.userName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    if (isWorker) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          comment.userName.toLowerCase().contains('assistant') ||
                                  comment.text.contains('assistant')
                              ? 'ASSISTANT'
                              : 'OFFICER',
                          style: GoogleFonts.inter(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('hh:mm a').format(comment.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: const Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: const Color(0xFF374151),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _commentController,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Add an official update...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[400],
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _addComment(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _addComment,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
