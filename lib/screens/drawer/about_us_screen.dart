import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/app_logo.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: Scaffold(
        appBar: AppBar(title: const Text('About Us')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: _buildContentColumn(),
        ),
      ),
      desktop: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _buildContentColumn(isWeb: true),
          ),
        ),
      ),
    );
  }

  Widget _buildContentColumn({bool isWeb = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: AppLogo(
            size: isWeb ? 80 : 64,
            showLabel: true,
            subtitle: 'Empowering Delhi, One Ward at a Time',
          ),
        ),
        const SizedBox(height: 32),
        _buildSection(
          'Our Vision',
          'By the People, For the Ward. This app was born out of a simple idea: that your neighborhood belongs to you. We have created a digital bridge between the citizens of Delhi and the Municipal Corporation of Delhi (MCD), ensuring that every voice is heard and every street is accounted for.',
          isWeb: isWeb,
        ),
        _buildSection(
          'An Official Partnership for Progress',
          'We are proud to be an official partner of the MCD. This collaboration means your reports don\'t just sit on a server \u2014 they are routed directly to the relevant department\'s dashboard. By integrating our smart tracking technology with MCD\'s ground-level operations, we are slashing resolution times and bringing a new era of transparency to Delhi\'s governance.',
          isWeb: isWeb,
        ),
        _buildSection(
          'Strength in Numbers',
          'Your upvote matters. In a city of millions, prioritization is key. When a community speaks together on a single issue, it moves from a complaint to a Top Priority. This collective action helps the MCD identify which infrastructure needs immediate attention, ensuring public funds are used where they are needed most.',
          isWeb: isWeb,
        ),
        _buildSection(
          'Our Promise: Transparency at Every Step',
          'We believe accountability is built through information. From the moment you capture a live photo of a grievance to the second an MCD official updates the status to Green, you will be notified. No more following up at offices; your phone is now your direct line to a better Delhi.',
          isWeb: isWeb,
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 24),
        Text(
          'Key Highlights',
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildHighlight(
          Icons.send_rounded,
          'Direct to MCD',
          'Every verified report is a logged ticket in the Municipal Corporation\'s system.',
        ),
        _buildHighlight(
          Icons.camera_alt_rounded,
          'Verified Authenticity',
          'Our Live Camera Only system ensures that every report is real, current, and geographically accurate.',
        ),
        _buildHighlight(
          Icons.analytics_rounded,
          'Data-Driven Governance',
          'We use advanced analytics to help the MCD identify recurring hotspots and plan long-term infrastructure improvements.',
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSection(String title, String content, {bool isWeb = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isWeb ? 40.0 : 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: isWeb ? 22 : 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: isWeb ? 16 : 15,
              color: const Color(0xFF666666),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlight(IconData icon, String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
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
