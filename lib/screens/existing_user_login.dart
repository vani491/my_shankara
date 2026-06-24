import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
// import 'package:flutter_signin_button/flutter_signin_button.dart';

import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'profile_basics.dart';
import '../onboarding_flow/bb_verify_email_screen.dart';
import '../main.dart';
import '../onboarding_flow/ba_create_account.dart';

class ExistingUserLogin extends StatefulWidget {
  const ExistingUserLogin({super.key});

  @override
  State<ExistingUserLogin> createState() => _ExistingUserLoginState();
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

  factory SocialSignInButton.google({
    required VoidCallback onPressed,
    String assetName = 'assets/google-icon-logo.svg',
    String label = 'Continue with Google',
    Color outlineColor = const Color(0xFFE0E0E0),
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


class _ExistingUserLoginState extends State<ExistingUserLogin> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;



  void _onForgotPassword() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const ForgotPasswordDialog();
      },
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onGoogleSignUp1() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await AuthService.signInWithGoogle();
      if (!mounted) return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google sign-in failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) nav.pop();
        });
      }
    }
  }


  // inside _ExistingUserLoginState
  Future<void> _onEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      // 1. Sign in the user with email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // 2. On successful login, GoRouter will handle the navigation
      //    based on the state (onboarding, email verification, profile completion).
      //    We just need to ensure the AppState listens for the auth change.
      //    Since main.dart already calls appState.attachAuth(),
      //    signing in is enough. We can optionally navigate to '/' to trigger
      //    the GoRouter redirect immediately, but the auth state listener should
      //    handle it. For simplicity, we can let GoRouter take over.
      //    context.go('/');  <-- Could be added here if needed, but the listener should do the trick.

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      // Handle specific Firebase Auth errors
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Invalid email or password.';
          break;
        case 'invalid-email':
          message = 'Invalid email address format.';
          break;
        case 'too-many-requests':
          message = 'Too many login attempts. Try again later.';
          break;
        default:
          message = e.message ?? 'Login failed.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('An unexpected error occurred: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  void _onLogin() {
    // Navigate to login screen
    Navigator.pop(context); // or use your navigation method
  }


  void _onTerms() => context.push('/terms-of-service');
  void _onPrivacy() => context.push('/privacy-policy');

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
        leading: const BackButton(),
        title: Text(
          'Welcome Back',
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
                      'Log in to continue your practice',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall
                  ),
                  const SizedBox(height: 12),

                  SocialSignInButton.google(
                    onPressed: () => _onGoogleSignUp1(),

                  ),

                  const SizedBox(height: 14),

                  SocialSignInButton.apple(
                    // onPressed: () => _onAppleSignUp(),
                    onPressed: () {
                      print('guest button pressed');
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //       builder: (context) => RegisterScreen()),
                      // );
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
                          label: 'Password',
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
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _loading ? null : _onForgotPassword,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot password?',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.link,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),


                      ],
                    ),
                  ),




                  const SizedBox(height: 16),
                  const Spacer(),


                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _loading ? null : _onEmailLogin,
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
                        'Log in',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(

                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                        height: 1.3,
                      ),
                      children: <TextSpan>[
                        const TextSpan(
                          text: 'New here? ',
                        ),
                        TextSpan(
                          text: 'Sign up',
                          style: TextStyle(
                            color: AppColors.link,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              // Your navigation logic
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => CreateAccountScreen()),
                              );
                            },
                        ),
                      ],
                    ),
                  ),

                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),


                      child: Text.rich(
                        textAlign: TextAlign.center,
                        TextSpan(
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.7),
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: ' By continuing, you agree to the ',
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
    super.key,
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
    // final isPasswordField = widget.obscure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          focusNode: _focusNode,
          controller: widget.controller,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscure,
          onChanged: (_) => setState(() {}),
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
      ],
    );
  }
}




// Add this new class outside of _ExistingUserLoginState
class ForgotPasswordDialog extends StatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  State<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<ForgotPasswordDialog> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      // Close the dialog and show a success message on the main screen
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset link sent to ${_emailController.text.trim()}. Please check your email.',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email.';
          break;
        case 'invalid-email':
          message = 'The email address is not valid.';
          break;
        default:
          message = e.message ?? 'Failed to send reset email.';
      }

      // Show error message within the dialog context
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter your email',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Email is required';
            }
            final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
            if (!emailRegex.hasMatch(v.trim())) {
              return 'Enter a valid email';
            }
            return null;
          },
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: <Widget>[
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        TextButton(
          onPressed: _loading ? null : _sendPasswordResetEmail,
          child: _loading
              ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : const Text('Send Link'),
        ),
      ],
    );
  }
}