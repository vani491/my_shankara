
import 'package:flutter/material.dart';

import '../theme/colors.dart';
import 'ca_onboarding_as_guest.dart';
import 'ba_create_account.dart';

import '../screens/existing_user_login.dart';

@immutable
class BrandExtension extends ThemeExtension<BrandExtension> {
  final Color accentButton;
  final Color surfaceCard;
  final Color primary;

  const BrandExtension({
    required this.accentButton,
    required this.surfaceCard,
    required this.primary
  });

  @override
  BrandExtension copyWith({Color? accentButton, Color? surfaceCard}) =>
      BrandExtension(
        accentButton: accentButton ?? this.accentButton,
        surfaceCard: surfaceCard ?? this.surfaceCard,
        primary: AppColors.primary,
      );

  @override
  BrandExtension lerp(ThemeExtension<BrandExtension>? other, double t) {
    if (other is! BrandExtension) return this;
    return BrandExtension(
      accentButton: Color.lerp(accentButton, other.accentButton, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
    );
  }
}


class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brand = theme.extension<BrandExtension>();

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top image
                  Image.asset(
                    'assets/Logo-Trans.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 32),
                  // Title
                  Text(
                    'MyShankara',
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  Text(
                    'Har Har Shankar • Jai Jai Shankar',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Samarkan',
                      color: AppColors.accent,
                      // fontStyle: FontStyle.italic,
                      letterSpacing: 0.2,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CreateAccountScreen()),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Start 30-day Free Trial',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.onAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Full features',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onAccent.withOpacity(0.9),
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Secondary button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => GuestInterstitialPage()),
                        );
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Continue as Guest',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Limited features',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.onBackground.withOpacity(0.8),
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onBackground.withValues(alpha: 0.9),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExistingUserLogin(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Log in',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.link,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onBackground,
                      ),

                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
