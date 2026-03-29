import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_theme.dart';
import '../models/ward.dart';
import '../providers/auth_provider.dart';
import '../providers/ward_provider.dart';
import '../utils/responsive_utils.dart';

/// Council Directory — matches app `ThemeData` + [AppTheme] (teal, Outfit headers, 24px cards).
class CouncilDirectoryScreen extends ConsumerWidget {
  const CouncilDirectoryScreen({super.key});

  static const LatLng _delhiFallback = LatLng(28.6139, 77.2090);
  static const double _horizontalPad = 20;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardAsync = ref.watch(currentUserWardProvider);
    final user = ref.watch(authProvider).user;

    return ResponsiveLayout(
      mobile: Scaffold(
        appBar: AppBar(
          title: const Text('Council Directory'),
        ),
        body: _body(
          context,
          ref,
          wardAsync,
          user?.wardId,
          scrollable: true,
        ),
      ),
      desktop: ColoredBox(
        color: AppTheme.surfaceScaffold,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Council Directory',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your ward, elected representative, and department heads.',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.35,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _body(
                    context,
                    ref,
                    wardAsync,
                    user?.wardId,
                    scrollable: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Ward?> wardAsync,
    String? wardId, {
    required bool scrollable,
  }) {
    if (wardAsync.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (wardId == null || wardId.isEmpty) {
      return _noWardState(context);
    }

    final ward = wardAsync.valueOrNull;
    if (ward == null) {
      return _noWardState(context);
    }

    final managersAsync = ref.watch(fieldManagersForWardProvider(ward.id));

    final content = <Widget>[
      _sectionHeader('WARD'),
      const SizedBox(height: 8),
      _themedCard(
        children: [
          _kvRow(label: 'Ward name', value: ward.name),
          _hairlineDivider(),
          _kvRow(label: 'Ward number', value: '${ward.number}'),
          if (ward.zoneName != null && ward.zoneName!.isNotEmpty) ...[
            _hairlineDivider(),
            _kvRow(label: 'Zone', value: ward.zoneName!),
          ],
        ],
      ),
      const SizedBox(height: 24),
      _sectionHeader('MAP'),
      const SizedBox(height: 8),
      _themedCard(
        child: _wardMap(ward),
      ),
      const SizedBox(height: 24),
      _sectionHeader('ELECTED REPRESENTATIVE'),
      const SizedBox(height: 8),
      _themedCard(
        children: [
          _kvRow(label: 'Councillor', value: ward.representativeName ?? '—'),
          _hairlineDivider(),
          _kvRow(
            label: 'Phone',
            value: ward.representativePhone.isEmpty
                ? '—'
                : ward.representativePhone.join(' · '),
            accent: ward.representativePhone.isNotEmpty,
            onTapValue: ward.representativePhone.isNotEmpty
                ? () => _launchTel(ward.representativePhone.first)
                : null,
          ),
          _hairlineDivider(),
          _kvRow(
            label: 'Email',
            value: (ward.representativeEmail != null &&
                    ward.representativeEmail!.trim().isNotEmpty)
                ? ward.representativeEmail!.trim()
                : '—',
            accent: ward.representativeEmail != null &&
                ward.representativeEmail!.trim().isNotEmpty,
            onTapValue: ward.representativeEmail != null &&
                    ward.representativeEmail!.trim().isNotEmpty
                ? () => _launchMail(ward.representativeEmail!.trim())
                : null,
          ),
          _hairlineDivider(),
          _kvRow(
            label: 'Party',
            value: (ward.representativeParty != null &&
                    ward.representativeParty!.trim().isNotEmpty)
                ? ward.representativeParty!.trim()
                : '—',
          ),
        ],
      ),
      const SizedBox(height: 24),
      _sectionHeader('FIELD MANAGERS'),
      const SizedBox(height: 6),
      Text(
        'Department heads assigned to your ward.',
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.35,
          color: AppTheme.textSecondary,
        ),
      ),
      const SizedBox(height: 12),
      managersAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return _footnote(
              'No field manager contacts are on file for this ward yet.',
            );
          }
          return Column(
            children: list
                .map(
                  (m) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _managerCard(m),
                  ),
                )
                .toList(),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(
            child: CircularProgressIndicator(color: AppTheme.primary),
          ),
        ),
        error: (_, __) => _footnote(
          'Could not load contacts. Pull to retry.',
        ),
      ),
      const SizedBox(height: 24),
    ];

