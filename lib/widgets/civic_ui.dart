import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../core/app_theme.dart';

// ── Design tokens: delegate to AppTheme for CivicConnect parity ───────────────

class CivicColors {
  static Color get teal => AppTheme.primary;
  static Color get bg => AppTheme.surfaceScaffold;
  static Color get textPri => AppTheme.textPrimary;
  static Color get textSec => AppTheme.textSecondary;
  static const Color textMuted = Color(0xFF72777F);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color upvoteGreen = Color(0xFF059669);
  static const Color downvoteRed = Color(0xFFDC2626);
}

// ── Vote buttons (consistent UX across complaint detail, feed, tasks) ─────────

class CivicVoteButton extends StatelessWidget {
  final bool isUpvote;
  final int count;
  final VoidCallback onPressed;

  const CivicVoteButton({
    super.key,
    required this.isUpvote,
    required this.count,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isUpvote ? CivicColors.upvoteGreen : CivicColors.downvoteRed;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isUpvote ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact vote + comment counts for list cards (non-tappable).
class CivicVoteCounts extends StatelessWidget {
  final int upvotes;
  final int downvotes;
  final int commentsCount;

  const CivicVoteCounts({
    super.key,
    required this.upvotes,
    required this.downvotes,
    required this.commentsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.thumb_up_rounded,
          size: 12,
          color: CivicColors.upvoteGreen.withValues(alpha: 0.9),
        ),
        const SizedBox(width: 2),
        Text(
          '$upvotes',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: CivicColors.upvoteGreen,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.thumb_down_rounded,
          size: 12,
          color: CivicColors.downvoteRed.withValues(alpha: 0.8),
        ),
        const SizedBox(width: 2),
        Text(
          '$downvotes',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: CivicColors.downvoteRed,
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.chat_bubble_outline_rounded,
          size: 12,
          color: CivicColors.textMuted,
        ),
        const SizedBox(width: 2),
        Text(
          '$commentsCount',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: CivicColors.textMuted,
          ),
        ),
      ],
    );
  }
}

// ── Offline Banner ───────────────────────────────────────────────────────────

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[800],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            'No internet connection',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer Skeletons ────────────────────────────────────────────────────────

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

Widget _shimmerWrap({required Widget child}) {
  return Shimmer.fromColors(
    baseColor: Colors.grey[200]!,
    highlightColor: Colors.white,
    child: child,
  );
}

/// Skeleton for a grievance list tile (used in ward feed, history, tasks).
class GrievanceCardSkeleton extends StatelessWidget {
  const GrievanceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerBox(width: 40, height: 40, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(width: 180, height: 14),
                      SizedBox(height: 6),
                      ShimmerBox(width: 100, height: 10),
                    ],
                  ),
                ),
                const ShimmerBox(width: 60, height: 22, radius: 12),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBox(width: double.infinity, height: 12),
            const SizedBox(height: 6),
            const ShimmerBox(width: 200, height: 12),
            const SizedBox(height: 12),
            Row(
              children: const [
                ShimmerBox(width: 60, height: 24, radius: 12),
                SizedBox(width: 8),
                ShimmerBox(width: 60, height: 24, radius: 12),
                Spacer(),
                ShimmerBox(width: 80, height: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Multiple skeleton cards for a list.
class GrievanceListSkeleton extends StatelessWidget {
  final int count;
  const GrievanceListSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: count,
      itemBuilder: (err, stack) => const GrievanceCardSkeleton(),
    );
  }
}

/// Skeleton for dashboard KPI cards (bento grid).
class DashboardKpiSkeleton extends StatelessWidget {
  const DashboardKpiSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _kpiBox()),
              const SizedBox(width: 12),
              Expanded(child: _kpiBox()),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kpiBox()),
              const SizedBox(width: 12),
              Expanded(child: _kpiBox()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiBox() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }
}

/// Skeleton for worker list items.
class WorkerCardSkeleton extends StatelessWidget {
  const WorkerCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const ShimmerBox(width: 48, height: 48, radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerBox(width: 140, height: 14),
                  SizedBox(height: 6),
                  ShimmerBox(width: 90, height: 10),
                ],
              ),
            ),
            const ShimmerBox(width: 50, height: 22, radius: 12),
          ],
        ),
      ),
    );
  }
}

/// Error state widget matching the civic design system.
class CivicErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const CivicErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: CivicColors.danger.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: CivicColors.danger,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Something went wrong',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: CivicColors.textPri,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: CivicColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Proximity warning for field workers (high-visibility).
class ProximityWarning extends StatelessWidget {
  final double distanceMeters;

  const ProximityWarning({super.key, required this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CivicColors.warning, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CivicColors.warning.withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_off_rounded,
              color: CivicColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Not at Site',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7B5800),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  !distanceMeters.isFinite
                      ? 'Distance unavailable — turn on GPS to update.'
                      : 'You are ${distanceMeters.toStringAsFixed(0)}m away. Move within 10m to update.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF7B5800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
