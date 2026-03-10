part of 'complaint_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Common UI Widgets — Bento cards, status row, metadata tags, header image
// ═══════════════════════════════════════════════════════════════════════════════

extension _ComplaintDetailWidgets on _ComplaintDetailScreenState {
  Widget _buildBentoCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: AppTheme.cardDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatusRow(Complaint c) {
    final statusColor = Color(c.status.colorValue);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(c.status.icon, color: statusColor, size: 20),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.status.label.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: statusColor,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Updated ${DateFormat('MMM dd, yyyy').format(c.date)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataTags(Complaint c) {
    final deptLabel = c.departmentDisplayName ?? c.category.label;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _tag(label: deptLabel, icon: c.category.icon),
        _tag(label: c.subCategory, icon: Icons.layers_outlined),
        _buildPriorityTag(c.priority),
        _tag(label: 'Ward ${c.ward}', icon: Icons.location_city),
      ],
    );
  }

  Widget _tag({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceScaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
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
        color = const Color(0xFFFF3B30); // iOS Red
        break;
      case ComplaintPriority.medium:
        color = const Color(0xFFFF9500); // iOS Orange
        break;
      case ComplaintPriority.low:
        color = const Color(0xFF34C759); // iOS Green
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag_rounded, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            priority.name.toUpperCase(),
            style: TextStyle(
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

  Widget _buildHeaderImage(Complaint c) {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: AppTheme.surfaceScaffold,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: c.imagePath.isNotEmpty
          ? SensitiveBlurWrapper(
              isSensitive: c.isSensitive,
              child: Hero(
                tag: 'complaint_image_${c.id}',
                child: c.imagePath.startsWith('http')
                    ? Image.network(
                        c.imagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (ctx, obj, stack) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            size: 64,
                            color: Colors.grey,
                          ),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                      )
                    : Image.file(File(c.imagePath), fit: BoxFit.cover),
              ),
            )
          : const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 64,
                color: Colors.grey,
              ),
            ),
    );
  }
}
