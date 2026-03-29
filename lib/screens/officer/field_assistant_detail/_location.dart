part of 'field_assistant_task_detail.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Location Section — FlutterMap, proximity indicator, distance display
// ═══════════════════════════════════════════════════════════════════════════════

extension _FADetailLocation on _FieldAssistantTaskDetailState {
  Widget _buildLocationSection(
    Complaint c,
    AttendanceState att,
    bool isAtSite,
    double dist,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'GEOTAG LOCATION',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(c.latitude, c.longitude),
                    initialZoom: 15.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.example.grievance_app',
                      retinaMode: RetinaMode.isHighDensity(context),
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(c.latitude, c.longitude),
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_map',
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.primary,
                    elevation: 4,
                    onPressed: () {
                      _mapController.move(
                        LatLng(c.latitude, c.longitude),
                        15.0,
                      );
                    },
                    child: const Icon(Icons.my_location, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.address.isNotEmpty ? c.address : 'GPS Locked',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${c.latitude.toStringAsFixed(6)}, ${c.longitude.toStringAsFixed(6)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (att.isClockedIn) _buildProximityCard(isAtSite, dist),
        const SizedBox(height: 16),
        _buildProximityRadio(),
      ],
    );
  }

  Widget _buildProximityRadio() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceScaffold,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, size: 20, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify at grievance location',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  _requireLocationAtGrievance
                      ? 'GPS required — must be within 50m'
                      : 'Location check skipped (different from shift)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _requireLocationAtGrievance,
            onChanged: (v) => _rebuildState(() => _requireLocationAtGrievance = v),
            activeTrackColor: AppTheme.primary.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildProximityCard(bool isAtSite, double dist) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isAtSite
            ? AppTheme.success.withValues(alpha: 0.06)
            : AppTheme.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isAtSite ? AppTheme.success : AppTheme.error).withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAtSite ? Icons.check_circle_rounded : Icons.gps_off_rounded,
            color: isAtSite ? AppTheme.success : AppTheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isAtSite
                  ? 'Within working range'
                  : !dist.isFinite
                      ? 'Location unavailable — turn on GPS'
                      : '${dist.toInt()}m from site — move closer',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isAtSite
                    ? const Color(0xFF065F46)
                    : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
