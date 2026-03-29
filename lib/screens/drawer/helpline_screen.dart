import 'package:flutter/material.dart';
import '../../utils/launch_links.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/responsive_utils.dart';

class HelplineScreen extends StatelessWidget {
  const HelplineScreen({super.key});

  final List<Map<String, String>> helplines = const [
    {'name': 'MCD Call Center', 'number': '155305'},
    {'name': 'Anti Corruption', 'number': '011 2735 7169'},
    {'name': 'Fire', 'number': '101'},
    {'name': 'Police', 'number': '100'},
    {'name': 'Ambulance', 'number': '108'},
    {'name': 'Control Room Civic Centre', 'number': '011 2322 0016'},
    {'name': 'Central Flood Control Room', 'number': '011 2205 1234'},
    {'name': 'Central Water Commissioner', 'number': '011 2685 8452'},
    {'name': 'Flood Control Room', 'number': '011 2386 8775'},
    {
      'name': 'Civil Defence Control Room',
      'number': '011 2323 8001 / 011 2322 1620',
    },
    {
      'name': 'Delhi Disaster Management Authority',
      'number': '011 2337 0426 / 1077',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: Scaffold(
        appBar: AppBar(title: const Text('MCD Helpline')),
        body: RefreshIndicator(
          onRefresh: () async {
            // Static list, but keeps UI consistent
            await Future.delayed(const Duration(milliseconds: 800));
          },
          color: AppTheme.primary,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            itemCount: helplines.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => _helplineItem(helplines[index]),
          ),
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
        Text(
          'Emergency & Government Helplines',
          style: GoogleFonts.outfit(
            fontSize: isWeb ? 32 : 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Important contact numbers for civic services and emergencies across the capital.',
          style: TextStyle(
            fontSize: isWeb ? 16 : 13,
            color: const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 48),
        if (isWeb)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            childAspectRatio: 2.8,
            physics: const NeverScrollableScrollPhysics(),
            children: helplines
                .map((h) => _helplineItem(h, isWeb: true))
                .toList(),
          )
        else
          ...helplines.map((h) => _helplineItem(h)),
      ],
    );
  }

  Widget _helplineItem(Map<String, String> helpline, {bool isWeb = false}) {
    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 0 : 12),
      padding: EdgeInsets.symmetric(
        horizontal: isWeb ? 24 : 20,
        vertical: isWeb ? 20 : 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_in_talk_rounded,
              color: Colors.red,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  helpline['name']!,
                  style: GoogleFonts.outfit(
                    fontSize: isWeb ? 17 : 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  helpline['number']!,
                  style: GoogleFonts.inter(
                    fontSize: isWeb ? 18 : 16,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_rounded, color: AppTheme.primary),
            onPressed: () => launchPhoneDialer(helpline['number']),
            tooltip: 'Call',
          ),
        ],
      ),
    );
  }
}
