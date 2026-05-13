import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../screens/profile_basics.dart';
import 'bb_verify_email_screen.dart';
import 'package:flutter/foundation.dart';
import '../main.dart';
import 'package:go_router/go_router.dart';
import '../screens/existing_user_login.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final int strength; // 0 = easy, 1 = medium, 2 = hard

  const PasswordStrengthIndicator({super.key, required this.strength});

  Color get _color {
    switch (strength) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inactive = Theme
        .of(context)
        .colorScheme
        .surfaceContainerHighest;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i <= strength;
            return Expanded(
              child: Container(
                height: 8,
                margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                decoration: BoxDecoration(
                  color: filled ? _color : inactive,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

int passwordStrength(String p) {
  if (p.isEmpty) return 0;

  int score = 0;

  if (p.length >= 8) score++;
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(p);
  final hasDigit = RegExp(r'\d').hasMatch(p);
  if (hasLetter && hasDigit) score++;

  final hasSpecial = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\\/\[\]=;+`~]').hasMatch(
      p);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
  final hasLower = RegExp(r'[a-z]').hasMatch(p);
  if (hasSpecial || (hasUpper && hasLower)) score++;

  if (score <= 1) return 0; // easy
  if (score == 2) return 1; // medium
  return 2; // hard
}

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});
  // final AppState appState;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}


class SocialSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String assetName;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color outlineColor;
  final Color? iconColor;
  final double height;
  final double borderRadius;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const SocialSignInButton({
    super.key,
    required this.onPressed,
    required this.assetName,
    required this.label,
    this.backgroundColor = Colors.white,
    this.textColor = Colors.black,
    this.outlineColor = Colors.grey,
    this.iconColor,
    this.height = 52,
    this.borderRadius = 10,
    this.iconSize = 28,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  /// Convenience factory for Google style button
  factory SocialSignInButton.google({
    required VoidCallback onPressed,
    String assetName = 'assets/google-icon-logo.svg',
    String label = 'Continue with Google',
    Color outlineColor = const Color(0xFFE0E0E0),
    // double height = 52,
    Key? key,
  }) =>
      SocialSignInButton(
        key: key,
        onPressed: onPressed,
        assetName: assetName,
        label: label,
        backgroundColor: Colors.white,
        textColor: Colors.black,
        outlineColor: outlineColor,
        iconColor: null,
        iconSize: 28,
        // height: height,
      );


  factory SocialSignInButton.apple({
    required VoidCallback onPressed,
    String assetName = 'assets/apple-logo.svg',
    String label = 'Continue with Apple',
    // double height = 52,
    Key? key,
  }) =>
      SocialSignInButton(
        key: key,
        onPressed: onPressed,
        assetName: assetName,
        label: label,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        outlineColor: Colors.black,
        iconColor: Colors.white,
        iconSize: 38,
        // height: height,
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: BoxConstraints.tightFor(height: height),
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(height),
            side: BorderSide(color: outlineColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            backgroundColor: backgroundColor,
            padding: padding,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                assetName,
                width: iconSize,
                height: iconSize,
                // apply color only when provided (useful for white icon on black bg)
                colorFilter: iconColor != null
                    ? ColorFilter.mode(iconColor!, BlendMode.srcIn)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: Theme
                    .of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  _onGoogleSignUp() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await AuthService.signInWithGoogle();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google sign-in failed: $e')),
      );
    }
  }

  void _onAppleSignUp() {}

  Future<void> _onCreateAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Optionally send email verification
      await userCredential.user?.sendEmailVerification();
      if (mounted) {
        context.go('/verify-email');
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'email-already-in-use':
          message = 'An account already exists with this email';
          break;
        case 'weak-password':
          message = 'Password is too weak';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        default:
          message = e.message ?? 'Sign-up failed';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-up failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onLogin() {
    Navigator.pop(context);
  }

  void _onTerms() {}
  void _onPrivacy() {}

  String get userEmail => 'test@gmail.com';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brand = theme.extension<BrandExtension>();
    final cardColor = brand?.surfaceCard ?? cs.surface;
    final primaryButtonColor = brand?.accentButton ?? cs.primary;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(),
        title: Text(
          'Create Account',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          // child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: IntrinsicHeight(
              child: Column(
                // crossAxisAlignment: CrossAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 34),

                  Text(
                      'Light your first diya today!\nExperience wisdom, calm, growth.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                  ),

                  const SizedBox(height: 34),
                  SocialSignInButton.google(
                    onPressed: () => _onGoogleSignUp(),
                  ),

                  const SizedBox(height: 14),

                  SocialSignInButton.apple(
                    // onPressed: () => _onAppleSignUp(),
                    onPressed: () {
                      print('Continue with Apple');

                    },
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          'or use email',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 18),

                  Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      children: [
                        _LabeledField(
                          label: 'Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v
                                .trim()
                                .isEmpty) {
                              return 'Email is required';
                            }
                            final email = v.trim();
                            final emailRegex = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            );
                            if (!emailRegex.hasMatch(email)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _LabeledField(
                          label: 'New Password',
                          controller: _passwordController,
                          obscure: _obscure,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required';
                            }
                            if (v.length < 8) {
                              return 'Minimum 8 characters';
                            }
                            return null;
                          },
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() {
                                  _obscure = !_obscure;
                                }),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Theme
                                  .of(
                                context,
                              )
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.70),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _onCreateAccount,
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
                          : const Text(
                        'Sign up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text.rich(
                        textAlign: TextAlign.center,
                        TextSpan(
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withOpacity(0.7),
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: 'By creating an account, you agree to the ',
                            ),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: AppColors.link,
                                fontWeight: FontWeight.w500,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = _onTerms,
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                decoration: TextDecoration.underline,
                                color: AppColors.link,
                                fontWeight: FontWeight.w500,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = _onPrivacy,
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withOpacity(0.85),
                        ),
                      ),
                      TextButton(
                        // onPressed: _onLogin,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExistingUserLogin(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 0),
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
                ],
              ),
            ),
          ),
          // ),

        ),
      ),

    );
  }
}

class _LabeledField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscure;
  final Widget? suffix;

  const _LabeledField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.validator,
    this.obscure = false,
    this.suffix,
  });

  @override
  State<_LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<_LabeledField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final brand = null;

    final isPasswordField = widget.obscure;
    print('Focus: ${_focusNode.hasFocus}, Text: "${widget.controller.text}", IsEmpty: ${widget.controller.text.isEmpty}');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          focusNode: _focusNode,
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscure,
          onChanged: (_) => setState(() {}),
          // Rebuild on text change
          style: TextStyle(color: cs.onSurface),
          validator: widget.validator,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(color: cs.onSurface.withOpacity(0.9)),
            filled: true,
            fillColor: cs.surface.withOpacity(0.06),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: cs.outline),
              borderRadius: BorderRadius.circular(14),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: brand?.accentButton ?? cs.primary),
              borderRadius: BorderRadius.circular(14),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: cs.error),
              borderRadius: BorderRadius.circular(14),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: cs.error),
              borderRadius: BorderRadius.circular(14),
            ),
            disabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: cs.outline.withOpacity(0.6)),
              borderRadius: BorderRadius.circular(14),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: widget.suffix,
          ),
        ),
        if (isPasswordField) ...[
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _focusNode.hasFocus
                ? PasswordStrengthIndicator(
              key: const ValueKey('pw-indicator-visible'),
              strength: passwordStrength(widget.controller.text),
            )
                : const SizedBox.shrink(key: ValueKey('pw-indicator-hidden')),
          ),
        ],
      ],
    );
  }
}