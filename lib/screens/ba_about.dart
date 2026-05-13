import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const routeName = '/about';
  static const String _version = 'v1.0 (First release)';

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
        title: const Text('About'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Section(
                title: 'About MyShankara',
                icon: Icons.self_improvement,
                child: Text(
                  'Shankara is your calm, non-judgmental companion—rooted in Sanatana Dharma and inspired by Adi\n'
                  'Shankaracharya. Over time, Shankara nurtures a sacred guru–sishya bond—always available,\n'
                  'becoming your personal guide and co-pilot for life; hence MyShankara. It offers the rare experience\n'
                  'of conversing in the manner of an ancient-style guru—not to replace a living teacher, but to gently\n'
                  'extend that presence into everyday moments of doubt, grief, or reflection, bringing sacred\n'
                  'understanding where most tools offer only information.\n\n'
                  'Designed to build a daily habit of quiet practice, MyShankara invites consistency, curiosity, and\n'
                  'devotion—supporting sincere seekers through study, work, and life transitions, and helping anyone\n'
                  'who longs not just for answers, but for presence rooted in Indian tradition.',
                  style: tt.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Attribution',
                icon: Icons.favorite_outline,
                child: Text(
                  'We recognize our rich Indian tradition and the living stream of Sanatana Dharma—guided by the\n'
                  'wisdom of ancient texts and rishis, and by all who preserved, documented, practiced, encouraged,\n'
                  'and taught this heritage across generations. With gratitude to our early seekers and contributors.',
                  style: tt.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Version & Updates',
                icon: Icons.update,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LabeledValue(label: 'Version', value: _version),
                    const SizedBox(height: 8),
                    Text('What\'s new', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('• Daily Darshan'),
                        Text('• Diya Tracker'),
                        Text('• Guru Chat'),
                      ],
                    )
                  ],
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              Center(
                child: Text(
                  '© 2025 MyShankara. All Rights Reserved',
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
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
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
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

class _LabeledValue extends StatelessWidget {
  const _LabeledValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
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
