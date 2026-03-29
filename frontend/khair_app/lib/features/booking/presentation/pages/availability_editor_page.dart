import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/booking_bloc.dart';

/// Sheikh availability editor — set weekly schedule, slot duration, breaks, and settings.
class AvailabilityEditorPage extends StatefulWidget {
  const AvailabilityEditorPage({super.key});

  @override
  State<AvailabilityEditorPage> createState() => _AvailabilityEditorPageState();
}

class _AvailabilityEditorPageState extends State<AvailabilityEditorPage> {
  static const _days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  // Per-day state
  final Map<int, bool> _enabled = {};
  final Map<int, TimeOfDay> _startTimes = {};
  final Map<int, TimeOfDay> _endTimes = {};
  int _slotDuration = 30;
  int _breakMinutes = 5;

  // Settings
  bool _autoApprove = false;
  bool _prayerBlocking = true;
  final _meetingLinkController = TextEditingController();
  String _platform = 'Zoom';
  String _timezone = 'UTC';

  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    context.read<BookingBloc>().add(const LoadBookingSettings());
  }

  @override
  void dispose() {
    _meetingLinkController.dispose();
    super.dispose();
  }

  void _applyLoadedData(BookingState state) {
    if (_loaded) return;
    _loaded = true;

    // Apply settings
    final settings = state.bookingSettings;
    if (settings != null) {
      _autoApprove = settings['auto_approve'] ?? false;
      _prayerBlocking = settings['prayer_blocking'] ?? true;
      _meetingLinkController.text = settings['default_meeting_link'] ?? '';
      _platform = settings['default_platform'] ?? 'Zoom';
      _timezone = settings['timezone'] ?? 'UTC';
    }

    // Apply availability rules
    for (final rule in state.availabilityRules) {
      final day = rule['day_of_week'] as int? ?? 0;
      _enabled[day] = rule['is_active'] ?? true;
      final startParts = (rule['start_time'] as String? ?? '09:00').split(':');
      final endParts = (rule['end_time'] as String? ?? '17:00').split(':');
      _startTimes[day] = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
      _endTimes[day] = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
      _slotDuration = rule['slot_duration_minutes'] ?? 30;
      _breakMinutes = rule['break_minutes'] ?? 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability & Schedule'),
        actions: [
          TextButton.icon(
            onPressed: _saveAll,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: BlocConsumer<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state.settingsStatus == BookingStatus.success && _loaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Settings saved ✓'), backgroundColor: Colors.green),
            );
          }
          if (!_loaded && state.settingsStatus == BookingStatus.success) {
            setState(() => _applyLoadedData(state));
          }
        },
        builder: (context, state) {
          if (state.settingsStatus == BookingStatus.loading && !_loaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Weekly Schedule ──
              _sectionHeader(theme, Icons.calendar_month, 'Weekly Schedule'),
              const SizedBox(height: 12),
              ...List.generate(7, (i) => _buildDayRow(i, theme, isDark)),

              const SizedBox(height: 12),
              // Slot duration & break
              Row(
                children: [
                  Expanded(child: _buildDropdown('Slot Duration', _slotDuration, [15, 30, 45, 60], (v) {
                    setState(() => _slotDuration = v);
                  }, suffix: 'min')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDropdown('Break Time', _breakMinutes, [0, 5, 10, 15], (v) {
                    setState(() => _breakMinutes = v);
                  }, suffix: 'min')),
                ],
              ),

              const SizedBox(height: 28),
              const Divider(),
              const SizedBox(height: 16),

              // ── Booking Settings ──
              _sectionHeader(theme, Icons.settings, 'Booking Settings'),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text('Auto-Approve Bookings'),
                subtitle: const Text('Instantly confirm student bookings'),
                value: _autoApprove,
                onChanged: (v) => setState(() => _autoApprove = v),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('🕌 Prayer Time Blocking'),
                subtitle: const Text('Automatically block slots during prayer times'),
                value: _prayerBlocking,
                onChanged: (v) => setState(() => _prayerBlocking = v),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),

              const SizedBox(height: 16),

              // Platform
              Text('Default Platform', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Zoom', label: Text('Zoom'), icon: Icon(Icons.videocam)),
                  ButtonSegment(value: 'Google Meet', label: Text('Meet'), icon: Icon(Icons.video_call)),
                  ButtonSegment(value: 'Other', label: Text('Other'), icon: Icon(Icons.link)),
                ],
                selected: {_platform},
                onSelectionChanged: (v) => setState(() => _platform = v.first),
              ),
              const SizedBox(height: 16),

              // Meeting Link
              TextField(
                controller: _meetingLinkController,
                decoration: InputDecoration(
                  labelText: 'Default Meeting Link',
                  hintText: 'https://zoom.us/j/...',
                  prefixIcon: const Icon(Icons.link),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Timezone
              DropdownButtonFormField<String>(
                value: _timezone,
                decoration: InputDecoration(
                  labelText: 'Timezone',
                  prefixIcon: const Icon(Icons.public),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _commonTimezones.map((tz) => DropdownMenuItem(value: tz, child: Text(tz, overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (v) => setState(() => _timezone = v ?? 'UTC'),
              ),
              const SizedBox(height: 32),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saveAll,
                  icon: const Icon(Icons.save),
                  label: const Text('Save All Settings', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDayRow(int day, ThemeData theme, bool isDark) {
    final enabled = _enabled[day] ?? false;
    final start = _startTimes[day] ?? const TimeOfDay(hour: 9, minute: 0);
    final end = _endTimes[day] ?? const TimeOfDay(hour: 17, minute: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: enabled
            ? (isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.primary.withValues(alpha: 0.04))
            : (isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enabled
              ? theme.colorScheme.primary.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Checkbox(
              value: enabled,
              onChanged: (v) => setState(() => _enabled[day] = v ?? false),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              _days[day],
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: enabled ? null : Colors.grey,
              ),
            ),
          ),
          if (enabled) ...[
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _timeButton(start, (t) => setState(() => _startTimes[day] = t), theme),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('–', style: TextStyle(color: Colors.grey.shade500)),
                  ),
                  _timeButton(end, (t) => setState(() => _endTimes[day] = t), theme),
                ],
              ),
            ),
          ] else
            const Expanded(child: Text('  Off', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))),
        ],
      ),
    );
  }

  Widget _timeButton(TimeOfDay time, Function(TimeOfDay) onChanged, ThemeData theme) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, int value, List<int> options, Function(int) onChanged, {String suffix = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: value,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            isDense: true,
          ),
          items: options.map((o) => DropdownMenuItem(value: o, child: Text('$o $suffix'))).toList(),
          onChanged: (v) => onChanged(v ?? value),
        ),
      ],
    );
  }

  void _saveAll() {
    // Build availability rules
    final List<Map<String, dynamic>> rules = [];
    for (int day = 0; day < 7; day++) {
      if (_enabled[day] == true) {
        final start = _startTimes[day] ?? const TimeOfDay(hour: 9, minute: 0);
        final end = _endTimes[day] ?? const TimeOfDay(hour: 17, minute: 0);
        rules.add({
          'day_of_week': day,
          'start_time': '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}',
          'end_time': '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}',
          'slot_duration_minutes': _slotDuration,
          'break_minutes': _breakMinutes,
          'is_active': true,
        });
      }
    }

    // Save availability
    if (rules.isNotEmpty) {
      context.read<BookingBloc>().add(SaveAvailability(rules));
    }

    // Save settings
    context.read<BookingBloc>().add(UpdateBookingSettings({
      'timezone': _timezone,
      'auto_approve': _autoApprove,
      'prayer_blocking': _prayerBlocking,
      'default_meeting_link': _meetingLinkController.text.isNotEmpty ? _meetingLinkController.text : null,
      'default_platform': _platform,
    }));
  }

  static const _commonTimezones = [
    'UTC',
    'Asia/Istanbul',
    'Asia/Riyadh',
    'Asia/Dubai',
    'Asia/Karachi',
    'Asia/Kolkata',
    'Asia/Jakarta',
    'Asia/Kuala_Lumpur',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Paris',
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
    'Africa/Cairo',
    'Africa/Casablanca',
  ];
}