    if (!scrollable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content,
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(currentUserWardProvider);
        ref.invalidate(fieldManagersForWardProvider(ward.id));
        await ref.read(currentUserWardProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(_horizontalPad, 8, _horizontalPad, 24),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: content,
      ),
    );
  }

  /// Same pattern as [DashboardScreen] section titles.
  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Colors.grey[500],
      ),
    );
  }

  /// Uses [AppTheme.cardDecoration] like dashboard / feed cards.
  Widget _themedCard({
    List<Widget>? children,
    Widget? child,
  }) {
    assert(children != null || child != null);
    final inner = child ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children!,
        );
    return Container(
      decoration: AppTheme.cardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: inner,
    );
  }

  Widget _hairlineDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppTheme.border,
      ),
    );
  }

  Widget _kvRow({
    required String label,
    required String value,
    bool accent = false,
    VoidCallback? onTapValue,
  }) {
    final valueStyle = GoogleFonts.inter(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w500,
      color: accent ? AppTheme.primary : AppTheme.textPrimary,
    );

    Widget valueWidget = Text(
      value,
      textAlign: TextAlign.end,
      style: valueStyle,
    );

    if (onTapValue != null) {
      valueWidget = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapValue,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: valueStyle,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.primary.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 16,
                height: 1.3,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: valueWidget,
          ),
        ],
      ),
    );
  }

  Widget _wardMap(Ward ward) {
    final center = ward.centroid ?? _delhiFallback;
    final zoom = ward.bounds != null ? 14.0 : 13.0;
    return SizedBox(
      height: 200,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
        ),
        children: [
          TileLayer(
            urlTemplate:
                'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.example.grievance_app',
          ),
          if (ward.centroid != null)
            MarkerLayer(
              markers: [
                Marker(
                  width: 40,
                  height: 40,
                  point: ward.centroid!,
                  child: Icon(
                    Icons.location_on_rounded,
                    color: AppTheme.primary,
                    size: 40,
                    shadows: const [
                      Shadow(
                        color: Colors.white,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _managerCard(Map<String, dynamic> m) {
    final name = (m['name'] as String?) ?? '—';
    final dept = (m['department_name'] as String?) ?? '';
    final designation = (m['designation'] as String?) ?? '';
    final phone = (m['phone'] as String?) ?? '';
    final email = (m['email'] as String?) ?? '';

    final rows = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
              ),
              child: Icon(
                Icons.person_rounded,
                color: AppTheme.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (designation.isNotEmpty)
                    Text(
                      designation,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];

    if (dept.isNotEmpty) {
      rows.add(_hairlineDivider());
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.business_rounded,
                size: 20,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  dept,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (phone.isNotEmpty) {
      rows.add(_hairlineDivider());
      rows.add(_contactRow(
        icon: Icons.phone_rounded,
        text: phone,
        onTap: () => _launchTel(phone),
      ));
    }
    if (email.isNotEmpty) {
      rows.add(_hairlineDivider());
      rows.add(_contactRow(
        icon: Icons.mail_outline_rounded,
        text: email,
        onTap: () => _launchMail(email),
      ));
    }

    return _themedCard(children: rows);
  }

  Widget _contactRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footnote(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 13,
          height: 1.4,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _noWardState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.cardDecoration(),
            child: Icon(
              Icons.location_off_rounded,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ward not set',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add or confirm your ward under My Account so we can show your council directory.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.45,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchTel(String raw) async {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: digits);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchMail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}
