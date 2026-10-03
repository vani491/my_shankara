import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../widgets/app_layout.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DARSHAN INTRO — shown from the bottom-nav "Darshan" tab.
// A brief framing screen before the 4-step guided experience; "Begin Darshan"
// from Home skips this and jumps straight into the flow (see RootNav).
// ─────────────────────────────────────────────────────────────────────────────
class DarshanIntroScreen extends StatelessWidget {
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onStart;

  const DarshanIntroScreen({super.key, this.onOpenDrawer, this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppLayout(
      title: 'Daily Darshan',
      onMenuPressed: onOpenDrawer,
      backgroundImage: 'assets/backgrounds/back1.webp',
      backgroundOpacity: 0.35,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.self_improvement_rounded,
                    size: 40,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  "Today's Darshan",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'A short guided journey through a story, its meaning, '
                  'a moment of reflection, and lighting your diya — '
                  'just a few minutes to start your day with intention.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onBackground.withValues(alpha: 0.75),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'Are you ready to start your divine journey?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: onStart,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Start Darshan',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.onAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
}
