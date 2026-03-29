import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_theme.dart';
import '../providers/weather_provider.dart';
import '../screens/ward_environment_screen.dart';

/// Compact weather/AQI card for dashboard. Tappable to open full Environment screen.
class WardWeatherWidget extends ConsumerWidget {
  const WardWeatherWidget({super.key});

  static Color _aqiColor(int? aqi) {
    if (aqi == null) return AppTheme.textSecondary;
    if (aqi <= 50) return const Color(0xFF34C759); // good
    if (aqi <= 100) return const Color(0xFFB8860B); // moderate — warm amber
    if (aqi <= 150) return const Color(0xFFFF9500); // unhealthy sensitive
    if (aqi <= 200) return const Color(0xFFFF3B30); // unhealthy
    if (aqi <= 300) return const Color(0xFFAF52DE); // very unhealthy
    return const Color(0xFF7E2B2B); // hazardous
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(wardWeatherProvider);

    return async.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();

        final aqi = data.airQuality.currentAqi;
        final temp = data.weather.currentTemp;
        final humidity = data.weather.currentHumidity;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WardEnvironmentScreen(),
              ),
            ),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.cardDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _aqiColor(aqi).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.air,
                      color: _aqiColor(aqi),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${data.wardName} Environment',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (aqi != null)
                              _chip('AQI $aqi', _aqiColor(aqi)),
                            if (temp != null) ...[
                              if (aqi != null) const SizedBox(width: 8),
                              _chip('${temp.toStringAsFixed(0)}°C', AppTheme.primary),
                            ],
                            if (humidity != null) ...[
                              if (aqi != null || temp != null) const SizedBox(width: 8),
                              _chip('$humidity%', AppTheme.info),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_right,
                    color: AppTheme.textSecondary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => _buildSkeleton(context),
      error: (err, _) => _buildErrorCard(context, ref, err),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, WidgetRef ref, Object err) {
    final short = weatherLoadErrorMessage(err);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ref.invalidate(wardWeatherProvider),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration(),
          child: Row(
            children: [
              Icon(Icons.cloud_off_rounded, color: AppTheme.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weather unavailable',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      short,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Tap to retry',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
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

  Widget _buildSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
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
