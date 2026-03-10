import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/responsive_utils.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: Scaffold(
        appBar: AppBar(title: const Text('Contact Us')),
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
      children: [
        Icon(
          Icons.support_agent_rounded,
          size: isWeb ? 80 : 64,
          color: AppTheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'We\'re Here to Help',
          style: GoogleFonts.outfit(
            fontSize: isWeb ? 36 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Text(
            'Have questions or feedback? Reach out to us through any of the channels below.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF6B7280),
              fontSize: isWeb ? 16 : 14,
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 48),
        if (isWeb)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            shrinkWrap: true,
            childAspectRatio: 2.2,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildContactMethod(
                Icons.phone_rounded,
                'Phone',
                '+91 9652839050',
                'Mon-Sat • 9AM - 6PM',
                isWeb: true,
              ),
              _buildContactMethod(
                Icons.email_rounded,
                'Email',
                'daathwi.031@gmail.com',
                'Expect a reply within 24 hours',
                isWeb: true,
              ),
              _buildContactMethod(
                Icons.code_rounded,
                'GitHub',
                'github.com/daathwi',
                'Report bugs or contribute code',
                isWeb: true,
              ),
              _buildContactMethod(
                Icons.business_center_rounded,
                'LinkedIn',
                'linkedin.com/in/daathwi/',
                'Professional networking & updates',
                isWeb: true,
              ),
            ],
          )
        else ...[
          _buildContactMethod(
            Icons.phone_rounded,
            'Phone',
            '+91 9652839050',
            'Mon-Sat • 9AM - 6PM',
          ),
          _buildContactMethod(
            Icons.email_rounded,
            'Email',
            'daathwi.031@gmail.com',
            'Expect a reply within 24 hours',
          ),
          _buildContactMethod(
            Icons.code_rounded,
            'GitHub',
            'github.com/daathwi',
            'Report bugs or contribute code',
          ),
          _buildContactMethod(
            Icons.business_center_rounded,
            'LinkedIn',
            'linkedin.com/in/daathwi/',
            'Professional networking & updates',
          ),
        ],
      ],
    );
  }

  Widget _buildContactMethod(
    IconData icon,
    String title,
    String value,
    String subtitle, {
    bool isWeb = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isWeb ? 0 : 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isWeb ? 17 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: Color(0xFFD1D5DB),
          ),
        ],
      ),
    );
  }
}
