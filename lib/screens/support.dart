import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Help & Support screen
/// - Contact Us form with pre-filled, read-only Name & Email
/// - Message (multiline, required, 10-2000 chars)
/// - Submit shows success/error toast (SnackBar)
/// - Privacy note
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});
  static const routeName = '/help';

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  bool _sending = false;

  static const int _minLen = 10;
  static const int _maxLen = 2000;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
    _messageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  bool get _isValidLength {
    final len = _messageCtrl.text.trim().length;
    return len >= _minLen && len <= _maxLen;
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _sending = true);

    try {
      // TODO: Wire this up to your backend / Firestore / Cloud Function / email service
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Message sent. We'll reply within 2-3 business days.")),
      );
      _messageCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't send your message. Please try again.")),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Section(
                  title: 'Contact Us',
                  icon: Icons.support_agent_outlined,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailCtrl,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _messageCtrl,
                        maxLines: 6,
                        minLines: 4,
                        maxLength: _maxLen,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          alignLabelWithHint: true,
                          hintText: 'How can we help? Provide a few details…',
                          prefixIcon: Icon(Icons.chat_outlined),
                        ),
                        validator: (v) {
                          final txt = (v ?? '').trim();
                          if (txt.isEmpty) return 'Please enter a message';
                          if (txt.length < _minLen) return 'Minimum $_minLen characters';
                          if (txt.length > _maxLen) return 'Maximum $_maxLen characters';
                          return null;
                        },
                      ),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.privacy_tip_outlined, size: 18, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'We use this information only to respond to your request.',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (!_sending && _isValidLength) ? _submit : null,
                          icon: _sending
                              ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Icon(Icons.send_rounded),
                          label: const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.icon, required this.child});
  final String title; final IconData icon; final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: cs.primary),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    title,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 12),
            child,
          ],
        ),
    );
  }
}
