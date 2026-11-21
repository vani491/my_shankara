import 'package:flutter/material.dart';

import '../services/app_update_service.dart';

Future<void> showUpdateDialog(BuildContext context, UpdateCheckResult r) {
  final force = r.type == UpdateType.force;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: !force,
    barrierLabel: 'Update',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (ctx, _, __) => PopScope(
      canPop: !force, // block Android back button on force update
      child: _UpdateDialog(result: r, force: force),
    ),
    transitionBuilder: (_, anim, __, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.result, required this.force});

  final UpdateCheckResult result;
  final bool force;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = force ? cs.error : cs.primary;

    return Center(
      child: Material(
        color: cs.surface,
        elevation: 8,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0.06)],
                    ),
                  ),
                  child: Icon(
                    force ? Icons.system_update_rounded : Icons.rocket_launch_rounded,
                    size: 38,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  force ? 'Update Required' : 'New Update Available',
                  textAlign: TextAlign.center,
                  style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (result.latestVersion != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Version ${result.latestVersion}',
                      style: text.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  force
                      ? 'This version is no longer supported. Please update to continue using the app.'
                      : 'A newer version with improvements and fixes is ready. Update now for the best experience.',
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      AppUpdateService.instance.openStore();
                      // Force: keep dialog open so it is still there on return.
                      if (!force) Navigator.of(context).pop();
                    },
                    child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                if (!force) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Maybe Later',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
