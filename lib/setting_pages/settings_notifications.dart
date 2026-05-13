// lib/screens/settings_notifications.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotificationsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const SettingsNotificationsScreen({super.key, this.onThemeModeChanged});

  @override
  State<SettingsNotificationsScreen> createState() => _SettingsNotificationsScreenState();
}

class _SettingsNotificationsScreenState extends State<SettingsNotificationsScreen> {
  // Appearance: 0 system, 1 light, 2 dark
  int _appearance = 0;

  // Notifications
  bool _notifEnabled = false;
  TimeOfDay _notifTime = const TimeOfDay(hour: 7, minute: 0); // default 07:00

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
    final p = await SharedPreferences.getInstance();
    await p.setBool(_Keys.notifEnabled, value);
    setState(() => _notifEnabled = value);

    // TODO: schedule/cancel your local notifications here based on [_notifTime].
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

      // TODO: reschedule the daily notification to the new [_notifTime].
    }
  }

  String _formatTime24(BuildContext context, TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Scaffold(
      appBar: AppBar(
          title: const Text('Settings')
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          // Appearance
          Text('Appearance', style: titleStyle),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('System'), icon: Icon(Icons.settings_suggest_outlined)),
              ButtonSegment(value: 1, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: 2, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
            ],
            selected: <int>{_appearance},
            onSelectionChanged: (sel) => _saveAppearance(sel.first),
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // Notifications
          Text('Notifications', style: titleStyle),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            value: _notifEnabled,
            onChanged: _saveNotifEnabled,
            title: const Text('Daily notification'),
            subtitle: const Text('Get a reminder once a day'),
          ),
          const SizedBox(height: 4),
          ListTile(
            enabled: _notifEnabled,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Time'),
            subtitle: Text(_formatTime24(context, _notifTime)), // 24h display
            trailing: const Icon(Icons.chevron_right),
            onTap: _notifEnabled ? _pickNotifTime : null,
          ),

          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'Default time is 07:00 (local). You can choose any time within 24 hours.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Keys {
  static const themeMode = 'settings.themeMode'; // 0 system, 1 light, 2 dark
  static const notifEnabled = 'notif.enabled';
  static const notifHour = 'notif.hour';
  static const notifMinute = 'notif.minute';
}
