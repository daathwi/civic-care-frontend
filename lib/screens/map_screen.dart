import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/complaint.dart';
import '../core/app_theme.dart';
import '../providers/complaint_provider.dart';
import '../utils/responsive_utils.dart';
import 'complaint_detail/complaint_detail_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/ward_provider.dart';

/// How many grievances to request when opening the map (aligned with portal filters).
const int kMapGrievanceFetchLimit = 500;

class MapScreen extends ConsumerStatefulWidget {
  final List<Complaint>? initialComplaints;
  final LatLng? initialCenter;

  /// When set, map markers use this notifier's list (e.g. [managerGrievancesProvider] with status filters).
  /// Defaults to [complaintProvider] (citizen ward feed, worker tasks, manager dashboard list).
  final NotifierProvider<ComplaintNotifier, GrievanceState>? grievanceSourceProvider;

  /// Optional portal search (e.g. manager grievances search) — applied client-side on top of API data.
  final String? searchQuery;

  const MapScreen({
    super.key,
    this.initialComplaints,
    this.initialCenter,
    this.grievanceSourceProvider,
    this.searchQuery,
  });

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  Complaint? _selectedComplaint;
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapMapData());
  }

  /// Load grievances using the same filters as the active portal list (status, worker, reporter).
  void _bootstrapMapData() {
    if (widget.initialComplaints != null) return;
    final p = widget.grievanceSourceProvider ?? complaintProvider;
    final st = ref.read(p);
    ref.read(p.notifier).loadGrievances(
          limit: kMapGrievanceFetchLimit,
          status: st.filterStatus,
          workerId: st.filterWorkerId,
          reporterId: st.filterReporterId,
        );
  }

  List<Complaint> _filteredComplaints() {
    if (widget.initialComplaints != null) return widget.initialComplaints!;
    final p = widget.grievanceSourceProvider ?? complaintProvider;
    var list = ref.watch(p).complaints;
    final q = widget.searchQuery?.trim();
    if (q != null && q.isNotEmpty) {
      final lq = q.toLowerCase();
      list = list
          .where(
            (c) =>
                c.title.toLowerCase().contains(lq) ||
                c.description.toLowerCase().contains(lq) ||
                c.userName.toLowerCase().contains(lq),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final complaints = _filteredComplaints();
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isTablet = ResponsiveUtils.isTablet(context);

    // Watch ward details for dynamic centering
    final wardAsync = ref.watch(currentUserWardProvider);
    final ward = wardAsync.valueOrNull;
    final center = widget.initialCenter ?? ward?.centroid ?? _delhiCenter;

    // Listen for ward centroid updates to reactively move the map
    ref.listen(currentUserWardProvider, (previous, next) {
      final newWard = next.valueOrNull;
      if (newWard != null && previous?.valueOrNull?.id != newWard.id) {
        if (newWard.bounds != null) {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: newWard.bounds!,
              padding: const EdgeInsets.all(40),
            ),
          );
        } else if (newWard.centroid != null) {
          _mapController.move(newWard.centroid!, 15.0);
        }
      }
    });

    return ResponsiveLayout(
      mobile: _buildMobileLayout(context, complaints, center),
      desktop: _buildWebLayout(context, complaints, isDesktop || isTablet, center),
    );
  }

  // Delhi center (India Gate area)
  static const LatLng _delhiCenter = LatLng(28.6139, 77.2090);

  Widget _buildMobileLayout(BuildContext context, List<Complaint> complaints, LatLng center) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15.0,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.grievance_app',
            ),
            MarkerLayer(
              markers: complaints.map((complaint) {
                return Marker(
                  point: LatLng(complaint.latitude, complaint.longitude),
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _showComplaintSnippet(context, complaint),
                    child: _MapMarker(
                      category: complaint.category,
                      status: complaint.status,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Glass Header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: MediaQuery.of(context).padding.top + 64,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top,
                ),
                decoration: const BoxDecoration(color: AppTheme.primary),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: 48.0,
                          ), // Balance the back button
                          child: Text(
                            'Ward Map',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebLayout(
    BuildContext context,
    List<Complaint> complaints,
    bool showSidebarLogic,
    LatLng center,
  ) {
    final showSidebar = showSidebarLogic && _selectedComplaint != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Map Explorer',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: BackButton(color: Colors.white),
      ),
      body: Row(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.grievance_app',
                ),
                MarkerLayer(
                  markers: complaints.map((complaint) {
                    final isSelected = _selectedComplaint?.id == complaint.id;
                    return Marker(
                      point: LatLng(complaint.latitude, complaint.longitude),
                      width: isSelected ? 50 : 40,
                      height: isSelected ? 50 : 40,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedComplaint = complaint),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: _MapMarker(
                            category: complaint.category,
                            status: complaint.status,
                            isSelected: isSelected,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (showSidebar) _buildSidebar(_selectedComplaint!),
        ],
      ),
    );
  }

  Widget _buildSidebar(Complaint complaint) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Details',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _selectedComplaint = null),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sidebarItem(
                    complaint.category.icon,
                    'Category',
                    complaint.departmentDisplayName ?? complaint.category.label,
                  ),
                  const SizedBox(height: 20),
                  _sidebarItem(Icons.title_rounded, 'Title', complaint.title),
                  const SizedBox(height: 20),
                  _sidebarItem(
                    Icons.description_outlined,
                    'Description',
                    complaint.description,
                  ),
                  const SizedBox(height: 20),
                  _sidebarItem(
                    Icons.location_on_outlined,
                    'Address',
                    complaint.address,
                  ),
                  const SizedBox(height: 32),
                  _StatusPill(status: complaint.status),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ComplaintDetailScreen(complaint: complaint),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'View Full Details',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
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

  Widget _sidebarItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey[400],
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  void _showComplaintSnippet(BuildContext context, Complaint complaint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(
                      complaint.status.colorValue,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    complaint.category.icon,
                    color: Color(complaint.status.colorValue),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complaint.title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          letterSpacing: -0.3,
                          color: const Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        complaint.address,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatusPill(status: complaint.status),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ComplaintDetailScreen(complaint: complaint),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'View Details',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final ComplaintCategory category;
  final ComplaintStatus status;
  final bool isSelected;

  const _MapMarker({
    required this.category,
    required this.status,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(status.colorValue);

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: isSelected ? 40 : 32,
          height: isSelected ? 40 : 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.yellow : Colors.white,
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isSelected ? 0.6 : 0.3),
                blurRadius: isSelected ? 12 : 8,
                spreadRadius: isSelected ? 4 : 2,
              ),
            ],
          ),
        ),
        Icon(category.icon, color: Colors.white, size: isSelected ? 20 : 16),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ComplaintStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = Color(status.colorValue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
