import 'package:flutter/material.dart';
class PrivacyTermsPage extends StatelessWidget {
  const PrivacyTermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Privacy & Terms'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Privacy Policy & Terms of Service',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Last updated: June 2026',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),

              _Section(
                title: '1. Introduction',
                body:
                'Welcome to MyShankara. We are committed to protecting your '
                    'privacy and providing a safe, meaningful experience. This page '
                    'explains how we collect, use, and safeguard your information, '
                    'and the terms under which you use our app.',
              ),
              _Section(
                title: '2. Information We Collect',
                body:
                'We collect information you provide directly, such as your name, '
                    'preferred name, year of birth, and gender, to personalise your '
                    'experience. We also collect usage data such as your daily '
                    'reflections and activity within the app to help you track your journey.',
              ),
              _Section(
                title: '3. How We Use Your Information',
                body:
                'Your information is used to personalise content, deliver daily '
                    'reflections and notifications, maintain your profile, and improve '
                    'our services. We do not sell your personal data to third parties.',
              ),
              _Section(
                title: '4. Data Storage & Security',
                body:
                'Your data is stored securely using industry-standard practices. '
                    'We take reasonable measures to protect your information from '
                    'unauthorised access, alteration, or disclosure.',
              ),
              _Section(
                title: '5. Notifications',
                body:
                'With your permission, we send daily reminders at a time you choose. '
                    'You can enable, disable, or reschedule these at any time from the '
                    'Settings screen.',
              ),
              _Section(
                title: '6. Your Rights',
                body:
                'You may view, edit, or delete your profile information at any time '
                    'through the app. You can also request deletion of your account and '
                    'associated data by contacting our support team.',
              ),
              _Section(
                title: '7. Eligibility',
                body:
                'MyShankara is intended for seekers aged 18 and above. By using the '
                    'app, you confirm that you meet this age requirement.',
              ),
              _Section(
                title: '8. Changes to This Policy',
                body:
                'We may update this policy from time to time. Any changes will be '
                    'reflected on this page with an updated revision date. Continued use '
                    'of the app constitutes acceptance of the revised terms.',
              ),
              _Section(
                title: '9. Contact Us',
                body:
                'If you have questions about this policy or your data, please reach '
                    'out to us at support@myshankara.ai.',
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  '© 2026 MyShankara. All rights reserved.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}