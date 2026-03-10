import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/responsive_utils.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: Scaffold(
        appBar: AppBar(title: const Text("FAQ's")),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [_buildContentColumn(context)],
        ),
      ),
      desktop: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: _buildContentColumn(context, isWeb: true),
          ),
        ),
      ),
    );
  }

  Widget _buildContentColumn(BuildContext context, {bool isWeb = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isWeb) ...[
          Text(
            "Frequently Asked Questions",
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Everything you need to know about CivicCare and reporting issues.",
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 48),
        ],
        _buildCategoryHeader('General & Account'),
        _buildFAQ(
          context,
          'What is this app for?',
          'It is an official platform for Delhi citizens to report civic grievances (like potholes, waste, or streetlights) directly to the MCD and track their resolution in real-time.',
          isWeb: isWeb,
        ),
        _buildFAQ(
          context,
          'Do I need to live in Delhi to use this?',
          'Anyone can report an issue they see within the MCD\'s jurisdiction. However, you must specify your primary "Ward" in your profile to see relevant community updates.',
          isWeb: isWeb,
        ),
        const SizedBox(height: 24),
        _buildCategoryHeader('Reporting a Complaint'),
        _buildFAQ(
          context,
          'Why can\'t I upload a photo from my gallery?',
          'To ensure the authenticity and accuracy of every report, we require a live, time-stamped photo captured through the app\'s camera. This prevents the submission of outdated or duplicate photos.',
          isWeb: isWeb,
        ),
        _buildFAQ(
          context,
          'Does the app track my location?',
          'The app only accesses your GPS location when you are filing a report. This is necessary to automatically tag the exact spot of the grievance so MCD officials can find it easily.',
          isWeb: isWeb,
        ),
        _buildFAQ(
          context,
          'Can I report issues outside of my registered Ward?',
          'Yes! You can report any issue you see across Delhi. The app will automatically detect the ward based on your GPS coordinates.',
          isWeb: isWeb,
        ),
        const SizedBox(height: 24),
        _buildCategoryHeader('Tracking & Resolution'),
        _buildStatusFAQ(context, isWeb: isWeb),
        _buildFAQ(
          context,
          'How long will it take to fix my issue?',
          'Resolution times vary by category. For example, sanitation issues are typically addressed within 24-48 hours, while structural road repairs may take longer. You can see the "Estimated Resolution Time" on your complaint dashboard.',
          isWeb: isWeb,
        ),
        _buildFAQ(
          context,
          'What if my complaint is marked "Resolved" but the issue still exists?',
          'You can use the "Re-open" or "Comment" feature on the complaint to provide feedback. You can also upload a new photo showing the current status.',
          isWeb: isWeb,
        ),
        const SizedBox(height: 24),
        _buildCategoryHeader('Community & Impact'),
        _buildFAQ(
          context,
          'What does "Upvoting" a complaint do?',
          'Upvoting signals to the MCD that an issue is affecting many people. Complaints with high upvote counts are moved to the "High Priority" list on the department\'s dashboard.',
          isWeb: isWeb,
        ),
        _buildFAQ(
          context,
          'Who can see my comments?',
          'Comments are public to all users within that Ward. Please keep discussions focused on the civic issue at hand.',
          isWeb: isWeb,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppTheme.primary,
        ),
      ),
    );
  }

  Widget _buildFAQ(
    BuildContext context,
    String question,
    String answer, {
    bool isWeb = false,
  }) {
    if (isWeb) {
      return Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(vertical: 8),
              title: Text(
                question,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: const Color(0xFF111827),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    answer,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: const TextStyle(color: Color(0xFF666666), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFAQ(BuildContext context, {bool isWeb = false}) {
    if (isWeb) {
      return Column(
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(vertical: 8),
              title: Text(
                'What do the status colors mean?',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: const Color(0xFF111827),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    children: [
                      _buildStatusRow(
                        Colors.red,
                        'Red (Unassigned)',
                        'Your complaint is logged and waiting for an officer to be assigned.',
                        isWeb: isWeb,
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        Colors.orange,
                        'Amber (Ongoing)',
                        'An officer has been assigned and work is currently in progress.',
                        isWeb: isWeb,
                      ),
                      const SizedBox(height: 12),
                      _buildStatusRow(
                        Colors.green,
                        'Green (Completed)',
                        'The issue has been resolved and verified.',
                        isWeb: isWeb,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      );
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        title: const Text(
          'What do the status colors mean?',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              children: [
                _buildStatusRow(
                  Colors.red,
                  'Red (Unassigned)',
                  'Your complaint is logged and waiting for an officer to be assigned.',
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  Colors.orange,
                  'Amber (Ongoing)',
                  'An officer has been assigned and work is currently in progress.',
                ),
                const SizedBox(height: 8),
                _buildStatusRow(
                  Colors.green,
                  'Green (Completed)',
                  'The issue has been resolved and verified.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(
    Color color,
    String title,
    String description, {
    bool isWeb = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isWeb ? 15 : 14,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: isWeb ? 14 : 13,
                  color: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
