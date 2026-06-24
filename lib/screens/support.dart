import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Contact Support screen
/// - Name & Email: editable, auto-filled for signed-in users when available
/// - Message: multi-line, required, with character count
/// - Guests can use it fully (no sign-in required)
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});
  static const routeName = '/support';

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
    // Auto-fill if available, but keep editable
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

  bool get _canSend {
    final nameOk = _nameCtrl.text.trim().isNotEmpty;
    final emailOk = _isValidEmail(_emailCtrl.text.trim());
    final len = _messageCtrl.text.trim().length;
    final msgOk = len >= _minLen && len <= _maxLen;
    return nameOk && emailOk && msgOk;
  }

  bool _isValidEmail(String v) {
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    return re.hasMatch(v);
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    setState(() => _sending = true);
    try {
      // TODO: Wire to backend / Firestore / email service
      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your message has been received with gratitude. '
                'We will respond soon.',
          ),
        ),
      );
      _messageCtrl.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't send your message. Please try again."),
        ),
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
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title:  Text('Contact Support',  style: tt.titleLarge),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Hero icon ──
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primary,
                        cs.primary.withValues(alpha: 0.85),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.support_agent_outlined,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Subtitle ──
                Text(
                  'We are here to help with your questions, feedback, or '
                      'account support.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Form card ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                    Border.all(color: cs.outline.withValues(alpha: 0.18)),
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
                      _label(context, 'Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        decoration: _decoration(
                          context,
                          hint: 'Your name',
                          icon: Icons.person_outline,
                        ),
                        validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Please enter your name'
                            : null,
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      _label(context, 'Email'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          context,
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                        ),
                        validator: (v) {
                          final txt = (v ?? '').trim();
                          if (txt.isEmpty) return 'Please enter your email';
                          if (!_isValidEmail(txt)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),

                      _label(context, 'Message'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _messageCtrl,
                        maxLines: 6,
                        minLines: 4,
                        maxLength: _maxLen,
                        decoration: _decoration(
                          context,
                          hint: 'How can we help you?',
                          icon: Icons.chat_outlined,
                          alignLabelWithHint: true,
                        ),
                        validator: (v) {
                          final txt = (v ?? '').trim();
                          if (txt.isEmpty) return 'Please enter a message';
                          if (txt.length < _minLen) {
                            return 'Minimum $_minLen characters';
                          }
                          if (txt.length > _maxLen) {
                            return 'Maximum $_maxLen characters';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.privacy_tip_outlined,
                              size: 16, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'We use this information only to respond to your '
                                  'request.',
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Submit ──
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: (!_sending && _canSend) ? _submit : null,
                    icon: _sending
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(strokeWidth: 2),
                    )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      _sending ? 'Sending…' : 'Send Message',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Text(
      text,
      style: tt.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
    );
  }

  InputDecoration _decoration(
      BuildContext context, {
        required String hint,
        required IconData icon,
        bool alignLabelWithHint = false,
      }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.6),
      ),
    );
  }
}