import 'package:flutter/material.dart';

class ThemeDemoPage extends StatelessWidget {
  const ThemeDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TEXT STYLES SECTION
            // _SectionHeader(title: 'Text Styles'),
            // const SizedBox(height: 16),

            // Display Styles
            const SizedBox(height: 50),
            Text('displayLarge', style: textTheme.displayLarge),
            const SizedBox(height: 8),
            Text('displayMedium', style: textTheme.displayMedium),
            const SizedBox(height: 8),
            Text('displaySmall', style: textTheme.displaySmall),
            const SizedBox(height: 20),

            // Headline Styles
            Text('headlineLarge', style: textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text('headlineMedium', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('headlineSmall', style: textTheme.headlineSmall),
            const SizedBox(height: 20),

            // Title Styles
            Text('titleLarge', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('titleMedium', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('titleSmall', style: textTheme.titleSmall),
            const SizedBox(height: 20),

            // Body Styles
            Text('bodyLarge', style: textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text('bodyMedium', style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text('bodySmall', style: textTheme.bodySmall),
            const SizedBox(height: 20),

            // Label Styles
            Text('labelLarge', style: textTheme.labelLarge),
            const SizedBox(height: 8),
            Text('labelMedium', style: textTheme.labelMedium),
            const SizedBox(height: 8),
            Text('labelSmall', style: textTheme.labelSmall),
            const SizedBox(height: 50),

            // BUTTONS SECTION
            _SectionHeader(title: 'Buttons'),
            const SizedBox(height: 16),

            // FilledButton (uses filledButtonTheme)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {},
                child: const Text('FilledButton'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.star),
                label: const Text('FilledButton with Icon'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('ElevatedButton'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                child: const Text('OutlinedButton'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {},
                child: const Text('TextButton'),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.favorite),
              ),
            ),
            const SizedBox(height: 32),

            // INPUT FIELDS SECTION
            _SectionHeader(title: 'Input Fields'),
            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(
                labelText: 'Label Text',
                hintText: 'Hint text here',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(
                labelText: 'With Prefix Icon',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(
                labelText: 'With Helper Text',
                helperText: 'This is helper text',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(
                labelText: 'Error State',
                errorText: 'This field has an error',
              ),
            ),
            const SizedBox(height: 32),

            // COLOR SCHEME SECTION
            _SectionHeader(title: 'Color Scheme'),
            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ColorChip(label: 'primary', color: colorScheme.primary),
                _ColorChip(label: 'onPrimary', color: colorScheme.onPrimary),
                _ColorChip(label: 'secondary', color: colorScheme.secondary),
                _ColorChip(label: 'onSecondary', color: colorScheme.onSecondary),
                _ColorChip(label: 'surface', color: colorScheme.surface),
                _ColorChip(label: 'onSurface', color: colorScheme.onSurface),
                _ColorChip(label: 'error', color: colorScheme.error),
                _ColorChip(label: 'onError', color: colorScheme.onError),
                _ColorChip(label: 'outline', color: colorScheme.outline),
              ],
            ),
            const SizedBox(height: 32),

            // CARDS SECTION
            _SectionHeader(title: 'Cards & Surfaces'),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Card Title', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      'This is a card with some content inside. Cards use the surface color from the theme.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: colorScheme.outline),
              ),
              child: Text(
                'Surface Container',
                style: textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 32),

            // CHIPS & BADGES
            _SectionHeader(title: 'Chips & Badges'),
            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: const Text('Chip'),
                  onDeleted: () {},
                ),
                ActionChip(
                  label: const Text('Action Chip'),
                  onPressed: () {},
                ),
                FilterChip(
                  label: const Text('Filter Chip'),
                  selected: false,
                  onSelected: (bool value) {},
                ),
                const Badge(
                  label: Text('Badge'),
                  child: Icon(Icons.notifications),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // SWITCHES & CHECKBOXES
            _SectionHeader(title: 'Switches & Checkboxes'),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Switch'),
              value: true,
              onChanged: (bool value) {},
            ),
            CheckboxListTile(
              title: const Text('Checkbox'),
              value: true,
              onChanged: (bool? value) {},
            ),
            RadioListTile<int>(
              title: const Text('Radio Button'),
              value: 1,
              groupValue: 1,
              onChanged: (int? value) {},
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 2,
          ),
        ),
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final Color color;

  const _ColorChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}