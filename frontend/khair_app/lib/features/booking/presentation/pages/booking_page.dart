import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/booking_bloc.dart';

/// Student booking page — calendar date picker + time slot grid + booking form.
class BookingPage extends StatefulWidget {
  final String sheikhId;
  final String sheikhName;

  const BookingPage({
    super.key,
    required this.sheikhId,
    required this.sheikhName,
  });

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime _selectedDate = DateTime.now();
  final _notesController = TextEditingController();
  String _selectedPlatform = 'Zoom';

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  void _loadSlots() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    context.read<BookingBloc>().add(LoadAvailableSlots(widget.sheikhId, dateStr));
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Book with ${widget.sheikhName}'),
        elevation: 0,
      ),
      body: BlocConsumer<BookingBloc, BookingState>(
        listener: (context, state) {
          if (state.bookingStatus == BookingStatus.success && state.createdBooking != null) {
            _showConfirmation(context, state.createdBooking!);
          }
          if (state.bookingStatus == BookingStatus.failure && state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Calendar ──
                _buildCalendar(theme, isDark),
                const SizedBox(height: 24),

                // ── Time Slots ──
                Text('Available Times', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildTimeSlots(state, theme, isDark),
                const SizedBox(height: 24),

                // ── Booking Form (visible when slot selected) ──
                if (state.selectedSlot != null) ...[
                  _buildBookingForm(state, theme, isDark),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalendar(ThemeData theme, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 30));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: CalendarDatePicker(
        initialDate: _selectedDate,
        firstDate: today,
        lastDate: maxDate,
        onDateChanged: (date) {
          setState(() => _selectedDate = date);
          _loadSlots();
        },
      ),
    );
  }

  Widget _buildTimeSlots(BookingState state, ThemeData theme, bool isDark) {
    if (state.slotsStatus == BookingStatus.loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }

    if (state.availableSlots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No available slots on this day',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              'Try selecting a different date',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: state.availableSlots.map((slot) {
        final startStr = slot['start_time'] as String? ?? '';
        final isSelected = state.selectedSlot == slot;

        String timeLabel;
        try {
          final dt = DateTime.parse(startStr);
          timeLabel = DateFormat.Hm().format(dt);
        } catch (_) {
          timeLabel = startStr;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ChoiceChip(
            label: Text(
              timeLabel,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : theme.colorScheme.primary,
                fontSize: 15,
              ),
            ),
            selected: isSelected,
            selectedColor: theme.colorScheme.primary,
            backgroundColor: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : theme.colorScheme.primary.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.primary.withValues(alpha: 0.3),
              ),
            ),
            onSelected: (_) {
              context.read<BookingBloc>().add(SelectSlot(slot));
            },
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBookingForm(BookingState state, ThemeData theme, bool isDark) {
    final slot = state.selectedSlot!;
    final startStr = slot['start_time'] as String? ?? '';

    String formattedTime;
    try {
      final dt = DateTime.parse(startStr);
      formattedTime = DateFormat('MMM d, yyyy – h:mm a').format(dt);
    } catch (_) {
      formattedTime = startStr;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.02)]
              : [theme.colorScheme.primary.withValues(alpha: 0.05), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Confirm Booking', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),

          // Selected time display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(formattedTime, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Platform selector
          Text('Meeting Platform', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Zoom', label: Text('Zoom'), icon: Icon(Icons.videocam)),
              ButtonSegment(value: 'Google Meet', label: Text('Meet'), icon: Icon(Icons.video_call)),
              ButtonSegment(value: 'Other', label: Text('Other'), icon: Icon(Icons.link)),
            ],
            selected: {_selectedPlatform},
            onSelectionChanged: (v) => setState(() => _selectedPlatform = v.first),
          ),
          const SizedBox(height: 16),

          // Notes
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'What would you like to learn? (optional)',
              hintText: 'e.g., Tajweed, Quran recitation, Islamic studies...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.note_alt_outlined),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Book button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: state.bookingStatus == BookingStatus.loading ? null : () {
                context.read<BookingBloc>().add(CreateBooking(
                  sheikhId: widget.sheikhId,
                  startTime: startStr,
                  notes: _notesController.text.isNotEmpty ? _notesController.text : null,
                ));
              },
              icon: state.bookingStatus == BookingStatus.loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label: Text(
                state.bookingStatus == BookingStatus.loading ? 'Booking...' : 'Confirm Booking',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmation(BuildContext context, Map<String, dynamic> booking) {
    final theme = Theme.of(context);
    final startStr = booking['start_time'] as String? ?? '';
    String formattedTime;
    try {
      formattedTime = DateFormat('MMM d, yyyy – h:mm a').format(DateTime.parse(startStr));
    } catch (_) {
      formattedTime = startStr;
    }

    final status = booking['status'] as String? ?? 'pending';
    final meetingLink = booking['meeting_link'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              status == 'confirmed' ? 'Lesson Confirmed!' : 'Booking Sent!',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              status == 'confirmed'
                  ? 'Your lesson has been automatically confirmed'
                  : 'The sheikh will review your booking request',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            _confirmRow(Icons.person, 'Sheikh', widget.sheikhName, theme),
            _confirmRow(Icons.schedule, 'Time', formattedTime, theme),
            _confirmRow(Icons.videocam, 'Platform', _selectedPlatform, theme),
            if (meetingLink != null)
              _confirmRow(Icons.link, 'Link', meetingLink, theme),
            _confirmRow(Icons.info_outline, 'Status',
              status == 'confirmed' ? 'Confirmed ✅' : 'Pending ⏳', theme),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to sheikh profile
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _confirmRow(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(color: Colors.grey.shade700))),
        ],
      ),
    );
  }
}
