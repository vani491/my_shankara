import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// for storing data to firestone
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../main.dart';
import '../services/user_name_cache.dart';


class ProfileBasicsPage extends StatefulWidget {
  final AppState? appState;
  final bool isEditMode;
  const ProfileBasicsPage({super.key, this.appState, this.isEditMode = false});

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

  if (score <= 1) return 0;
  if (score == 2) return 1;
  return 2;
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
  bool _isLoading = false;
  bool _isGuest = false;
  String _emailDisplay = '';

  @override
  void initState() {
    super.initState();
    if (widget.isEditMode) {
      final user = FirebaseAuth.instance.currentUser;
      _isGuest = user == null || user.isAnonymous;
      if (!_isGuest) {
        _loadExistingProfile();
      }
    }
  }

  Future<void> _loadExistingProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _emailDisplay = user.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();
      if (data != null) {
        _nameCtrl.text = (data['fullName'] ?? '').toString();
        _preferredNameCtrl.text = (data['preferredName'] ?? '').toString();
        _yearOfBirthCtrl.text = (data['yearOfBirth'] ?? '').toString();

        final genderStr = (data['gender'] ?? '').toString();
        _selectedGender = Gender.values
            .where((g) => g.name == genderStr)
            .cast<Gender?>()
            .firstOrNull;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _preferredNameCtrl.dispose();
    _ageCtrl.dispose();
    _yearOfBirthCtrl.dispose();
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

  String _genderDisplayName(Gender? gender) {
    switch (gender) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Prefer not to say';
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: widget.isEditMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => deleteUnverifiedAccount(),
              ),
        title: Text(
          widget.isEditMode ? 'Edit Profile' : 'About You',
          style: theme.textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: widget.isEditMode
            ? (_isGuest
                ? _buildGuestEditView(theme)
                : _buildSignedInEditView(theme))
            : _buildOnboardingBody(theme),
      ),
    );
  }

  // ── Edit mode: guest ──────────────────────────────────────────────────────

  Widget _buildGuestEditView(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Create a free account to continue your spiritual journey.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Start 30-Day Free Trial'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Edit mode: signed-in user ─────────────────────────────────────────────

  Widget _buildSignedInEditView(ThemeData theme) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            Text('Full Name', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              enabled: false,
              decoration: _decorate('Full name'),
            ),
            const SizedBox(height: 16),

            Text('Gender', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _genderDisplayName(_selectedGender),
              enabled: false,
              decoration: _decorate('Gender'),
            ),
            const SizedBox(height: 16),

            Text('Year of Birth', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _yearOfBirthCtrl,
              enabled: false,
              decoration: _decorate('Year of birth'),
            ),
            const SizedBox(height: 16),

            Text('Email', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _emailDisplay,
              enabled: false,
              decoration: _decorate('Email'),
            ),
            const SizedBox(height: 16),

            Text('Preferred Name', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _preferredNameCtrl,
              textInputAction: TextInputAction.done,
              decoration: _decorate('Enter your preferred name'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _savePreferredName,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),

            Center(
              child: Text.rich(
                TextSpan(
                  text: 'Need help updating account details? ',
                  style: theme.textTheme.bodySmall,
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => context.push('/support'),
                        child: Text(
                          'Contact Support',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Onboarding mode (unchanged) ───────────────────────────────────────────

  Widget _buildOnboardingBody(ThemeData theme) {
    return SingleChildScrollView(
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
                        const SizedBox(height: 8),
                        Wrap(
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

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  InputDecoration _decorate(String hint, {Widget? suffix}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InputDecoration(
      hintText: hint,
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
            'MyShankara is for seekers 18 years and older. You won\'t be able to continue.',
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

  Future<void> _savePreferredName() async {
    final preferredName = _preferredNameCtrl.text.trim();
    if (preferredName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a preferred name')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({'preferredName': preferredName}, SetOptions(merge: true));
      UserNameCache.value = _preferredNameCtrl.text.trim();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        'trialStartDate': FieldValue.serverTimestamp(),
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
