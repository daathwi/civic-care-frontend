import 'dart:ui';
import 'package:flutter/material.dart';

/// Single source of truth for CivicConnect/CivicCare brand - Apple Premium Native style.
class AppTheme {
  AppTheme._();

  // Primary palette (Teal Green accent, used sparingly)
  static const Color primary = Color(0xFF008080);
  static const Color primaryDark = Color(0xFF006666);
  static const Color primaryLight = Color(0xFFE6F7F7);

  // Surfaces (Pure white backgrounds, system gray for grouping)
  static const Color surface = Color(
    0xFFF2F2F7,
  ); // iOS System Grouped Background
  static const Color surfaceScaffold = Color(
    0xFFF2F2F7,
  ); // iOS System Grouped Background
  static const Color cardBg = Colors.white;

  // Text
  static const Color textPrimary = Colors.black;
  static const Color textSecondary = Color(0xFF8E8E93); // iOS System Gray

  // Borders & dividers
  static const Color border = Color(0xFFE5E5EA); // iOS Separator

  // Semantic
  static const Color success = Color(0xFF34C759); // iOS System Green
  static const Color warning = Color(0xFFFF9500); // iOS System Orange
  static const Color error = Color(0xFFFF3B30); // iOS System Red
  static const Color info = Color(0xFF007AFF); // iOS System Blue

  // Layout (Squircle style)
  static const double cardRadius = 24.0;
  static const double buttonRadius = 16.0;
  static const double inputRadius = 12.0;

  // Glassmorphism util
  static Widget glass({
    required Widget child,
    double blur = 20.0,
    Color color = const Color(0xB3FFFFFF), // 70% white
    BorderRadius? borderRadius,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(color: color),
          child: child,
        ),
      ),
    );
  }

  // Card style used across dashboard, add complaint, feeds
  static BoxDecoration cardDecoration({
    Color? color,
    Border? border,
    List<BoxShadow>? boxShadow,
    double borderRadius = cardRadius,
  }) {
    return BoxDecoration(
      color: color ?? cardBg,
      borderRadius: BorderRadius.circular(borderRadius),
      border:
          border, // Apple cards typically don't have borders if they have shadows, relying on contrast
      boxShadow:
          boxShadow ??
          [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
    );
  }

  // Grouped cell style for settings-like forms
  static BoxDecoration groupedCellDecoration({
    bool isFirst = false,
    bool isLast = false,
    bool isSingle = false,
  }) {
    late BorderRadius radius;
    if (isSingle) {
      radius = BorderRadius.circular(12);
    } else if (isFirst) {
      radius = const BorderRadius.vertical(top: Radius.circular(12));
    } else if (isLast) {
      radius = const BorderRadius.vertical(bottom: Radius.circular(12));
    } else {
      radius = BorderRadius.zero;
    }

    return BoxDecoration(color: Colors.white, borderRadius: radius);
  }

  static InputDecoration inputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: textSecondary, size: 20),
      labelStyle: const TextStyle(color: textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(inputRadius),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
