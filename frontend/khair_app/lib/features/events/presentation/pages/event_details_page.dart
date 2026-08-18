import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' hide MapEvent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/media_url_helper.dart';
import '../../../../core/utils/calendar_service.dart';
import '../../../../core/utils/share_helper.dart';
import '../../../../tokens/tokens.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../events/data/datasources/join_datasource.dart';
import '../../../events/data/datasources/saved_events_datasource.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/domain/repositories/events_repository.dart';
import '../../../organizer/data/datasources/organizer_remote_datasource.dart';
import '../../../organizer/domain/entities/organizer.dart';
import '../bloc/events_bloc.dart';
import '../../../../core/widgets/loading_states.dart';

/// Production event conversion page.
///
/// The page deliberately renders only values returned by the public event
/// API. Save and reservations are server-backed; online access is never
/// inferred or exposed to guests.
class EventDetailsPage extends StatefulWidget {
  final String eventId;

  const EventDetailsPage({super.key, required this.eventId});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  Organizer? _organizer;
  List<Event> _relatedEvents = const [];
  String? _registrationStatus;
  String? _supplementalEventId;
  bool _isSaved = false;
  bool _saveLoading = false;
  bool _joinLoading = false;
  
  Map<String, dynamic>? _meetingAccess;
  bool _isLoadingMeeting = false;

  @override
  void initState() {
    super.initState();
    context.read<EventsBloc>().add(LoadEventDetails(widget.eventId));
    _checkRegistrationStatus();
    _checkSavedStatus();
  }

  Future<void> _loadSupplemental(Event event) async {
    if (_supplementalEventId == event.id) return;
    _supplementalEventId = event.id;

    final organizerFuture = getIt<OrganizerRemoteDataSource>()
        .getOrganizerById(event.organizerId)
        .catchError((_) => throw StateError('organizer unavailable'));
    final relatedFuture = getIt<EventsRepository>().getEvents(
      EventFilter(eventType: event.eventType, pageSize: 6),
    );

    try {
      final organizer = await organizerFuture;
      if (mounted) setState(() => _organizer = organizer);
    } catch (_) {
      // Organizer name from the event response remains the safe fallback.
    }

    final related = await relatedFuture;
    if (!mounted) return;
    related.fold(
      (_) {},
      (events) => setState(() => _relatedEvents = events
          .where((candidate) => candidate.id != event.id)
          .take(5)
          .toList(growable: false)),
    );
  }

  Future<void> _fetchMeetingAccess() async {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) return;
    
