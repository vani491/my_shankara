import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title:  Text('Privacy Policy',  style: tt.titleLarge),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──

              const SizedBox(height: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Last updated: August 2026',
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Welcome to MyShankara. MyShankara is committed to respecting and '
                    'protecting your privacy. This Privacy Policy explains how we '
                    'collect, use, and safeguard your information when you use the '
                    'MyShankara mobile application and related services.\n\n'
                    'By using MyShankara, you agree to the practices described in this '
                    'Privacy Policy.',
                style: tt.bodyMedium?.copyWith(
                  height: 1.6,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),

              _Section(
                number: '1',
                title: 'Information We Collect',
                children: [
                  _para(context,
                      'Depending on how you use MyShankara, we may collect the '
                          'following information:'),
                  _subhead(context, 'Account Information'),
                  _bullets(context, const [
                    'Full name',
                    'Preferred name',
                    'Gender',
                    'Year of birth',
                    'Email address',
                  ]),
                  _subhead(context, 'Subscription Information'),
                  _bullets(context, const [
                    'Membership status',
                    'Subscription renewal information',
                    'App Store or Google Play subscription identifiers',
                  ]),
                  _para(context,
                      'Payment information is securely managed by Apple App Store '
                          'or Google Play Store. MyShankara does not store payment card '
                          'details.'),
                  _subhead(context, 'Usage Information'),
                  _para(context,
                      'We may collect limited information about how users interact '
                          'with the app, including:'),
                  _bullets(context, const [
                    'Feature usage',
                    'App activity',
                    'Device type',
                    'App performance and diagnostics',
                  ]),
                  _subhead(context, 'Guru Chat Interactions'),
                  _para(context,
                      'Messages shared in Guru Chat may be processed to generate '
                          'AI-based responses and improve the user experience.\n\n'
                          'Users should not share highly sensitive or confidential '
                          'information through Guru Chat, including passwords, financial '
                          'information, government identifiers, medical records, legal '
                          'matters, or other sensitive personal data.\n\n'
                          'While MyShankara takes reasonable measures to protect user '
                          'information, no digital platform or AI system can guarantee '
                          'absolute confidentiality or security.'),
                ],
              ),

              _Section(
                number: '2',
                title: 'How We Use Information',
                children: [
                  _para(context, 'We use information to:'),
                  _bullets(context, const [
                    'Provide and improve MyShankara services',
                    'Personalize your experience',
                    'Deliver Daily Darshan and Guru Chat features',
                    'Manage memberships and subscriptions',
                    'Send reminders and notifications',
                    'Respond to support requests',
                    'Improve app stability, performance, and user experience',
                  ]),
                ],
              ),

              _Section(
                number: '3',
                title: 'Guru Chat & AI Guidance',
                children: [
                  _para(context,
                      'Guru Chat responses are AI-generated and intended for '
                          'spiritual reflection, self-inquiry, educational, and general '
                          'informational purposes only.\n\n'
                          'MyShankara is not a substitute for:'),
                  _bullets(context, const [
                    'Medical advice',
                    'Mental health care',
                    'Legal advice',
                    'Financial advice',
                    'Emergency services',
                  ]),
                  _para(context,
                      'Users should exercise personal judgment, discretion, and '
                          'caution when relying on guidance or responses provided '
                          'through MyShankara.'),
                ],
              ),

              _Section(
                number: '4',
                title: 'Subscriptions & Payments',
                children: [
                  _para(context,
                      'Membership subscriptions are managed securely through:'),
                  _bullets(context, const [
                    'Apple App Store',
                    'Google Play Store',
                  ]),
                  _para(context,
                      'Subscription billing, renewals, cancellations, refunds, and '
                          'payment methods are handled by Apple App Store or Google Play '
                          'Store according to their respective policies.'),
                ],
              ),

              _Section(
                number: '5',
                title: 'Notifications',
                children: [
                  _para(context,
                      'If enabled, MyShankara may send notifications related to:'),
                  _bullets(context, const [
                    'Daily Darshan reminders',
                    'App updates',
                    'Important account or subscription information',
                  ]),
                  _para(context,
                      'Users can manage notification preferences within device '
                          'settings or app settings.'),
                ],
              ),

              _Section(
                number: '6',
                title: 'Data Sharing',
                children: [
                  _para(context,
                      'MyShankara does not sell or rent personal information to '
                          'advertisers, data brokers, or third parties.\n\n'
                          'We may share limited information with trusted service '
                          'providers who support app operations, including:'),
                  _bullets(context, const [
                    'Authentication services',
                    'Analytics providers',
                    'Cloud infrastructure providers',
                    'Subscription and payment platforms',
                  ]),
                  _para(context,
                      'These providers are expected to handle information securely '
                          'and only for authorized purposes.'),
                ],
              ),

              _Section(
                number: '7',
                title: 'Data Security',
                children: [
                  _para(context,
                      'We take reasonable technical and organizational measures to '
                          'help protect user information from unauthorized access, '
                          'misuse, or disclosure.\n\n'
                          'However, no system can guarantee absolute security.\n\n'
                          'Users are responsible for maintaining the security of their '
                          'own devices, accounts, and login credentials.'),
                ],
              ),

              _Section(
                number: '8',
                title: 'Data Retention',
                children: [
                  _para(context,
                      'We retain information only as long as reasonably necessary '
                          'to:'),
                  _bullets(context, const [
                    'Provide services',
                    'Comply with legal obligations',
                    'Resolve disputes',
                    'Maintain app functionality and security',
                  ]),
                ],
              ),

              _Section(
                number: '9',
                title: "Children's Privacy",
                children: [
                  _para(context,
                      'MyShankara is not intended for children under the age '
                          'required by applicable laws in their region to use digital '
                          'services independently.\n\n'
                          'If we become aware that personal information has been '
                          'collected from a child without appropriate consent, we may '
                          'delete such information.'),
                ],
              ),

              _Section(
                number: '10',
                title: 'Third-Party Services',
                children: [
                  _para(context,
                      'MyShankara may contain links to or integrations with '
                          'third-party services, including:'),
                  _bullets(context, const [
                    'Apple App Store',
                    'Google Play Store',
                    'Authentication providers',
                    'Analytics services',
                  ]),
                  _para(context,
                      'Use of those services may be governed by their own privacy '
                          'policies and terms.'),
                ],
              ),

              _Section(
                number: '11',
                title: 'Changes to This Privacy Policy',
                children: [
                  _para(context,
                      'We may update this Privacy Policy from time to time.\n\n'
                          'Updated versions will be published within the app and '
                          'reflected by the "Last Updated" date above.\n\n'
                          'Continued use of MyShankara after updates constitutes '
                          'acceptance of the revised policy.'),
                ],
              ),

              _Section(
                number: '12',
                title: 'Contact Us',
                children: [
                  _para(context,
                      'For privacy-related questions or concerns, please contact:'),
                  _para(context, 'support@myshankara.ai'),
                  _para(context,
                      'Users may request account deletion by contacting '
                          'support@myshankara.ai.'),
                ],
              ),

              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Thank you for being part of MyShankara.',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '© 2026 MyShankara. All rights reserved.',
                  style: tt.bodySmall?.copyWith(
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

  // ── Helpers ──
  static Widget _para(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.6,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  static Widget _subhead(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }

  static Widget _bullets(BuildContext context, List<String> items) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items
            .map(
              (t) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7, right: 10),
                  child: Icon(Icons.brightness_1,
                      size: 6, color: cs.secondary),
                ),
                Expanded(
                  child: Text(
                    t,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: cs.onSurface.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String number;
  final String title;
  final List<Widget> children;
  const _Section({
    required this.number,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  number,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.primary,

                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    fontSize: 18
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}