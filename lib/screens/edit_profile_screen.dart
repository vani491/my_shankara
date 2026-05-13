import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';


class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _preferredNameCtrl = TextEditingController();
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _occupationCtrl = TextEditingController();
  final _lifeGoalsCtrl = TextEditingController();

  // State
  DateTime? _dob;
  String? _language = 'English (India)';
  String? _customGender;
  String _gender = 'Prefer not to say';
  bool _emailVerified = false;
  bool _phoneVerified = false;

  // Avatar
  final ImagePicker _picker = ImagePicker();
  File? _avatar;

  // Life goal chips
  final List<String> _presetGoals = const [
    'Fitness',
    'Career',
    'Learning',
    'Finance',
    'Mindfulness'
  ];
  final Set<String> _selectedGoals = {};

  bool _saving = false;
  bool _dirty = false;

  @override
  void dispose() {
    _preferredNameCtrl.dispose();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _occupationCtrl.dispose();
    _lifeGoalsCtrl.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickFromCamera() async {
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (x != null) {
      setState(() {
        _avatar = File(x.path);
        _markDirty();
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x != null) {
      setState(() {
        _avatar = File(x.path);
        _markDirty();
      });
    }
  }

  void _removePhoto() {
    setState(() {
      _avatar = null;
      _markDirty();
    });
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
              if (_avatar != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removePhoto();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    // Example: min age 13
    final earliest = DateTime(now.year - 100, now.month, now.day);
    final latest = DateTime(now.year - 13, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 21, now.month, now.day),
      firstDate: earliest,
      lastDate: latest,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _markDirty();
      });
    }
  }

  int? _age(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _verifyEmail() async {
    // TODO: replace with your verification trigger.
    // Simulate flow
    final ok = await _showCodeDialog('Verify email');
    if (ok) {
      setState(() {
        _emailVerified = true;
        _markDirty();
      });
      _snack('Email verified');
    }
  }

  Future<void> _verifyPhone() async {
    // TODO: replace with actual SMS verify.
    final ok = await _showCodeDialog('Verify phone');
    if (ok) {
      setState(() {
        _phoneVerified = true;
        _markDirty();
      });
      _snack('Phone verified');
    }
  }

  Future<bool> _showCodeDialog(String title) async {
    final codeCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: codeCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            labelText: 'Enter 6-digit code',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, codeCtrl.text.length == 6), child: const Text('Verify')),
        ],
      ),
    );
    return ok ?? false;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      // Scroll to first error automatically by Flutter if using ListView? Ensure visible:
      _snack('Please fix the highlighted fields.');
      return;
    }
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _saving = false;
      _dirty = false;
    });
    if (mounted) {
      _snack('Profile updated');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) {
        if (!_dirty || didPop) return;
        _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        // appBar: AppBar(
          // title: const Text('Edit profile'),
          // actions: [
          //   TextButton(
              // onPressed: _dirty && !_saving ? _save : null,
              // child: const Text('Done'),
            // ),
          // ],
        // ),
        body: Form(
          key: _formKey,
          onChanged: _markDirty,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            children: [
              // Avatar
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 56,
                          backgroundImage: _avatar != null ? FileImage(_avatar!) : null,
                          child: _avatar == null ? const Icon(Icons.person, size: 56) : null,
                        ),
                        GestureDetector(
                          onTap: _showPhotoSheet,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4, right: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit, size: 18, color: theme.colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              _SectionHeader('Identity'),
              TextFormField(
                controller: _preferredNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Preferred name',
                  helperText: 'Shown on your profile',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _fullNameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) return 'Please enter 2–80 characters.';
                  if (v.trim().length > 80) return 'Too long.';
                  return null;
                },
              ),

              const SizedBox(height: 20),
              _SectionHeader('Contact & verification'),
              _LabeledRow(
                label: 'Email',
                trailing: _VerifyChip(
                  verified: _emailVerified,
                  onTap: _emailVerified ? null : _verifyEmail,
                ),
              ),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email required.';
                  final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v);
                  if (!ok) return 'Enter a valid email.';
                  return null;
                },
                onChanged: (_) {
                  // Email change clears verification
                  if (_emailVerified) setState(() => _emailVerified = false);
                },
              ),
              const SizedBox(height: 12),
              _LabeledRow(
                label: 'Phone number',
                trailing: _VerifyChip(
                  verified: _phoneVerified,
                  onTap: _phoneVerified ? null : _verifyPhone,
                ),
              ),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '+91 98765 43210',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Phone required.';
                  if (v.replaceAll(RegExp(r'\D'), '').length < 8) {
                    return 'Enter a valid number.';
                  }
                  return null;
                },
                onChanged: (_) {
                  if (_phoneVerified) setState(() => _phoneVerified = false);
                },
              ),

              const SizedBox(height: 20),
              _SectionHeader('Personal details'),
              _LabeledRow(
                label: 'Date of birth',
                trailing: null,
              ),
              _DobField(
                dob: _dob,
                onTap: _pickDob,
              ),
              const SizedBox(height: 12),

              _LabeledRow(label: 'Gender'),
              const SizedBox(height: 6),
              _GenderSegment(
                value: _gender,
                onChanged: (v) {
                  setState(() {
                    _gender = v;
                    if (v != 'Custom') _customGender = null;
                  });
                },
              ),
              if (_gender == 'Custom') ...[
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Enter gender'),
                  onChanged: (v) => _customGender = v,
                ),
              ],
              const SizedBox(height: 12),

              TextFormField(
                controller: _occupationCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Occupation',
                  hintText: 'e.g., Product Designer',
                ),
              ),

              const SizedBox(height: 20),
              _SectionHeader('Preferences'),
              DropdownButtonFormField<String>(
                initialValue: _language,
                decoration: const InputDecoration(labelText: 'Language'),
                items: const [
                  'English (India)',
                  'English (US)',
                  'हिन्दी',
                  'Español',
                  'Français',
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => _language = v),
              ),

              const SizedBox(height: 12),
              _LabeledRow(label: 'Life goals'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: -6,
                children: [
                  for (final g in _presetGoals)
                    FilterChip(
                      label: Text(g),
                      selected: _selectedGoals.contains(g),
                      onSelected: (sel) {
                        setState(() {
                          if (sel) {
                            _selectedGoals.add(g);
                          } else {
                            _selectedGoals.remove(g);
                          }
                          _markDirty();
                        });
                      },
                    ),
                  InputChip(
                    label: const Text('Add your own'),
                    onPressed: () {
                      // Focus to textarea below
                      FocusScope.of(context).requestFocus(FocusNode());
                      // no-op: textarea is below
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lifeGoalsCtrl,
                maxLines: 4,
                maxLength: 280,
                decoration: const InputDecoration(
                  hintText: 'What are you working toward this year?',
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.of(context).padding.bottom,
            top: 8,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              if (_dirty)
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _dirty && !_saving ? _save : null,
                    child: _saving
                        ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Text('Save changes'),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: _dirty && !_saving ? _confirmDiscard : null,
                  child: const Text('Discard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDiscard() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved edits. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton.tonal(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.pop(context);
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _VerifyChip extends StatelessWidget {
  final bool verified;
  final VoidCallback? onTap;
  const _VerifyChip({required this.verified, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: ShapeDecoration(
          color: verified ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest,
          shape: StadiumBorder(
            side: BorderSide(
              color: verified ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              verified ? Icons.verified_rounded : Icons.shield_outlined,
              size: 16,
              color: verified ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              verified ? 'Verified' : 'Verify',
              style: theme.textTheme.labelSmall?.copyWith(
                color: verified ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledRow extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _LabeledRow({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _DobField extends StatelessWidget {
  final DateTime? dob;
  final VoidCallback onTap;
  const _DobField({required this.dob, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final age = _calcAge(dob);
    final text = dob == null
        ? 'Select date'
        : '${DateFormat('dd MMM yyyy').format(dob!)}${age != null ? '  •  $age' : ''}';
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text)),
            const Icon(Icons.calendar_month_outlined),
          ],
        ),
      ),
    );
  }

  int? _calcAge(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }
}

class _GenderSegment extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _GenderSegment({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final options = const [
      'Female',
      'Male',
      'Prefer not to say',
    ];
    return Wrap(
      spacing: 8,
      children: options.map((opt) {
        final selected = value == opt;
        return ChoiceChip(
          label: Text(opt),
          selected: selected,
          onSelected: (_) => onChanged(opt),
        );
      }).toList(),
    );
  }
}
