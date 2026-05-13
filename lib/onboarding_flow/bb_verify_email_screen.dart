import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../main.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final AppState appState;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.appState,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}


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


class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _controllers = List.generate(4, (_) => TextEditingController());
  final _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isResendDisabled = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _onChanged(int index, String value) {
    // Move to next box when a digit is entered
    if (value.length == 1 && index < 3) {
      _focusNodes[index + 1].requestFocus();
    }

    // Backspace to previous box
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onVerify() {
    // TODO: verify with backend using _code
    // print(_code);
  }

  void _onResend() async {
    if (_isResendDisabled) return; // Prevent multiple taps

    setState(() {
      _isResendDisabled = true;
      _countdown = 60;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Start countdown timer
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          if (_countdown > 0) {
            _countdown--;
          } else {
            _isResendDisabled = false;
            _timer?.cancel();
          }
        });
      });
    } catch (e) {
      // On error, re-enable immediately
      setState(() {
        _isResendDisabled = false;
        _countdown = 0;
      });
      _timer?.cancel();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resend email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brand = theme.extension<BrandExtension>();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cancel Account Creation?'),
                content: const Text('This will delete your unverified account. You will need to sign up again.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context), // Close dialog
                    child: const Text('No, Keep it'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await FirebaseAuth.instance.currentUser?.delete();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to delete: $e')),
                          );
                        }
                      }
                    },
                    child: const Text('Yes, Delete'),
                  ),
                ],
              ),
            );
          },
        ),
        title: Text(
          'Verify Email',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'MyShankara',
                    style: theme.textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  Text(
                    'We\'ve sent a verification link to',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onBackground.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.onBackground,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),


                  Text(
                    'Please check your email and click the link to verify your account.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onBackground.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),



                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        // Refresh email verification status in AppState
                        await widget.appState.refreshEmailVerification();

                        final user = FirebaseAuth.instance.currentUser;
                        if (user?.emailVerified ?? false) {
                          if (context.mounted) {
                            // Now AppState is updated, router will redirect automatically
                            context.go('/profile-basics');
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please verify your email first by clicking the link in your inbox.'),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(
                        'I\'ve Verified My Email',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.onAccent,
                        ),
                      ),
                    ),
                  ),




                  Text(
                    "Didn't receive the email?",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onBackground.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 4),

                  GestureDetector(
                    onTap: _isResendDisabled ? null : _onResend,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isResendDisabled
                            ? AppColors.link.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _isResendDisabled
                            ? 'Resend in $_countdown s'
                            : 'Resend',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _isResendDisabled
                              ? AppColors.link.withOpacity(0.4)
                              : AppColors.link,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
