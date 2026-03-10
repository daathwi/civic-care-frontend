import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';

/// CivicCare Delhi branding logo. Use everywhere for consistent branding.
/// Asset: assets/civiccare_logo_delhi.png
class AppLogo extends StatelessWidget {
  /// Logo image size (width and height).
  final double size;

  /// Whether to show "CivicCare" text below the logo.
  final bool showLabel;

  /// Optional subtitle (e.g. "Delhi", "Create your account").
  final String? subtitle;

  /// Color for the main label. Defaults to teal.
  final Color? labelColor;

  /// Color for subtitle. Defaults to grey or white70 when [labelColor] is white.
  final Color? subtitleColor;

  const AppLogo({
    super.key,
    this.size = 56,
    this.showLabel = false,
    this.subtitle,
    this.labelColor,
    this.subtitleColor,
  });

  static const String _assetPath = 'assets/civiccare_logo_delhi.jpg';
  static Color get _teal => AppTheme.primary;

  @override
  Widget build(BuildContext context) {
    final lColor = labelColor ?? _teal;
    final sColor =
        subtitleColor ??
        (lColor == Colors.white ? Colors.white70 : Colors.grey[600]!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _assetPath,
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (ctx, obj, stack) => _buildFallbackIcon(size),
        ),
        if (showLabel) ...[
          SizedBox(height: size <= 32 ? 6 : 10),
          Text(
            'CivicCare',
            style: GoogleFonts.outfit(
              fontSize: size <= 32 ? 16 : (size <= 56 ? 22 : 28),
              fontWeight: FontWeight.bold,
              color: lColor,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: size <= 32 ? 2 : 4),
            Text(
              subtitle!,
              style: GoogleFonts.inter(
                fontSize: size <= 32 ? 10 : (size <= 56 ? 12 : 14),
                color: sColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildFallbackIcon(double s) {
    return Container(
      padding: EdgeInsets.all(s * 0.28),
      decoration: BoxDecoration(
        color: _teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(s * 0.35),
      ),
      child: Icon(Icons.location_city, size: s * 0.6, color: _teal),
    );
  }
}