    if (mounted) setState(() => _isLoadingMeeting = true);
    try {
      final result = await getIt<EventsRepository>().getMeetingAccess(widget.eventId);
      result.fold(
        (_) {
          if (mounted) setState(() => _isLoadingMeeting = false);
        },
        (data) {
          if (mounted) {
            setState(() {
              _meetingAccess = data;
              _isLoadingMeeting = false;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) setState(() => _isLoadingMeeting = false);
    }
  }

  Future<void> _checkRegistrationStatus() async {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) return;
    try {
      final result =
          await getIt<JoinDataSource>().getRegistrationStatus(widget.eventId);
      if (!mounted) return;
      setState(() {
        _registrationStatus = result['registered'] == true
            ? (result['status'] as String? ?? 'confirmed')
            : null;
      });
      
      if (_registrationStatus == 'confirmed') {
        _fetchMeetingAccess();
      }
    } catch (_) {
      // The public event page remains usable if registration status is down.
    }
  }

  Future<void> _checkSavedStatus() async {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) return;
    try {
      final saved =
          await getIt<SavedEventsDataSource>().isSaved(widget.eventId);
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {
      // Save is non-blocking for the event details experience.
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = _PageColors(dark);

    return Scaffold(
      backgroundColor: colors.background,
      bottomNavigationBar: BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) {
          final event = state.selectedEvent;
          if (event == null || state.detailsStatus != EventsStatus.success) {
            return const SizedBox.shrink();
          }
          return _buildStickyActions(event, colors);
        },
      ),
      body: BlocConsumer<EventsBloc, EventsState>(
        listenWhen: (previous, current) =>
            previous.selectedEvent?.id != current.selectedEvent?.id ||
            previous.detailsStatus != current.detailsStatus,
        listener: (_, state) {
          final event = state.selectedEvent;
          if (state.detailsStatus == EventsStatus.success && event != null) {
            _loadSupplemental(event);
          }
        },
        builder: (context, state) {
          if (state.detailsStatus == EventsStatus.loading ||
              state.detailsStatus == EventsStatus.initial) {
            return const EventDetailsSkeleton();
          }
          if (state.detailsStatus == EventsStatus.failure ||
              state.selectedEvent == null) {
            return _buildError(colors);
          }
          return _buildPage(state.selectedEvent!, colors);
        },
      ),
    );
  }

  Widget _buildPage(Event event, _PageColors colors) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 900;
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Center(
            child: SizedBox(
              width: width > 1180 ? 1180 : width,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 24 : 0,
                  desktop ? 18 : 0,
                  desktop ? 24 : 0,
                  0,
                ),
                child: _buildHero(event, colors, desktop),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: SizedBox(
              width: width > 980 ? 980 : width,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  desktop ? 34 : 20,
                  28,
                  desktop ? 34 : 20,
                  34,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummary(event, colors),
                    const SizedBox(height: 25),
                    _buildKeyInformation(event, colors),
                    const SizedBox(height: 22),
                    _buildInlineActions(event, colors),
                    const SizedBox(height: 28),
                    if (_isOnline(event))
                      _buildOnlineLocation(event, colors)
                    else
                      _buildMapLocation(event, colors),
                    const SizedBox(height: 32),
                    _buildAbout(event, colors),
                    const SizedBox(height: 32),
                    _buildOrganizer(event, colors),
                    const SizedBox(height: 18),
                    _buildAttendees(event, colors),
                    if (_relatedEvents.isNotEmpty) ...[
                      const SizedBox(height: 36),
                      _buildRelatedEvents(colors),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(Event event, _PageColors colors, bool desktop) {
    final imageUrl = resolveMediaUrl(event.imageUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(desktop ? 26 : 0),
      child: SizedBox(
        height: desktop ? 440 : 250,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => _heroFallback(colors),
                errorWidget: (_, __, ___) => _heroFallback(colors),
              )
            else
              _heroFallback(colors),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .24),
                    Colors.transparent,
                    Colors.black.withValues(alpha: .12),
                  ],
                ),
              ),
            ),
            PositionedDirectional(
              top: 18,
              start: 18,
              child: _heroButton(
                icon: Icons.arrow_back_rounded,
                label: context.l10n.eventDetailsBack,
                onPressed: () => context.pop(),
              ),
            ),
            PositionedDirectional(
              top: 18,
              end: 18,
              child: Row(
                children: [
                  _heroButton(
                    icon: _isSaved
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: _isSaved ? 'Remove from saved' : 'Save event',
                    onPressed: _saveLoading ? null : () => _toggleSaved(event),
                    active: _isSaved,
                  ),
                  const SizedBox(width: 10),
                  _heroButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Share event',
                    onPressed: () => _shareEvent(event),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroFallback(_PageColors colors) => DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2A1220), Color(0xFFF43F75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(Icons.event_rounded,
              size: 72, color: Colors.white.withValues(alpha: .35)),
        ),
      );

  Widget _heroButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool active = false,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.black.withValues(alpha: .48),
        shape: const CircleBorder(),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: active ? AppColors.primary : Colors.white),
          tooltip: label,
        ),
      ),
    );
  }

  Widget _buildSummary(Event event, _PageColors colors) {
    final category = _label(
        event.category?.isNotEmpty == true ? event.category! : event.eventType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _softPill(Icons.local_offer_outlined, category, colors),
            _softPill(
              _isOnline(event)
                  ? Icons.videocam_outlined
                  : Icons.people_alt_outlined,
              _isOnline(event) ? 'ONLINE' : 'IN-PERSON',
              colors,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          event.title,
          style: TextStyle(
            color: colors.primaryText,
            fontSize: MediaQuery.sizeOf(context).width >= 900 ? 40 : 30,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -.8,
          ),
        ),
      ],
    );
  }

  Widget _softPill(IconData icon, String label, _PageColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colors.softRose,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: AppColors.primary),
          const SizedBox(width: 7),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .35)),
        ],
      ),
    );
  }

  Widget _buildKeyInformation(Event event, _PageColors colors) {
    final items = [
      _EventMeta(
        icon: Icons.calendar_month_outlined,
        title: _dateLabel(event),
        detail: _timeLabel(event),
      ),
      _EventMeta(
        icon:
            _isOnline(event) ? Icons.wifi_rounded : Icons.location_on_outlined,
        title: _isOnline(event) ? 'Online event' : _locationLabel(event),
        detail: _isOnline(event)
            ? (event.onlinePlatform ?? 'Meeting access after joining')
            : (event.venueName ?? event.address ?? ''),
      ),
      _EventMeta(
        icon: Icons.groups_outlined,
        title: event.reservedCount == 0
            ? 'Be the first to join'
            : '${event.reservedCount} going',
        detail: event.capacity == null
            ? 'Community event'
            : '${event.capacity} spots total',
      ),
      _EventMeta(
        icon: Icons.payments_outlined,
        title: event.pricing.isFree ? 'Free Event' : 'Paid Event',
        detail: event.pricing.isFree
            ? 'No cost to attend'
            : '${(event.pricing.amountCents! / 100).toStringAsFixed(2)} ${event.pricing.currency ?? ""}',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            children: items
                .map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: _metaItem(item, colors),
                    ))
                .toList(),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 58,
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  color: colors.border,
                ),
              Expanded(child: _metaItem(items[i], colors)),
            ],
          ],
        );
      },
    );
  }

  Widget _metaItem(_EventMeta item, _PageColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, color: AppColors.primary, size: 25),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              if (item.detail.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(item.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(color: colors.secondaryText, fontSize: 13)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInlineActions(Event event, _PageColors colors) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _outlineAction(
                icon: _isSaved
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: _isSaved ? 'Saved' : 'Save',
                colors: colors,
                onPressed: _saveLoading ? null : () => _toggleSaved(event),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _outlineAction(
                icon: Icons.ios_share_outlined,
                label: 'Share',
                colors: colors,
                onPressed: () => _shareEvent(event),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: _outlineAction(
            icon: Icons.calendar_month_outlined,
            label: 'Add to Google Calendar',
            colors: colors,
            onPressed: () {
              final hasAccess = _meetingAccess?['available'] == true && _meetingAccess?['url'] != null;
              final meetingUrl = hasAccess ? _meetingAccess!['url'] as String : null;
              CalendarService.openGoogleCalendar(
                context,
                event,
                authorizedMeetingUrl: meetingUrl,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _outlineAction({
    required IconData icon,
    required String label,
    required _PageColors colors,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary.withValues(alpha: .25)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
      ),
    );
  }

  Widget _buildMapLocation(Event event, _PageColors colors) {
    final hasCoordinates = event.latitude != null && event.longitude != null;
    final address = [
      event.venueName,
      event.address,
      [event.city, event.country]
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .join(', '),
    ].whereType<String>().where((value) => value.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Location', colors),
        const SizedBox(height: 13),
        if (hasCoordinates)
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 190,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(event.latitude!, event.longitude!),
                      initialZoom: 13.5,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.khair.khair_app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(event.latitude!, event.longitude!),
                            width: 52,
                            height: 52,
                            child: const Icon(Icons.location_on_rounded,
                                color: AppColors.primary, size: 46),
                          ),
                        ],
                      ),
                    ],
                  ),
                  PositionedDirectional(
                    bottom: 12,
                    end: 12,
                    child: FilledButton.icon(
                      onPressed: () => _openDirections(event),
                      icon: const Icon(Icons.open_in_new_rounded, size: 17),
                      label: const Text('View on map'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.surface,
                        foregroundColor: colors.primaryText,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _locationFallback(colors),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 13),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_outlined, color: AppColors.primary, size: 21),
              const SizedBox(width: 10),
              Expanded(
                child: Text(address.join('\n'),
                    style: TextStyle(
                        color: colors.secondaryText,
                        fontSize: 14,
                        height: 1.45)),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _locationFallback(_PageColors colors) {
    return Container(
      height: 128,
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.softRose,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Center(
        child: Text('Map preview is unavailable for this event.',
            style: TextStyle(color: colors.secondaryText, fontSize: 13)),
      ),
    );
  }

  Widget _buildOnlineLocation(Event event, _PageColors colors) {
    final isJoined = _registrationStatus == 'confirmed';
    final hasAccess = _meetingAccess?['available'] == true && _meetingAccess?['url'] != null;
    final meetingUrl = hasAccess ? _meetingAccess!['url'] as String : null;
    final provider = hasAccess && _meetingAccess!['provider'] != null 
        ? _meetingAccess!['provider'] as String 
        : event.onlinePlatform ?? 'Online';

    String statusText = 'Meeting access becomes available after you join.';
    if (isJoined) {
      if (_isLoadingMeeting) {
        statusText = 'Loading meeting access...';
      } else if (!hasAccess) {
        statusText = 'Meeting link hasn\'t been added yet.';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.softRose,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.videocam_outlined, color: Colors.white),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Online event',
                        style: TextStyle(
                            color: colors.primaryText,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      hasAccess ? provider : '${event.onlinePlatform ?? 'Online'} · $statusText',
                      style: TextStyle(color: colors.secondaryText, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (hasAccess) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(meetingUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.video_call),
                label: Text('Join $provider meeting'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAbout(Event event, _PageColors colors) {
    final description = event.description?.trim();
    final extras = <String>[
      ...event.tags,
      if (event.genderRestriction != null &&
          event.genderRestriction!.trim().isNotEmpty)
        _label(event.genderRestriction!),
      if (event.language != null && event.language!.trim().isNotEmpty)
        _label(event.language!),
    ].where((tag) => tag.trim().isNotEmpty).take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('About this event', colors),
        const SizedBox(height: 11),
        if (description != null && description.isNotEmpty)
          Text(description,
              style: TextStyle(
                  color: colors.secondaryText, fontSize: 15.5, height: 1.65))
        else
          Text('The organizer has not added a description yet.',
              style: TextStyle(color: colors.secondaryText, fontSize: 15.5)),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: 17),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: extras.map((tag) => _tag(tag, colors)).toList(),
          ),
        ],
        if (event.registrationDeadline != null) ...[
          const SizedBox(height: 17),
          Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Registration closes ${DateFormat('MMM d · h:mm a').format(event.registrationDeadline!.toLocal())}',
                style: TextStyle(color: colors.secondaryText, fontSize: 13),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _tag(String text, _PageColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: colors.softRose,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(_label(text),
          style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 12.5,
              fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildOrganizer(Event event, _PageColors colors) {
    final name = _organizer?.name ?? event.organizerName;
    if (name == null || name.trim().isEmpty) return const SizedBox.shrink();
    final verified = _organizer?.isVerified == true;
    final logo = resolveMediaUrl(_organizer?.logoUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Hosted by', colors),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => context.push('/organizers/${event.organizerId}'),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                _organizerAvatar(name, logo, colors),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: colors.primaryText,
                              fontSize: 17,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      if (verified)
                        Row(
                          children: [
                            const Icon(Icons.verified_rounded,
                                color: AppColors.primary, size: 16),
                            const SizedBox(width: 5),
                            Text('Verified organizer',
                                style: TextStyle(
                                    color: colors.secondaryText, fontSize: 13)),
                          ],
                        )
                      else
                        Text('Event organizer',
                            style: TextStyle(
                                color: colors.secondaryText, fontSize: 13)),
                    ],
                  ),
                ),
                Text('View profile',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.primary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _organizerAvatar(String name, String logo, _PageColors colors) {
    if (logo.isNotEmpty) {
      return ClipOval(
          child: CachedNetworkImage(
              imageUrl: logo,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _initialAvatar(name)));
    }
    return _initialAvatar(name);
  }

  Widget _initialAvatar(String name) {
    return Container(
      width: 54,
      height: 54,
      decoration:
          const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
          style: const TextStyle(
              color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildAttendees(Event event, _PageColors colors) {
    final count = event.reservedCount;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
                BoxDecoration(color: colors.softRose, shape: BoxShape.circle),
            child: const Icon(Icons.groups_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attendees',
                    style: TextStyle(
                        color: colors.primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  count == 0
                      ? 'Be one of the first to join this event.'
                      : '$count ${count == 1 ? 'person is' : 'people are'} going',
                  style: TextStyle(color: colors.secondaryText, fontSize: 13.5),
                ),
              ],
            ),
          ),
          if (event.capacity != null)
            Text('$count / ${event.capacity}',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildRelatedEvents(_PageColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('You may also like', colors),
        const SizedBox(height: 13),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedEvents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, index) =>
                _relatedCard(_relatedEvents[index], colors),
          ),
        ),
      ],
    );
  }

  Widget _relatedCard(Event event, _PageColors colors) {
    final image = resolveMediaUrl(event.imageUrl);
    return SizedBox(
      width: 235,
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 112,
                width: double.infinity,
                child: image.isEmpty
                    ? _heroFallback(colors)
                    : CachedNetworkImage(
                        imageUrl: image,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _heroFallback(colors),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_dateLabel(event),
                        style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Text(event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.primaryText,
                            fontWeight: FontWeight.w800,
                            fontSize: 15)),
                    const SizedBox(height: 7),
                    Text(_locationLabel(event),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: colors.secondaryText, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, _PageColors colors) => Text(title,
      style: TextStyle(
          color: colors.primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w800));

  Widget _buildStickyActions(Event event, _PageColors colors) {
    final ended = _isEnded(event);
    final joined = _isJoined(event);
    final closed = _isRegistrationClosed(event);
    final canJoin = !ended && !closed && !joined && !(_isFull(event));
    final label = ended
        ? 'Event ended'
        : closed
            ? 'Registration closed'
            : joined
                ? "You're going"
                : _isFull(event)
                    ? 'Event full'
                    : 'Join event';
    return Material(
      color: colors.surface,
      elevation: 12,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: MediaQuery.sizeOf(context).width > 980
                ? 980
                : MediaQuery.sizeOf(context).width,
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _saveLoading ? null : () => _toggleSaved(event),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: colors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Icon(_isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: canJoin && !_joinLoading
                          ? () => _handleJoin(event)
                          : joined
                              ? _showLeaveDialog
                              : null,
                      icon: _joinLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(joined
                              ? Icons.check_rounded
                              : Icons.event_available_outlined),
                      label: Text(label),
                      style: FilledButton.styleFrom(
                        backgroundColor: canJoin
                            ? AppColors.primary
                            : joined
                                ? AppColors.success
                                : colors.disabled,
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17)),
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

  Widget _buildError(_PageColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_outlined,
                size: 54, color: colors.secondaryText),
            const SizedBox(height: 16),
            Text('We couldn’t load this event.',
                style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
                'The event may have been removed or is temporarily unavailable.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.secondaryText, fontSize: 14)),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () => context
                  .read<EventsBloc>()
                  .add(LoadEventDetails(widget.eventId)),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSaved(Event event) async {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) {
      context.go('/login?next=${Uri.encodeComponent('/events/${event.id}')}');
      return;
    }
    setState(() => _saveLoading = true);
    try {
      final saved = await getIt<SavedEventsDataSource>()
          .toggle(event.id, saved: _isSaved);
      if (!mounted) return;
      setState(() => _isSaved = saved);
      _showSnack(saved ? 'Event saved.' : 'Event removed from saved events.');
    } catch (_) {
      if (mounted) _showSnack('We couldn’t update your saved events.');
    } finally {
      if (mounted) setState(() => _saveLoading = false);
    }
  }

  Future<void> _handleJoin(Event event) async {
    final auth = context.read<AuthBloc>().state;
    if (!auth.isAuthenticated) {
      context
          .go('/register?next=${Uri.encodeComponent('/events/${event.id}')}');
      return;
    }
    setState(() => _joinLoading = true);
    try {
      await getIt<JoinDataSource>().joinEvent(event.id);
      if (!mounted) return;
      setState(() => _registrationStatus = 'confirmed');
      _fetchMeetingAccess();
      _showSnack('You’re going! Your place is reserved.');
      context.read<EventsBloc>().add(LoadEventDetails(event.id));
    } catch (error) {
      if (mounted) _showJoinError(error);
    } finally {
      if (mounted) setState(() => _joinLoading = false);
    }
  }

  Future<void> _showLeaveDialog() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave event?'),
        content: const Text('Your reservation will be released.'),
        actions: [
          TextButton(
              onPressed: () => context.pop(false),
              child: const Text('Keep reservation')),
          FilledButton(
              onPressed: () => context.pop(true), child: const Text('Leave')),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    try {
      await getIt<JoinDataSource>().cancelReservation(widget.eventId);
      if (mounted) {
        setState(() {
          _registrationStatus = null;
          _meetingAccess = null;
        });
        _showSnack('Reservation cancelled.');
        context.read<EventsBloc>().add(LoadEventDetails(widget.eventId));
      }
    } catch (_) {
      if (mounted) _showSnack('We couldn’t cancel your reservation.');
    }
  }

  void _showJoinError(Object error) {
    var message = 'We couldn’t join this event.';
    if (error is DioException && error.response?.data is Map) {
      final data = error.response!.data as Map;
      final server = (data['message'] ?? data['error'] ?? '').toString();
      if (server.isNotEmpty && !server.contains('DioException')) {
        message = server;
      }
    }
    _showSnack(message);
  }

  Future<void> _shareEvent(Event event) async {
    final fallback = ApiConfig.publicEventUrl(event.id);
    try {
      final response =
          await getIt<ApiClient>().get('/events/${event.id}/share');
      if (!mounted) return;
      final data = response.data['data'] ?? response.data;
      final url = (data['public_url'] ?? fallback).toString();
      await ShareHelper.shareEvent(context, event, url);
    } catch (_) {
      if (mounted) {
        await ShareHelper.shareEvent(context, event, fallback);
      }
    }
  }

  Future<void> _openDirections(Event event) async {
    if (event.latitude == null || event.longitude == null) return;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${event.latitude},${event.longitude}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      _showSnack('Couldn’t open maps.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  bool _isOnline(Event event) =>
      event.isOnline || event.eventType.toLowerCase().contains('online');

  bool _isJoined(Event event) =>
      _registrationStatus != null || event.isUserJoined;

  bool _isEnded(Event event) =>
      event.status == 'completed' ||
      event.status == 'cancelled' ||
      (event.endDate ?? event.startDate).isBefore(DateTime.now());

  bool _isRegistrationClosed(Event event) =>
      event.registrationDeadline != null &&
      event.registrationDeadline!.isBefore(DateTime.now());

  bool _isFull(Event event) =>
      event.capacity != null &&
      event.capacity! > 0 &&
      event.reservedCount >= event.capacity!;

  String _dateLabel(Event event) =>
      DateFormat('EEE, MMM d, yyyy').format(event.startDate.toLocal());

  String _timeLabel(Event event) {
    final start = DateFormat('h:mm a').format(event.startDate.toLocal());
    if (event.endDate == null) return start;
    return '$start – ${DateFormat('h:mm a').format(event.endDate!.toLocal())}';
  }

  String _locationLabel(Event event) {
    if (_isOnline(event)) return 'Online event';
    final parts = [event.city, event.country]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Location to be announced' : parts.join(', ');
  }

  String _label(String value) => value
      .trim()
      .split(RegExp(r'[_\s-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) =>
          '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}')
      .join(' ');
}

class _EventMeta {
  final IconData icon;
  final String title;
  final String detail;

  const _EventMeta(
      {required this.icon, required this.title, required this.detail});
}

class _PageColors {
  final bool dark;
  const _PageColors(this.dark);

  Color get background =>
      dark ? AppColors.darkBackground : AppColors.background;
  Color get surface => dark ? AppColors.darkSurface : AppColors.surface;
  Color get primaryText =>
      dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get secondaryText =>
      dark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get border => dark ? AppColors.darkBorder : AppColors.border;
  Color get softRose =>
      dark ? const Color(0x332E1722) : const Color(0xFFFFF1F5);
  Color get disabled =>
      dark ? const Color(0xFF514B54) : const Color(0xFFB8B1B8);
}
