import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const routeName = '/about';
  static const String _version = 'v1.0 — First Release';

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
        title: Text('About', style: tt.titleLarge),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Brand hero ──────────────────────────────────────────────
              Container(
                width: 88,
                height: 88,
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
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.self_improvement,
                  color: Colors.white,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'MyShankara',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _version,
                  style: tt.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── About MyShankara ────────────────────────────────────────
              _Section(
                title: 'About MyShankara',
                icon: Icons.auto_awesome_outlined,
                child: Text(
                  'MyShankara is a calm, non-judgmental companion rooted in the '
                      'wisdom of Sanatana Dharma and inspired by Adi Shankaracharya.\n\n'
                      'Over time, MyShankara nurtures a quiet guru–sishya bond — '
                      'becoming a personal guide for reflection, clarity, and everyday '
                      'life.\n\n'
                      'It offers the rare experience of conversing in the spirit of an '
                      'ancient-style guru — not to replace a living teacher, but to '
                      'gently extend that presence into moments of doubt, grief, '
                      'confusion, or inner seeking.\n\n'
                      'Designed to encourage daily spiritual practice, MyShankara '
                      'supports sincere seekers through study, work, relationships, and '
                      'life transitions — offering not just answers, but presence rooted '
                      'in Indian wisdom traditions.',
                  style: tt.bodyMedium?.copyWith(
                    height: 1.6,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),

              // ── Attribution ─────────────────────────────────────────────
              _Section(
                title: 'Attribution',
                icon: Icons.favorite_outline,
                child: Text(
                  'With reverence to the timeless wisdom of Sanatana Dharma, the '
                      'ancient rishis, sacred texts, teachers, practitioners, and all who '
                      'preserved and carried this living tradition across generations.\n\n'
                      'With gratitude to our early seekers and contributors.',
                  style: tt.bodyMedium?.copyWith(
                    height: 1.6,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ),

              // ── Version & Updates ───────────────────────────────────────
              _Section(
                title: 'Version & Updates',
                icon: Icons.update,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledValue(label: 'Version', value: _version),
                    const SizedBox(height: 16),
                    Text(
                      'Features',
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _feature(context, Icons.wb_twilight_outlined, 'Daily Darshan'),
                    _feature(context, Icons.local_fire_department_outlined,
                        'Diya Tracker'),
                    _feature(
                        context, Icons.chat_bubble_outline, 'Guru Chat'),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              Text(
                '© 2026 MyShankara. All rights reserved.',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feature(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: cs.secondary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: cs.outline.withValues(alpha: 0.18)),
        borderRadius: BorderRadius.circular(18),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  title,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    fontSize: 18
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      children: [
        Text(
          '$label: ',
          style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        Flexible(
          child: Text(
            value,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}