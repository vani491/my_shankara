// lib/setting_pages/settings_notifications.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../theme/colors.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const SettingsNotificationsScreen({super.key, this.onThemeModeChanged});

  @override
  State<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends State<SettingsNotificationsScreen> {
  // Appearance: 0 system, 1 light, 2 dark
  int _appearance = 0;

  // Notifications
  bool _notifEnabled = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 7, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _appearance = p.getInt(_Keys.themeMode) ?? 0;
      _notifEnabled = p.getBool(_Keys.notifEnabled) ?? false;
      final h = p.getInt(_Keys.notifHour);
      final m = p.getInt(_Keys.notifMinute);
      if (h != null && m != null) {
        _notifTime = TimeOfDay(hour: h, minute: m);
      }
    });
  }

  Future<void> _saveAppearance(int value) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_Keys.themeMode, value);
    setState(() => _appearance = value);
    widget.onThemeModeChanged?.call(_toThemeMode(value));
  }

  ThemeMode _toThemeMode(int v) {
    switch (v) {
      case 1:
        return ThemeMode.light;
      case 2:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _saveNotifEnabled(bool value) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (value) {
        // Ask OS permission before enabling.
        final granted =
            await NotificationService.instance.requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Notification permission denied. Enable it in system settings.',
                ),
              ),
            );
          }
          return;
        }
        await NotificationService.instance.scheduleWeekly(
          hour: _notifTime.hour,
          minute: _notifTime.minute,
        );
      } else {
        await NotificationService.instance.cancelAll();
      }
      await p.setBool(_Keys.notifEnabled, value);
      setState(() => _notifEnabled = value);
    } catch (e) {
      debugPrint('ERROR: $e');
    }
  }

  Future<void> _pickNotifTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notifTime,
      helpText: 'Daily notification time',
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (ctx, child) {
        // Force 24-hour selection (user can choose any time from 00:00–23:59)
        return MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_Keys.notifHour, picked.hour);
      await p.setInt(_Keys.notifMinute, picked.minute);
      setState(() => _notifTime = picked);
      // Reschedule only if notifications are currently enabled.
      if (_notifEnabled) {
        await NotificationService.instance.scheduleWeekly(
          hour: picked.hour,
          minute: picked.minute,
        );
      }
    }
  }

  String _formatTime24(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Section header ──────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Notifications',
                    style: tt.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Settings card ───────────────────────────────────────
              Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle row
                    SwitchListTile.adaptive(
                      contentPadding:
                          const EdgeInsets.fromLTRB(16, 10, 14, 10),
                      value: _notifEnabled,
                      onChanged: _saveNotifEnabled,
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _notifEnabled
                              ? AppColors.accent.withValues(alpha: 0.12)
                              : cs.outlineVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.notifications_active_outlined,
                          color: _notifEnabled
                              ? AppColors.accent
                              : cs.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Daily notification',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'A gentle daily reminder from Shankara',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),

                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),

                    // Time row
                    InkWell(
                      onTap: _notifEnabled ? _pickNotifTime : null,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _notifEnabled
                                    ? AppColors.primary.withValues(alpha: 0.08)
                                    : cs.outlineVariant.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.schedule_outlined,
                                color: _notifEnabled
                                    ? AppColors.primary
                                    : cs.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reminder time',
                                    style: tt.bodyMedium?.copyWith(
                                      color: _notifEnabled
                                          ? cs.onSurface
                                          : cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _notifEnabled
                                        ? 'Tap to change'
                                        : 'Enable notifications first',
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Time chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _notifEnabled
                                    ? AppColors.accent.withValues(alpha: 0.10)
                                    : cs.outlineVariant.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _notifEnabled
                                      ? AppColors.accent.withValues(alpha: 0.35)
                                      : cs.outline.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                _formatTime24(_notifTime),
                                style: TextStyle(
                                  color: _notifEnabled
                                      ? AppColors.accent
                                      : cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: _notifEnabled
                                  ? cs.onSurfaceVariant
                                  : cs.outline,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Caption ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Default time is 07:00 (local). You can choose any time within 24 hours.',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keys {
  static const themeMode = 'settings.themeMode'; // 0 system, 1 light, 2 dark
  static const notifEnabled = 'notifications_enabled';
  static const notifHour = 'notif_hour';
  static const notifMinute = 'notif_minute';
}
