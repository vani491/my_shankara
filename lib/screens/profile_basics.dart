import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// for storing data to firestone
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';

class ProfileBasicsPage extends StatefulWidget {
  final AppState? appState; // ← ADD THIS

  const ProfileBasicsPage({super.key, this.appState}); // ← MODIFY THIS

  @override
  State<ProfileBasicsPage> createState() => _ProfileBasicsPageState();
}

enum Gender { male, female, other }

int passwordStrength(String p) {
  if (p.isEmpty) return 0;
  int score = 0;
  if (p.length >= 8) score++;
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(p);
  final hasDigit = RegExp(r'\d').hasMatch(p);
  if (hasLetter && hasDigit) score++;

  final hasSpecial = RegExp(
    r'[!@#\$%^&*(),.?":{}|<>_\-\\/\[\]=;+`~]',
  ).hasMatch(p);
  final hasUpper = RegExp(r'[A-Z]').hasMatch(p);
  final hasLower = RegExp(r'[a-z]').hasMatch(p);
  if (hasSpecial || (hasUpper && hasLower)) score++;

  if (score <= 1) return 0; // easy
  if (score == 2) return 1; // medium
  return 2; // hard
}

class _ProfileBasicsPageState extends State<ProfileBasicsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final TextEditingController _preferredNameCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final _yearOfBirthCtrl = TextEditingController();

  String? _ageGateError;
  Gender? _selectedGender;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _preferredNameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void deleteUnverifiedAccount() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'This will delete your unverified account. You will need to sign up again.',
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              child: const Text('No, Keep it'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Yes, Delete'),
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
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // leading: const BackButton(),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => deleteUnverifiedAccount(),
        ),
        title: Text('About You', style: theme.textTheme.titleLarge),
        centerTitle: true,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 34),
                  Text(
                    'This helps MyShankara to serve you better.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Full name*', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: _decorate('Enter your full name'),
                          // Used 'Enter your full name' as the hint
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            if (v.trim().length < 2) return 'Name is too short';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Preferred name',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _preferredNameCtrl,
                          textInputAction: TextInputAction.next,
                          decoration: _decorate('Preferred name'),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter preferred name';
                            }
                            if (v.trim().length < 2) return 'Name is too short';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Gender*', style: theme.textTheme.titleSmall),
                            const SizedBox(height: 8), // Spacing
                            Wrap(
                              // The radio buttons
                              spacing: 10,
                              crossAxisAlignment: WrapCrossAlignment.start,
                              children: [
                                _genderRadio(
                                  context,
                                  label: 'Male',
                                  value: Gender.male,
                                ),
                                _genderRadio(
                                  context,
                                  label: 'Female',
                                  value: Gender.female,
                                ),
                                _genderRadio(
                                  context,
                                  label: 'Prefer not to say',
                                  value: Gender.other,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Year of birth*',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: TextFormField(
                            controller: _yearOfBirthCtrl,
                            readOnly: true,
                            decoration: _decorate(
                              'e.g. 1980',
                              suffix: const Icon(Icons.calendar_month),
                            ).copyWith(errorText: _ageGateError),
                            onTap: _pickYear,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please select your birth year';
                              }
                              final y = int.tryParse(v);
                              final nowYear = DateTime.now().year;
                              if (y == null || y < 1900 || y > nowYear) {
                                return 'Enter a valid year';
                              }
                              // This check can be kept as a secondary guardrail,
                              // but the picker should prevent it now.
                              if (nowYear - y < 18) {
                                return 'You must be at least 18 years old to create an account';
                              }
                              return null;
                            },
                          ),
                        ),
                        Text(
                          'MyShankara is for seekers 18+',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isSaving ? null : _saveProfileBasics,
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Begin your journey'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Add extra spacing to avoid cropping on small screens
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decorate(String hint, {Widget? suffix}) {
    // Removed 'label' from params and added 'hint'
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InputDecoration(
      // labelText: label, // Removed labelText
      hintText: hint,
      // Used passed string as hintText
      filled: true,
      fillColor: theme.inputDecorationTheme.fillColor ?? cs.surface,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Future<void> _pickYear() async {
    final now = DateTime.now();
    final int currentYear = now.year;
    final int yearCutoff18 = currentYear - 18;
    final int firstYear = 1950;

    final int lastSelectableYear = currentYear;

    final int initialYear =
        int.tryParse(_yearOfBirthCtrl.text) ??
        (yearCutoff18 < firstYear ? firstYear : yearCutoff18);

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: const Text('Select birth year'),
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: SizedBox(
            height: 300,
            width: 320,
            child: YearPicker(
              firstDate: DateTime(firstYear),
              // *** KEY CHANGE: Set lastDate to currentYear to show all options ***
              lastDate: DateTime(lastSelectableYear),
              selectedDate: DateTime(initialYear),
              onChanged: (DateTime dateTime) {
                final y = dateTime.year;
                final age = currentYear - y;

                setState(() {
                  _yearOfBirthCtrl.text = y.toString();
                  _ageGateError = null;
                  Navigator.of(ctx).pop();
                  if (age < 18) {
                    _showAgeGatePopup();
                  }
                });
              },
            ),
          ),
        );
      },
    );
  }

  void _showAgeGatePopup() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'MyShankara is for seekers 18 years and older. You won’t be able to continue.',
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: <Widget>[
            TextButton(
              child: const Text('Back'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _yearOfBirthCtrl.clear();
                });
              },
            ),
            TextButton(
              child: const Text('Back to start'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _genderRadio(
    BuildContext context, {
    required String label,
    required Gender value,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () => setState(() => _selectedGender = value),
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<Gender>(
            value: value,
            groupValue: _selectedGender,
            onChanged: (v) => setState(() => _selectedGender = v),
            visualDensity: VisualDensity.compact,
            fillColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? cs.secondary
                  : cs.outline,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: _selectedGender == value
                  ? cs.onSurface
                  : cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfileBasics() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User not logged in.')),
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });

    try {
      final String birthYear = _yearOfBirthCtrl.text;
      final int age = DateTime.now().year - (int.tryParse(birthYear) ?? 0);

      final Map<String, dynamic> userData = {
        'fullName': _nameCtrl.text.trim(),
        'preferredName': _preferredNameCtrl.text.trim(),
        'gender': _selectedGender?.name,
        'yearOfBirth': int.tryParse(birthYear),
        'age': age,
        'createdAt': FieldValue.serverTimestamp(),
        'totalDiyasLit': 0,
        'lastLitDate': '',
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(userData, SetOptions(merge: true));
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        await widget.appState?.checkProfileComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
        if (mounted) {
          context.go('/');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
