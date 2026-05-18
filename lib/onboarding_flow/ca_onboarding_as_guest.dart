import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import 'ba_create_account.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GuestInterstitialPage extends StatefulWidget {
  final VoidCallback? onSignup;

  final String termsUrl;
  final String privacyUrl;

  const GuestInterstitialPage({
    super.key,
    this.onSignup,
    this.termsUrl = 'https://www.myshankara.ai/terms-and-conditions',
    this.privacyUrl = 'https://www.myshankara.ai/privacy-policy',
  });

  @override
  State<GuestInterstitialPage> createState() => _GuestInterstitialPageState();
}

class _GuestInterstitialPageState extends State<GuestInterstitialPage> {
  bool _confirmAge = false;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brand = theme.extension<BrandExtension>();

    const Color success = Color(0xFF15803D);
    const Color danger = Color(0xFFB91C1C);
    const Color warning = Color(0xFFB45309);

    final bool canContinue = _confirmAge && !_loading;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        leading: const BackButton(),
        title: Text('Guest Access', style: theme.textTheme.titleLarge),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    'Begin today, look around, make it a habit.',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 42),

                _FeatureRow(
                  icon: Icons.wb_sunny_rounded,
                  iconColor: success,
                  title: 'Daily Darshan - Fully available',
                  help: "Receive today's teaching, meaning, blessing.",
                ),
                const SizedBox(height: 12),

                _FeatureRow(
                  icon: Icons.local_fire_department,
                  iconColor: danger,
                  title: 'Diya Tracker - Not available',
                  help: 'Sign up to track devotion streak.',
                ),
                const SizedBox(height: 12),

                _FeatureRow(
                  icon: Icons.chat_bubble_rounded,
                  iconColor: warning,
                  title: 'Guru Chat - Limited',
                  help: 'Sign up for unlimited guidance.',
                ),

                const SizedBox(height: 32),
                InkWell(
                  onTap: () => setState(() => _confirmAge = !_confirmAge),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _confirmAge,
                        onChanged: (v) =>
                            setState(() => _confirmAge = v ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 11.0),
                          child: Text(
                            'I confirm I am above 18 years old',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black,
                            ),
                            textScaleFactor: 1.0, // Add this
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _TermsAndPrivacyText(
                  termsUrl: widget.termsUrl,
                  privacyUrl: widget.privacyUrl,
                ),
                const SizedBox(height: 16),

                // Sign up button
                SizedBox(
                  child: FilledButton(
                    onPressed: canContinue ? _signInAnonymouslyAndGo : null,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Continue as Guest'),
                  ),
                ),

                const SizedBox(height: 8),
                Center(child: Text('Or', style: theme.textTheme.titleSmall)),
                const SizedBox(height: 8),

                SizedBox(
                  child: FilledButton(
                    onPressed: () {
                      // print('guest button pressed');
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreateAccountScreen(),
                        ),
                      );
                    },
                    child: Text('Start 30-day Free Trial'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInAnonymouslyAndGo() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (!mounted) return;
          context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Sign-in failed: $e')));
      }
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String help;

  const _FeatureRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.help,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  Text(
                    help,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TermsAndPrivacyText extends StatelessWidget {
  final String termsUrl;
  final String privacyUrl;

  const _TermsAndPrivacyText({
    required this.termsUrl,
    required this.privacyUrl,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium!;

    final blackBody = style.copyWith(color: Colors.black);

    final linkStyle = style.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
    );

    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: blackBody,
        children: [
          const TextSpan(text: 'By continuing as Guest, you agree to the '),
          TextSpan(
            text: 'Terms of Service',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                Uri.parse(termsUrl),
                mode: LaunchMode.externalApplication,
              ),
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: linkStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () => launchUrl(
                Uri.parse(privacyUrl),
                mode: LaunchMode.externalApplication,
              ),
          ),
        ],
      ),
      textScaler: TextScaler.linear(1.0),
    );
  }
}
