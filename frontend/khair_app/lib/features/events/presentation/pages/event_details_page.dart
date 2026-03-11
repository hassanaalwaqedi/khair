import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/locale/l10n_extension.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/share_helper.dart';
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
                  Text(context.l10n.eventNotFound,
                      style: KhairTypography.bodyMedium
                          .copyWith(color: KhairColors.textSecondary)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.go('/'),
                    child: Text(context.l10n.eventDetailsBack),
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
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined,
                          color: Colors.white),
                      onPressed: () => _shareEvent(context, event),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildEventImage(event),
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
                                    context.l10n.eventDetailsAttending(event.reservedCount),
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
                        title: context.l10n.eventDetailsDateTime,
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
                        title: context.l10n.eventDetailsLocation,
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
                          title: context.l10n.eventDetailsOrganizedBy,
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
                          context.l10n.eventDetailsAbout,
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
                        ? context.l10n.eventDetailsSoldOut
                        : context.l10n.eventDetailsSeatsLeft(event.capacity! - event.reservedCount),
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
                  isFull ? context.l10n.eventDetailsSoldOut : context.l10n.eventDetailsJoin,
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

  Future<void> _shareEvent(BuildContext context, event) async {
    const baseUrl =
        'https://khair.it.com';

    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.get('/events/${event.id}/share');
      final data = response.data['data'] ?? response.data;
      final publicUrl = data['public_url'] ?? '$baseUrl/events/${event.id}';
      final title = data['title'] ?? event.title;
      final organizer = data['organizer'] ?? '';
      final description = data['description'] ?? '';

      final shareText = StringBuffer();
      shareText.writeln('🌿 $title');
      if (organizer.isNotEmpty) shareText.writeln('📋 By $organizer');
      if (description.isNotEmpty) {
        final desc = description.length > 100
            ? '${description.substring(0, 100)}...'
            : description;
        shareText.writeln(desc);
      }
      shareText.writeln();
      shareText.write('Join on Khair: $publicUrl');

      if (!context.mounted) return;
      await ShareHelper.share(context, shareText.toString());
    } catch (e) {
      // Fallback: share a simple text
      if (!context.mounted) return;
      final url = '$baseUrl/api/v1/events/public/${event.id}';
      await ShareHelper.share(
        context,
        '🌿 Check out "${event.title}" on Khair!\n$url',
      );
    }
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
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(context.l10n.eventDetailsJoining),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    try {
      final datasource = JoinDataSource(getIt<ApiClient>());
      await datasource.joinEvent(eventId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text(context.l10n.eventDetailsReservedSuccess),
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
                    context.l10n.eventDetailsJoinedSeeYou(eventTitle),
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
      
      String errorMsg = context.l10n.eventDetailsJoinFailed;
      // Extract the server's error message from DioException
      String serverMsg = '';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          serverMsg = (data['message'] ?? data['error'] ?? '').toString();
        }
      }
      if (serverMsg.isEmpty) {
        serverMsg = e.toString();
      }
      if (serverMsg.contains('already')) {
        errorMsg = context.l10n.eventDetailsAlreadyJoined;
      } else if (serverMsg.contains('full') || serverMsg.contains('capacity') || serverMsg.contains('booked')) {
        errorMsg = context.l10n.eventDetailsEventFull;
      } else if (serverMsg.isNotEmpty && !serverMsg.contains('DioException')) {
        errorMsg = serverMsg;
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

  static const _baseUrl =
      'https://khair.it.com';

  String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return '$_baseUrl$url';
  }

  Widget _buildEventImage(event) {
    final imageUrl = _resolveUrl(event.imageUrl);
    if (imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildImagePlaceholder(event.eventType),
      );
    }
    return _buildImagePlaceholder(event.eventType);
  }

  Widget _buildImagePlaceholder([String? eventType]) {
    final cat = _getCategoryData(eventType ?? '');
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cat.colors,
        ),
      ),
      child: Center(
        child: Icon(cat.icon,
            size: 80, color: Colors.white.withValues(alpha: 0.12)),
      ),
    );
  }

  static _CategoryData _getCategoryData(String eventType) {
    final type = eventType.toLowerCase();
    if (type.contains('quran') || type.contains('recit')) {
      return _CategoryData(
        icon: Icons.menu_book_rounded,
        colors: [const Color(0xFF1A5B4B), const Color(0xFF2D8E75), const Color(0xFF4DB89A)],
      );
    }
    if (type.contains('lecture') || type.contains('know')) {
      return _CategoryData(
        icon: Icons.school_rounded,
        colors: [const Color(0xFF1B4332), const Color(0xFF2D6A4F), const Color(0xFF40916C)],
      );
    }
    if (type.contains('charity') || type.contains('donat')) {
      return _CategoryData(
        icon: Icons.volunteer_activism_rounded,
        colors: [const Color(0xFF4A2040), const Color(0xFF7B3F6B), const Color(0xFFA0588D)],
      );
    }
    if (type.contains('masjid') || type.contains('mosque') || type.contains('prayer')) {
      return _CategoryData(
        icon: Icons.mosque_rounded,
        colors: [const Color(0xFF1A3A5C), const Color(0xFF2C6B97), const Color(0xFF4A90C2)],
      );
    }
    if (type.contains('youth') || type.contains('commun')) {
      return _CategoryData(
        icon: Icons.groups_rounded,
        colors: [const Color(0xFF2D4A22), const Color(0xFF4A7C3F), const Color(0xFF6BA55C)],
      );
    }
    if (type.contains('confer') || type.contains('seminar')) {
      return _CategoryData(
        icon: Icons.mic_rounded,
        colors: [const Color(0xFF3D2E1E), const Color(0xFF6B5240), const Color(0xFF9A7A5F)],
      );
    }
    if (type.contains('workshop') || type.contains('class')) {
      return _CategoryData(
        icon: Icons.auto_stories_rounded,
        colors: [const Color(0xFF1E3A3A), const Color(0xFF2C5E5E), const Color(0xFF4A8B8B)],
      );
    }
    return _CategoryData(
      icon: Icons.event_rounded,
      colors: [const Color(0xFF0D3522), const Color(0xFF14553A), const Color(0xFF1E7A52)],
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

class _CategoryData {
  final IconData icon;
  final List<Color> colors;
  _CategoryData({required this.icon, required this.colors});
}
