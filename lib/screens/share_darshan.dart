import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/colors.dart';

class ShareDarshanPage extends StatelessWidget {
  const ShareDarshanPage({super.key});

  // TODO: replace with your real app link (Play Store / App Store / website)
  static const String _appLink = 'https://myshankara.ai';

  static const String _shareMessage =
      "I've been using MyShankara for daily spiritual guidance and reflection. "
      "Thought you may enjoy this journey too 🙏\n\n$_appLink";

  static const String _emailSubject =
      'A spiritual journey I wanted to share 🙏';

  static const String _emailBody =
      "I've been using MyShankara for daily spiritual reflection and guidance. "
      "Thought you may enjoy this journey too 🙏\n\n$_appLink";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title:  Text('Share Darshan', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // ── Subtitle ──
              Text(
                'May this wisdom reach another seeker',
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),

              // ── Decorative icon ──
              Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withValues(alpha: 0.12),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_outlined,
                    color: AppColors.accent,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Preview of the share message ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
                ),
                child: Text(
                  _shareMessage,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Share via WhatsApp ──
              _shareButton(
                context,
                icon: Icons.chat,
                label: 'Share via WhatsApp',
                background: const Color(0xFF25D366),
                foreground: Colors.white,
                onTap: () => _shareViaWhatsApp(context),
              ),
              const SizedBox(height: 14),

              // ── Share via Email ──
              _shareButton(
                context,
                icon: Icons.email_outlined,
                label: 'Share via Email',
                background: AppColors.primary,
                foreground: Colors.white,
                onTap: () => _shareViaEmail(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color background,
        required Color foreground,
        required VoidCallback onTap,
      }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  // ── WhatsApp share ──────────────────────────────────────────────────────
  Future<void> _shareViaWhatsApp(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_shareMessage)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  // ── Email share ─────────────────────────────────────────────────────────
  Future<void> _shareViaEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      query: _encodeQuery({
        'subject': _emailSubject,
        'body': _emailBody,
      }),
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open email app.')),
      );
    }
  }

  // mailto query ko sahi se encode karta hai (spaces, emoji, newlines)
  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) =>
    '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}