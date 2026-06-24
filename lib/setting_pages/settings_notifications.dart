// lib/setting_pages/settings_notifications.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../theme/colors.dart';
import 'package:app_settings/app_settings.dart';
import 'package:fluttertoast/fluttertoast.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const SettingsNotificationsScreen({super.key, this.onThemeModeChanged});

  @override
  State<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState
    extends State<SettingsNotificationsScreen> {

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
      _notifEnabled = p.getBool(_Keys.notifEnabled) ?? false;
      final h = p.getInt(_Keys.notifHour);
      final m = p.getInt(_Keys.notifMinute);
      if (h != null && m != null) {
        _notifTime = TimeOfDay(hour: h, minute: m);
      }
    });
  }

  Future<void> _saveNotifEnabled(bool value) async {
    try {
      if (value) {
        _toast('Step 1: Requesting permissions...');
        final granted = await NotificationService.instance.requestPermissions();
        _toast('Step 1 result: granted=$granted');

        final enabled = await NotificationService.instance.areNotificationsEnabled();
        _toast('Step 2: areNotifEnabled=$enabled');

        if (!granted || !enabled) {
          _toast('BLOCKED: granted=$granted, enabled=$enabled');
          if (mounted) _showBlockedDialog();
          return;
        }

        _toast('Step 3: Calling scheduleWeekly...');
        await NotificationService.instance.scheduleWeekly(
          hour: _notifTime.hour,
          minute: _notifTime.minute,
        );
        _toast('Step 3 done: scheduled!');

        final p = await SharedPreferences.getInstance();
        await p.setBool(_Keys.notifEnabled, true);
        if (mounted) setState(() => _notifEnabled = true);
        _toast('Step 4: COMPLETE ✓');

      } else {
        await NotificationService.instance.cancelAll();
        final p = await SharedPreferences.getInstance();
        await p.setBool(_Keys.notifEnabled, false);
        if (mounted) setState(() => _notifEnabled = false);
        _toast('Notifications OFF');
      }
    } catch (e, stack) {
      _toast('ERROR: $e');
      debugPrint('ERROR: $e\n$stack');
    }
  }

  // Helper
  void _toast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 13.0,
    );
  }

  void _showBlockedDialog() {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notifications are turned off for MyShankara. Enable them in Settings to receive daily reminders.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now' ,  style: TextStyle(
              color: Colors.grey,
            ), ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 2,
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AppSettings.openAppSettings(
                type: AppSettingsType.notification,
              );
            },
            child: const Text('Open Settings',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showExactAlarmDialog() {
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        title: const Text(
          'Allow reminders',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            Text(
              'To deliver your daily reflection on time, MyShankara needs permission to schedule alarms & reminders.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'  ,  style: TextStyle(
              color: Colors.grey,
            ), ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 2,
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);

              await NotificationService.instance.requestExactAlarmPermission();

              final ok = await NotificationService.instance
                  .canScheduleExactAlarms();

              if (ok) {
                await NotificationService.instance.scheduleWeekly(
                  hour: _notifTime.hour,
                  minute: _notifTime.minute,
                );

                final p = await SharedPreferences.getInstance();
                await p.setBool(_Keys.notifEnabled, true);

                if (mounted) {
                  setState(() => _notifEnabled = true);
                }
              }
            },
            child: const Text('Allow',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 15
              ),
            ),
          ),
        ],
      ),
    );
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
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title: Text('Settings', style: theme.textTheme.titleLarge,),
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
