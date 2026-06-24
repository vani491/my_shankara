import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title:  Text('Terms of Service',  style: tt.titleLarge),
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
                'Welcome to MyShankara. These Terms of Service ("Terms") govern '
                    'your access to and use of the MyShankara mobile application and '
                    'related services ("MyShankara," "we," "our," or "us").\n\n'
                    'By using MyShankara, you agree to these Terms. If you do not agree, '
                    'please do not use the app.',
                style: tt.bodyMedium?.copyWith(
                  height: 1.6,
                  color: cs.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),

              _Section(
                number: '1',
                title: 'Purpose of MyShankara',
                children: [
                  _para(context,
                      'MyShankara is a spiritual reflection and guidance platform '
                          'rooted in the wisdom traditions of Sanatana Dharma and '
                          'inspired by the teachings of Adi Shankaracharya.\n\n'
                          'The app is intended to support:'),
                  _bullets(context, const [
                    'Reflection',
                    'Self-inquiry',
                    'Spiritual learning',
                    'Daily contemplative practice',
                  ]),
                  _para(context,
                      'MyShankara is intended for reflective and educational '
                          'purposes only.\n\n'
                          'MyShankara is not intended to replace living teachers, '
                          'professional advice, or emergency services.'),
                ],
              ),

              _Section(
                number: '2',
                title: 'Eligibility',
                children: [
                  _para(context, 'You may use MyShankara only if:'),
                  _bullets(context, const [
                    'You are legally permitted to use digital services in your region',
                    'You comply with these Terms',
                    'You provide accurate account information where applicable',
                  ]),
                  _para(context,
                      'By using MyShankara, you confirm that you are legally capable '
                          'of entering into these Terms.'),
                ],
              ),

              _Section(
                number: '3',
                title: 'User Accounts',
                children: [
                  _para(context,
                      'Certain features may require account creation.\n\n'
                          'You are responsible for:'),
                  _bullets(context, const [
                    'Maintaining the confidentiality of your account',
                    'Activities occurring under your account',
                    'Providing accurate information',
                  ]),
                  _para(context, 'You may not:'),
                  _bullets(context, const [
                    'Impersonate another person',
                    'Use the app for unlawful purposes',
                    'Attempt unauthorized access to systems or data',
                  ]),
                ],
              ),

              _Section(
                number: '4',
                title: 'Guru Chat & AI Guidance',
                children: [
                  _para(context,
                      'Guru Chat responses are generated using artificial '
                          'intelligence and are intended solely for spiritual '
                          'reflection, educational, and general informational purposes.\n\n'
                          'AI-generated responses may occasionally contain inaccuracies, '
                          'incomplete information, or interpretations that may not '
                          'reflect traditional teachings in full context.\n\n'
                          'MyShankara does not provide:'),
                  _bullets(context, const [
                    'Medical advice',
                    'Psychological counseling',
                    'Legal advice',
                    'Financial advice',
                    'Crisis intervention',
                    'Emergency support',
                  ]),
                  _para(context,
                      'MyShankara is not intended for emotional dependency or urgent '
                          'mental health support.\n\n'
                          'Users should exercise personal judgment, discretion, and '
                          'caution when relying on guidance or responses provided '
                          'through MyShankara.\n\n'
                          'Users remain solely responsible for their decisions, actions, '
                          'interpretations, and outcomes arising from use of the app.'),
                ],
              ),

              _Section(
                number: '5',
                title: 'Acceptable Use',
                children: [
                  _para(context, 'You agree not to:'),
                  _bullets(context, const [
                    'Misuse the app',
                    'Interfere with app functionality',
                    'Upload malicious code',
                    'Attempt to reverse engineer the platform',
                    'Use MyShankara for harmful, abusive, unlawful, or deceptive activities',
                  ]),
                  _para(context,
                      'We reserve the right to suspend or terminate accounts that '
                          'violate these Terms.'),
                ],
              ),

              _Section(
                number: '6',
                title: 'Memberships & Subscriptions',
                children: [
                  _para(context,
                      'MyShankara may offer paid memberships through:'),
                  _bullets(context, const [
                    'Apple App Store',
                    'Google Play Store',
                  ]),
                  _para(context, 'Subscriptions may:'),
                  _bullets(context, const [
                    'Renew automatically',
                    'Continue until cancelled by the user',
                  ]),
                  _para(context,
                      'Billing, cancellations, refunds, and payment management are '
                          'handled by Apple or Google under their respective terms and '
                          'policies.\n\nPrices may vary by region and platform.'),
                ],
              ),

              _Section(
                number: '7',
                title: 'Intellectual Property',
                children: [
                  _para(context,
                      'All content, branding, text, designs, graphics, app '
                          'interfaces, and software associated with MyShankara are '
                          'protected by applicable intellectual property laws.\n\n'
                          'You may not:'),
                  _bullets(context, const [
                    'Copy',
                    'Reproduce',
                    'Distribute',
                    'Modify',
                    'Commercially exploit',
                  ]),
                  _para(context,
                      'any part of MyShankara without prior written permission.\n\n'
                          'Sacred and historical source traditions remain part of the '
                          'broader cultural and spiritual heritage from which '
                          'inspiration is respectfully drawn.'),
                ],
              ),

              _Section(
                number: '8',
                title: 'Availability & Updates',
                children: [
                  _para(context,
                      'We may modify, update, suspend, or discontinue parts of '
                          'MyShankara at any time without prior notice.\n\n'
                          'Access to MyShankara may occasionally be interrupted due to '
                          'maintenance, updates, technical issues, or third-party '
                          'service interruptions.\n\n'
                          'We do not guarantee uninterrupted or error-free operation.'),
                ],
              ),

              _Section(
                number: '9',
                title: 'Disclaimer of Warranties',
                children: [
                  _para(context,
                      'MyShankara is provided on an "as is" and "as available" '
                          'basis.\n\n'
                          'To the fullest extent permitted by law, we disclaim '
                          'warranties of any kind, whether express or implied, '
                          'including:'),
                  _bullets(context, const [
                    'Accuracy',
                    'Reliability',
                    'Availability',
                    'Fitness for a particular purpose',
                  ]),
                ],
              ),

              _Section(
                number: '10',
                title: 'Limitation of Liability',
                children: [
                  _para(context,
                      'To the maximum extent permitted by law, MyShankara and its '
                          'creators shall not be liable for:'),
                  _bullets(context, const [
                    'Indirect damages',
                    'Incidental damages',
                    'Consequential damages',
                    'Loss of data',
                    'Loss of profits',
                    'Emotional distress',
                    'Decisions made based on app content or Guru Chat responses',
                  ]),
                  _para(context,
                      'This includes reliance on AI-generated spiritual, '
                          'philosophical, or reflective guidance.\n\n'
                          'Your use of MyShankara is at your own discretion and '
                          'responsibility.'),
                ],
              ),

              _Section(
                number: '11',
                title: 'Privacy',
                children: [
                  _para(context,
                      'Your use of MyShankara is also governed by the Privacy '
                          'Policy.\n\n'
                          'Please review the Privacy Policy for information on how data '
                          'is collected and used.'),
                ],
              ),

              _Section(
                number: '12',
                title: 'Termination',
                children: [
                  _para(context,
                      'You may stop using MyShankara at any time.\n\n'
                          'We reserve the right to suspend or terminate access for '
                          'violations of these Terms or misuse of the platform.'),
                ],
              ),

              _Section(
                number: '13',
                title: 'Changes to These Terms',
                children: [
                  _para(context,
                      'We may update these Terms from time to time.\n\n'
                          'Updated versions will be published within the app and '
                          'reflected by the "Last Updated" date above.\n\n'
                          'Continued use of MyShankara after updates constitutes '
                          'acceptance of the revised Terms.'),
                ],
              ),

              _Section(
                number: '14',
                title: 'Contact',
                children: [
                  _para(context,
                      'For questions regarding these Terms, please contact:'),
                  _para(context, 'support@myshankara.ai'),
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