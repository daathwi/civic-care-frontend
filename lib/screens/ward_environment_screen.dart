import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/ward_weather.dart';
import '../providers/weather_provider.dart';

/// Full weather dashboard: hero, tabs (Overview | Forecast | Air Quality), charts.
/// Apple Premium Native style — large title, Cupertino segmented control, inset grouped cards.
class WardEnvironmentScreen extends ConsumerStatefulWidget {
  const WardEnvironmentScreen({super.key});

  @override
  ConsumerState<WardEnvironmentScreen> createState() => _WardEnvironmentScreenState();
}

class _WardEnvironmentScreenState extends ConsumerState<WardEnvironmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static Color _aqiColor(int? aqi) {
    if (aqi == null) return AppTheme.textSecondary;
    if (aqi <= 50) return const Color(0xFF34C759);
    if (aqi <= 100) return const Color(0xFFFFCC00);
    if (aqi <= 150) return const Color(0xFFFF9500);
    if (aqi <= 200) return const Color(0xFFFF3B30);
    if (aqi <= 300) return const Color(0xFFAF52DE);
    return const Color(0xFF7E2B2B);
  }

  static IconData _weatherIcon(int code, bool isDay) {
    if (code == 0) return isDay ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_stars_fill;
    if (code <= 3) return CupertinoIcons.cloud_fill;
    if (code <= 49) return CupertinoIcons.cloud_fog_fill;
    if (code <= 69) return CupertinoIcons.drop_fill;
    if (code <= 79) return CupertinoIcons.snow;
    if (code <= 84) return CupertinoIcons.cloud_rain_fill;
    return CupertinoIcons.cloud_bolt_rain_fill;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(wardWeatherProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceScaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Weather',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Segment bar (Overview | Forecast | Air Quality)
            if (async.hasValue && async.value != null) _buildSegmentBar(context),
            // Content
            Expanded(
              child: async.when(
                data: (data) {
                  if (data == null) return _buildEmptyState();
                  return TabBarView(
                    controller: _tabController,
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    children: [
                      _OverviewTab(data: data, aqiColor: _aqiColor, weatherIcon: _weatherIcon, onRefresh: () => ref.invalidate(wardWeatherProvider)),
                      _ForecastTab(data: data, weatherIcon: _weatherIcon, onRefresh: () => ref.invalidate(wardWeatherProvider)),
                      _AirQualityTab(data: data, aqiColor: _aqiColor, onRefresh: () => ref.invalidate(wardWeatherProvider)),
                    ],
                  );
                },
                loading: () => const Center(child: CupertinoActivityIndicator(color: AppTheme.primary)),
                error: (e, _) => _buildErrorState(e, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentBar(BuildContext context) {
    final index = _tabController.index;
    const margin = 6.0;
    const labels = ['Overview', 'Forecast', 'Air Quality'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final third = w / 3;
            final pillWidth = third - 2 * margin;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  left: margin + index * third,
                  top: margin,
                  bottom: margin,
                  width: pillWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: List.generate(3, (i) {
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          if (index != i) _tabController.animateTo(i);
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            labels[i],
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: index == i ? FontWeight.w600 : FontWeight.w500,
                              color: index == i ? AppTheme.textPrimary : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No ward assigned or weather unavailable',
              style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object e, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.exclamationmark_circle, size: 48, color: AppTheme.error),
            const SizedBox(height: 16),
            Text('Failed to load', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(
              weatherLoadErrorMessage(e),
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: () => ref.invalidate(wardWeatherProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final WardWeather data;
  final Color Function(int?) aqiColor;
  final IconData Function(int, bool) weatherIcon;
  final VoidCallback onRefresh;

  const _OverviewTab({required this.data, required this.aqiColor, required this.weatherIcon, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cur = data.weather.current;
    final aqi = data.airQuality.currentAqi;
    final temp = cur?.temperature ?? data.weather.currentTemp ?? 0;
    final humidity = cur?.humidity ?? data.weather.currentHumidity ?? 0;
    final wind = cur?.windSpeed ?? data.weather.currentWindSpeed ?? 0;
    final pressure = cur?.pressure ?? data.weather.currentPressure;
    final code = data.weather.currentWeatherCode;
    final isDay = cur?.isDay ?? true;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ward label
            Text(
              data.wardName,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primary),
            ),
            const SizedBox(height: 12),
            // Hero card (inset grouped)
            _InsetCard(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(weatherIcon(code, isDay), size: 40, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${temp.toStringAsFixed(0)}°',
                          style: GoogleFonts.outfit(fontSize: 44, fontWeight: FontWeight.bold, color: AppTheme.textPrimary, height: 1),
                        ),
                        Text(weatherCodeLabel(code), style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary)),
                        if (cur != null && (cur.apparentTemperature - cur.temperature).abs() > 1)
                          Text('Feels like ${cur.apparentTemperature.toStringAsFixed(0)}°', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (aqi != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: aqiColor(aqi).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text('AQI', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: aqiColor(aqi))),
                          Text('$aqi', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: aqiColor(aqi))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // KPI row
            Row(
              children: [
                Expanded(child: _MiniKpi(icon: CupertinoIcons.drop_fill, label: 'Humidity', value: '$humidity%', color: AppTheme.info)),
                const SizedBox(width: 12),
                Expanded(child: _MiniKpi(icon: CupertinoIcons.wind, label: 'Wind', value: '${wind.toStringAsFixed(0)} km/h', color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (pressure != null) Expanded(child: _MiniKpi(icon: CupertinoIcons.gauge, label: 'Pressure', value: '${pressure.toStringAsFixed(0)} hPa', color: AppTheme.textSecondary)),
                if (pressure != null) const SizedBox(width: 12),
                Expanded(child: _MiniKpi(icon: Icons.air, label: 'PM2.5', value: '${(data.airQuality.currentPm25 ?? 0).toStringAsFixed(1)} μg/m³', color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 24),
            _buildHourlyChart(data),
          ],
        ),
      ),
    );
  }

  Widget _buildHourlyChart(WardWeather data) {
    final wth = data.weather;
    final times = wth.time.length > 24 ? wth.time.sublist(0, 24) : wth.time;
    final temps = wth.temperature.length > 24 ? wth.temperature.sublist(0, 24) : wth.temperature;
    final spots = <FlSpot>[];
    for (var i = 0; i < times.length; i++) {
      final t = temps.length > i ? temps[i] : null;
      if (t != null) spots.add(FlSpot(i.toDouble(), t));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 3;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('24h Temperature', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        _InsetCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text('${v.toInt()}°', style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20, interval: 4, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i >= 0 && i < times.length && times[i].length >= 13) return Text(times[i].substring(11, 13), style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textSecondary));
                    return const SizedBox();
                  })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (times.length - 1).toDouble(),
                minY: minY,
                maxY: maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppTheme.primary.withValues(alpha: 0.08)),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ),
      ],
    );
  }
}

class _ForecastTab extends StatelessWidget {
  final WardWeather data;
  final IconData Function(int, bool) weatherIcon;
  final VoidCallback onRefresh;

  const _ForecastTab({required this.data, required this.weatherIcon, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final daily = data.weather.daily;
    if (daily.isEmpty) return Center(child: Text('No forecast data', style: GoogleFonts.inter(fontSize: 15, color: AppTheme.textSecondary)));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      physics: const BouncingScrollPhysics(),
      itemCount: daily.length,
      itemBuilder: (_, i) {
        final d = daily[i];
        String dayLabel = d.date;
        try {
          final dt = DateFormat('yyyy-MM-dd').parse(d.date);
          dayLabel = DateFormat('EEEE').format(dt);
          if (i == 0) dayLabel = 'Today';
          else if (i == 1) dayLabel = 'Tomorrow';
        } catch (_) {}
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _InsetCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: AppTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
                  child: Icon(weatherIcon(d.weatherCode, true), color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dayLabel, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      if (d.sunrise != null && d.sunset != null)
                        Text('Sunrise ${_formatTime(d.sunrise!)} · Sunset ${_formatTime(d.sunset!)}', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${d.tempMax.toStringAsFixed(0)}° / ${d.tempMin.toStringAsFixed(0)}°', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    if (d.uvIndexMax != null) Text('UV ${d.uvIndexMax!.toStringAsFixed(1)}', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.warning)),
                    if (d.precipProbMax != null && d.precipProbMax! > 0) Text('${d.precipProbMax}% rain', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.info)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }

  String _formatTime(String iso) {
    try {
      if (iso.length >= 16) return iso.substring(11, 16);
      if (iso.length >= 5) return iso.substring(iso.length - 5);
    } catch (_) {}
    return iso;
  }
}

class _AirQualityTab extends StatelessWidget {
  final WardWeather data;
  final Color Function(int?) aqiColor;
  final VoidCallback onRefresh;

  const _AirQualityTab({required this.data, required this.aqiColor, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final aq = data.airQuality;
    final aqi = aq.currentAqi;
    final pm25 = aq.currentPm25 ?? 0;
    final pm10 = aq.currentPm10 ?? 0;
    final no2 = aq.no2.isNotEmpty ? aq.no2.first : null;
    final ozone = aq.ozone.isNotEmpty ? aq.ozone.first : null;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppTheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _InsetCard(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.air, size: 44, color: aqiColor(aqi)),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Air Quality Index', style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary)),
                      Text('${aqi ?? "--"}', style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.bold, color: aqiColor(aqi), height: 1)),
                      Text(aqi != null ? aqiLevelLabel(aqiToLevel(aqi)) : '--', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: aqiColor(aqi))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Pollutants', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            _PollutantRow(label: 'PM2.5', value: pm25, unit: 'μg/m³', color: AppTheme.primary),
            _PollutantRow(label: 'PM10', value: pm10, unit: 'μg/m³', color: AppTheme.primary),
            if (no2 != null) _PollutantRow(label: 'NO₂', value: no2, unit: 'μg/m³', color: AppTheme.warning),
            if (ozone != null) _PollutantRow(label: 'O₃', value: ozone, unit: 'μg/m³', color: AppTheme.info),
            const SizedBox(height: 24),
            _buildAqiChart(aq),
          ],
        ),
      ),
    );
  }

  Widget _buildAqiChart(WardAirQuality aq) {
    final times = aq.time.length > 24 ? aq.time.sublist(0, 24) : aq.time;
    final values = aq.usAqi.length > 24 ? aq.usAqi.sublist(0, 24) : aq.usAqi;
    final spots = <FlSpot>[];
    for (var i = 0; i < times.length; i++) {
      final v = values.length > i ? values[i] : null;
      if (v != null) spots.add(FlSpot(i.toDouble(), v.toDouble()));
    }
    if (spots.isEmpty) return const SizedBox.shrink();

    final maxVal = values.map((v) => v ?? 0).fold<int>(0, (a, b) => a > b ? a : b);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('24h AQI Trend', style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        _InsetCard(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: AppTheme.border, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28, getTitlesWidget: (v, _) => Text(v.toInt().toString(), style: GoogleFonts.inter(fontSize: 10, color: AppTheme.textSecondary)))),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 20, interval: 4, getTitlesWidget: (v, _) {
                    final i = v.toInt();
                    if (i >= 0 && i < times.length && times[i].length >= 13) return Text(times[i].substring(11, 13), style: GoogleFonts.inter(fontSize: 9, color: AppTheme.textSecondary));
                    return const SizedBox();
                  })),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: (times.length - 1).toDouble(),
                minY: 0,
                maxY: (maxVal * 1.2).clamp(50.0, 500.0),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: true, color: AppTheme.primary.withValues(alpha: 0.1)),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 250),
            ),
          ),
        ),
      ],
    );
  }
}

/// iOS inset grouped card style.
class _InsetCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _InsetCard({required this.child, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MiniKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniKpi({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return _InsetCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PollutantRow extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _PollutantRow({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _InsetCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            Text('${value.toStringAsFixed(1)} $unit', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}
