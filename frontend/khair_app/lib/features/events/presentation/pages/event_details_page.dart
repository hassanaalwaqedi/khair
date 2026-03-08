import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/datasources/join_datasource.dart';
import '../bloc/events_bloc.dart';
import '../widgets/join_event_modal.dart';

class EventDetailsPage extends StatefulWidget {
  final String eventId;

  const EventDetailsPage({super.key, required this.eventId});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  @override
  void initState() {
    super.initState();
    context.read<EventsBloc>().add(LoadEventDetails(widget.eventId));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) {
          if (state.detailsStatus == EventsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.detailsStatus == EventsStatus.failure ||
              state.selectedEvent == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 64, color: KhairColors.textTertiary),
                  const SizedBox(height: 16),
                  Text('Event not found',
                      style: KhairTypography.bodyMedium
                          .copyWith(color: KhairColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: const Text('Back to Events'),
                  ),
                ],
              ),
            );
          }

          final event = state.selectedEvent!;

          return CustomScrollView(
            slivers: [
              // App bar with image
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => context.go('/'),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Share feature coming soon')),
                        );
                      },
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      event.imageUrl != null
                          ? Image.network(
                              event.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildImagePlaceholder(),
                            )
                          : _buildImagePlaceholder(),
                      // Gradient overlay
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      // Event info overlay
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type badge + attendee count
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: KhairColors.islamicGradient,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    event.eventType.toUpperCase(),
                                    style: KhairTypography.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${event.reservedCount} attending',
                                    style: KhairTypography.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              event.title,
                              style: KhairTypography.h1.copyWith(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date and time
                      _buildInfoCard(
                        context: context,
                        isDark: isDark,
                        icon: Icons.calendar_today,
                        title: 'Date & Time',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM dd, yyyy')
                                  .format(event.startDate),
                              style: KhairTypography.labelLarge.copyWith(
                                color: isDark
                                    ? KhairColors.darkTextPrimary
                                    : KhairColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('hh:mm a').format(event.startDate) +
                                  (event.endDate != null
                                      ? ' - ${DateFormat('hh:mm a').format(event.endDate!)}'
                                      : ''),
                              style: KhairTypography.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Location
                      _buildInfoCard(
                        context: context,
                        isDark: isDark,
                        icon: Icons.location_on,
                        title: 'Location',
                        content: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event.address != null)
                              Text(
                                event.address!,
                                style: KhairTypography.labelLarge.copyWith(
                                  color: isDark
                                      ? KhairColors.darkTextPrimary
                                      : KhairColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (event.city != null || event.country != null)
                              Text(
                                [event.city, event.country]
                                    .where((e) => e != null)
                                    .join(', '),
                                style: KhairTypography.bodyMedium,
                              ),
                          ],
                        ),
                      ),
                      // Map
                      if (event.latitude != null &&
                          event.longitude != null) ...[
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            height: 200,
                            child: FlutterMap(
                              options: MapOptions(
                                initialCenter: LatLng(
                                    event.latitude!, event.longitude!),
                                initialZoom: 14,
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: LatLng(event.latitude!,
                                          event.longitude!),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: KhairColors.primary,
                                        size: 40,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      // Organizer
                      if (event.organizerName != null)
                        _buildInfoCard(
                          context: context,
                          isDark: isDark,
                          icon: Icons.business,
                          title: 'Organized by',
                          content: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: KhairColors.primarySurface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    event.organizerName![0].toUpperCase(),
                                    style: KhairTypography.labelLarge.copyWith(
                                      color: KhairColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                event.organizerName!,
                                style: KhairTypography.labelLarge.copyWith(
                                  color: isDark
                                      ? KhairColors.darkTextPrimary
                                      : KhairColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                      // Description
                      if (event.description != null) ...[
                        Text(
                          'About This Event',
                          style: KhairTypography.headlineSmall.copyWith(
                            color: isDark
                                ? KhairColors.darkTextPrimary
                                : KhairColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          event.description!,
                          style: KhairTypography.bodyLarge.copyWith(
                            color: isDark
                                ? KhairColors.darkTextSecondary
                                : KhairColors.textSecondary,
                            height: 1.7,
                          ),
                        ),
                      ],
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) {
          if (state.selectedEvent == null) return const SizedBox.shrink();
          final event = state.selectedEvent!;
          final isFull = event.capacity != null &&
              event.reservedCount >= event.capacity!;

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Seat counter chip
              if (event.capacity != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFull
                        ? KhairColors.errorLight
                        : KhairColors.successLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFull
                          ? KhairColors.error.withValues(alpha: 0.3)
                          : KhairColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    isFull
                        ? 'Sold Out'
                        : '${event.capacity! - event.reservedCount} seats left',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isFull ? KhairColors.error : KhairColors.success,
                    ),
                  ),
                ),
              // Join button
              FloatingActionButton.extended(
                onPressed: isFull
                    ? null
                    : () => _handleJoinTap(context, event.id, event.title),
                backgroundColor: isFull
                    ? (isDark
                        ? KhairColors.darkSurfaceVariant
                        : KhairColors.neutral400)
                    : KhairColors.primary,
                icon: Icon(
                  isFull
                      ? Icons.event_busy_rounded
                      : Icons.event_available_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  isFull ? 'Sold Out' : 'Join Event',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _handleJoinTap(BuildContext context, String eventId, String eventTitle) {
    final authState = context.read<AuthBloc>().state;

    // Not logged in → show join/register modal
    if (authState.status != AuthStatus.authenticated || authState.user == null) {
      showJoinEventModal(context, eventId, eventTitle);
      return;
    }

    // Logged in → join directly, no confirmation needed
    _joinEventDirectly(context, eventId, eventTitle);
  }

  Future<void> _joinEventDirectly(BuildContext context, String eventId, String eventTitle) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Joining event...'),
          ],
        ),
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final datasource = JoinDataSource(getIt<ApiClient>());
      await datasource.joinEvent(eventId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('You\'re in! Seat reserved successfully.'),
            ],
          ),
          backgroundColor: KhairColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );

      // Reload event details to update attendee count
      context.read<EventsBloc>().add(LoadEventDetails(eventId));

      // Show notification after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '🎉 You\'ve joined "$eventTitle"! See you there.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: KhairColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 4),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      String errorMsg = 'Failed to join event';
      final errStr = e.toString();
      if (errStr.contains('already')) {
        errorMsg = 'You have already joined this event';
      } else if (errStr.contains('full') || errStr.contains('capacity')) {
        errorMsg = 'This event is full';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(errorMsg)),
            ],
          ),
          backgroundColor: KhairColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Widget _buildImagePlaceholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D5B4D),
            Color(0xFF2C8D73),
            Color(0xFF74BBA3),
          ],
        ),
      ),
      child: Center(
        child: Icon(Icons.event,
            size: 80, color: Colors.white.withValues(alpha: 0.54)),
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? KhairColors.darkCard : KhairColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? KhairColors.darkBorder : KhairColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KhairColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: KhairColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: KhairTypography.labelSmall.copyWith(
                    color: KhairColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                content,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
