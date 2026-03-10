import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/app_theme.dart';
import '../utils/responsive_utils.dart';
import 'app_logo.dart';


// ── Data models ──────────────────────────────────────────────────────────────

class AdaptiveDestination {
  final String label;
  final IconData icon;
  final IconData? selectedIcon;

  const AdaptiveDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
  });
}

class SidebarFooterItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const SidebarFooterItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

// ── AdaptiveScaffold ─────────────────────────────────────────────────────────

class AdaptiveScaffold extends StatelessWidget {
  final String title;
  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  // Mobile-specific
  final Widget? mobileDrawer;
  final Widget? mobileBottomNavigationBar;

  // Desktop sidebar additions
  final String userName;
  final String userRole;
  final VoidCallback? onProfileTap;
  final List<SidebarFooterItem> footerItems;
  final VoidCallback? onLogout;
  final VoidCallback? onReportIssue;
  final bool useMobileAppBar;

  const AdaptiveScaffold({
    super.key,
    required this.title,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.mobileDrawer,
    this.mobileBottomNavigationBar,
    this.userName = '',
    this.userRole = 'CITIZEN PORTAL',
    this.onProfileTap,
    this.footerItems = const [],
    this.onLogout,
    this.onReportIssue,
    this.useMobileAppBar = true,
  });

  // Use AppTheme for CivicConnect parity (sidebar, nav, buttons)

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileScaffold(context),
      tablet: _buildDesktopScaffold(context),
      desktop: _buildDesktopScaffold(context),
    );
  }

  // ── Mobile — unchanged ──────────────────────────────────────────────────

  Widget _buildMobileScaffold(BuildContext context) {
    return Scaffold(
      appBar: useMobileAppBar
          ? AppBar(
              backgroundColor: AppTheme.surfaceScaffold,
              scrolledUnderElevation: 0,
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.black87),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              ),
              title: Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  fontSize: 18,
                ),
              ),
            )
          : null,
      drawer: mobileDrawer,
      body: SafeArea(
        top: !useMobileAppBar,
        bottom: false,
        child: Stack(
          children: [
            body,
            Positioned(
              left: 12,
              right: 12,
              bottom: 24,
              child: _buildGlassFloatingBottomBar(),
            ),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }

  Widget _buildGlassFloatingBottomBar() {
    return AppTheme.glass(
      blur: 30,
      color: Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: destinations.asMap().entries.map((entry) {
            final index = entry.key;
            final dest = entry.value;
            final isSelected = index == selectedIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onDestinationSelected(index);
                },
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected
                              ? (dest.selectedIcon ?? dest.icon)
                              : dest.icon,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            dest.label,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Desktop — full sidebar ──────────────────────────────────────────────

  Widget _buildDesktopScaffold(BuildContext context) {
    final isWide = ResponsiveUtils.isDesktop(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceScaffold,
      body: Row(
        children: [
          // Frosted Sidebar container
          AppTheme.glass(
            blur: 40,
            color: Colors.white.withValues(alpha: 0.7),
            child: _buildSidebar(context, isWide),
          ),
          Container(
            width: 1,
            color: Colors.black.withValues(alpha: 0.05), // subtle separator
          ),
          Expanded(
            child: Column(
              children: [
                _buildDesktopAppBar(context),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
    );
  }

  // ── Sidebar ─────────────────────────────────────────────────────────────

  Widget _buildSidebar(BuildContext context, bool isWide) {
    return Container(
      width: isWide ? 260 : 72,
      color: Colors.transparent, // Let glass show through
      child: Column(
        children: [
          // ── Brand header ──
          _buildBrandHeader(isWide),

          const SizedBox(height: 8),

          // ── Profile section ──
          if (userName.isNotEmpty) _buildProfileSection(isWide),

          const Divider(height: 24, indent: 16, endIndent: 16),

          // ── Main navigation ──
          ...destinations.asMap().entries.map(
            (entry) => _buildNavItem(context, entry.value, entry.key, isWide),
          ),

          const Spacer(),

          // ── Footer items (About, FAQs, etc.) ──
          if (footerItems.isNotEmpty) ...[
            const Divider(indent: 16, endIndent: 16),
            const SizedBox(height: 4),
            ...footerItems.map((item) => _buildFooterItem(item, isWide)),
            const SizedBox(height: 8),
          ],

          // ── Logout ──
          if (onLogout != null) ...[
            const Divider(indent: 16, endIndent: 16),
            _buildLogoutButton(isWide),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(bool isWide) {
    return Container(
      padding: EdgeInsets.fromLTRB(isWide ? 20 : 12, 32, isWide ? 20 : 12, 16),
      child: Column(
        children: [
          const AppLogo(size: 40, showLabel: false),
          if (isWide) ...[
            const SizedBox(height: 12),
            Text(
              'CivicCare',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              userRole,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileSection(bool isWide) {
    return InkWell(
      onTap: onProfileTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 16 : 8, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: isWide ? 18 : 16,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: isWide ? 14 : 12,
                ),
              ),
            ),
            if (isWide) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'View Profile',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    AdaptiveDestination dest,
    int index,
    bool isWide,
  ) {
    final isSelected = index == selectedIndex;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 8, vertical: 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.fastOutSlowIn,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.black.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => onDestinationSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 14 : 0,
              vertical: 12,
            ),
            child: Row(
              mainAxisAlignment: isWide
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? (dest.selectedIcon ?? dest.icon) : dest.icon,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  size: 22,
                ),
                if (isWide) ...[
                  const SizedBox(width: 14),
                  Text(
                    dest.label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterItem(SidebarFooterItem item, bool isWide) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 8, vertical: 1),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 14 : 0,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: isWide
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 18, color: Colors.grey[500]),
              if (isWide) ...[
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isWide) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 8, vertical: 4),
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 14 : 0,
            vertical: 10,
          ),
          child: Row(
            mainAxisAlignment: isWide
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 18,
                color: Colors.redAccent,
              ),
              if (isWide) ...[
                const SizedBox(width: 14),
                Text(
                  'Logout',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Desktop top bar ─────────────────────────────────────────────────────

  Widget _buildDesktopAppBar(BuildContext context) {
    return AppTheme.glass(
      blur: 20,
      color: Colors.white.withValues(alpha: 0.8),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
          ),
        ),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),

            if (onReportIssue != null) ...[
              ElevatedButton.icon(
                onPressed: onReportIssue,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: Text(
                  'REPORT ISSUE',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
              ),
              const SizedBox(width: 24),
            ],
            if (onProfileTap != null)
              userName.isNotEmpty
                  ? InkWell(
                      onTap: onProfileTap,
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppTheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              child: Text(
                                userName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              userName,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.person_outline, color: AppTheme.primary),
                      onPressed: onProfileTap,
                      tooltip: 'My profile',
                    ),
          ],
        ),
      ),
    );
  }
}
