import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/media_url_helper.dart';
import '../../../../core/utils/share_helper.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/datasources/join_datasource.dart';
import '../../domain/entities/event.dart';
import '../bloc/events_bloc.dart';
import '../widgets/join_event_modal.dart';

class EventDetailsPage extends StatefulWidget {
  final String eventId;
  const EventDetailsPage({super.key, required this.eventId});

  @override
  State<EventDetailsPage> createState() => _EventDetailsPageState();
}

class _EventDetailsPageState extends State<EventDetailsPage> {
  String? _registrationStatus;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    context.read<EventsBloc>().add(LoadEventDetails(widget.eventId));
    _checkRegistrationStatus();
  }

  Future<void> _checkRegistrationStatus() async {
    final authState = context.read<AuthBloc>().state;
    if (authState.status != AuthStatus.authenticated || authState.user == null) return;
    try {
      final ds = JoinDataSource(getIt<ApiClient>());
      final result = await ds.getRegistrationStatus(widget.eventId);
      if (mounted) {
        setState(() {
          _registrationStatus = result['registered'] == true
              ? (result['status'] as String? ?? 'confirmed')
              : null;
        });
      }
    } catch (_) {}
  }

  bool _isOnline(Event e) {
    // Prefer the backend field; fallback to heuristic for old events
    if (e.isOnline) return true;
    final t = e.eventType.toLowerCase();
    return t.contains('online') || t.contains('virtual') ||
        t.contains('webinar') || (e.meetingUrl != null && e.meetingUrl!.isNotEmpty);
  }

  String _detectPlatform(Event e) {
    if (e.meetingPlatform != null && e.meetingPlatform!.isNotEmpty) return e.meetingPlatform!;
    final url = (e.meetingUrl ?? '').toLowerCase();
    if (url.contains('zoom')) return 'Zoom';
    if (url.contains('meet.google')) return 'Google Meet';
    if (url.contains('teams')) return 'Microsoft Teams';
    return 'Online';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? KhairColors.darkBackground : KhairColors.background;
    final cardBg = isDark ? KhairColors.darkCard : KhairColors.surface;
    final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final tt = isDark ? KhairColors.darkTextTertiary : KhairColors.textTertiary;

    return Scaffold(
      backgroundColor: bg,
      // ── STICKY BOTTOM BAR via bottomNavigationBar ──
      bottomNavigationBar: BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) {
          if (state.selectedEvent == null) return const SizedBox.shrink();
          final event = state.selectedEvent!;
          return _buildBottomBar(event, isDark, bg, bdr);
        },
      ),
      body: BlocBuilder<EventsBloc, EventsState>(
        builder: (context, state) {
          if (state.detailsStatus == EventsStatus.loading) {
            return Center(child: CircularProgressIndicator(color: KhairColors.primary));
          }
          if (state.detailsStatus == EventsStatus.failure || state.selectedEvent == null) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: tt),
                const SizedBox(height: 16),
                Text(context.l10n.eventNotFound, style: TextStyle(color: ts, fontSize: 15)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.go('/'),
                    child: Text(context.l10n.eventDetailsBack)),
              ],
            ));
          }

          final event = state.selectedEvent!;
          final online = _isOnline(event);

          return CustomScrollView(
            slivers: [
              // ═══ 1. HERO APP BAR ═══
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: isDark ? KhairColors.darkSurface : KhairColors.surface,
                leading: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    onPressed: () => context.go('/'),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsetsDirectional.only(end: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                      onPressed: () => _shareEvent(context, event),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: isDark ? KhairColors.darkSurface : KhairColors.neutral200,
                    child: Column(
                      children: [
                        Expanded(child: _buildEventImage(event)),
                        // Bottom gradient with info
                      ],
                    ),
                  ),
                ),
              ),

              // ═══ CONTENT ═══
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + badges
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges row
                          Row(children: [
                            _badge(
                              icon: online ? Icons.videocam_rounded : Icons.location_on_rounded,
                              label: online ? 'ONLINE' : event.eventType.toUpperCase(),
                              color: online ? KhairColors.primary : KhairColors.islamicGreen,
                            ),
                            const SizedBox(width: 8),
                            _badge(
                              icon: Icons.people_rounded,
                              label: context.l10n.eventDetailsAttending(event.reservedCount),
                              color: isDark ? KhairColors.darkSurfaceVariant : KhairColors.neutral200,
                              textColor: tp,
                            ),
                          ]),
                          const SizedBox(height: 14),
                          // Title
                          Text(event.title,
                            style: TextStyle(color: tp, fontSize: 24,
                                fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.3),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ═══ 2. QUICK INFO CARDS ═══
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        Expanded(child: _infoCard(
                          isDark, cardBg, bdr,
                          Icons.calendar_today_rounded, KhairColors.primary,
                          context.l10n.eventDetailsDateTime, tt,
                          DateFormat('EEE, MMM d').format(event.startDate), tp,
                          DateFormat('hh:mm a').format(event.startDate) +
                              (event.endDate != null ? ' – ${DateFormat('hh:mm a').format(event.endDate!)}' : ''),
                          ts,
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _infoCard(
                          isDark, cardBg, bdr,
                          online ? Icons.videocam_rounded : Icons.location_on_rounded,
                          online ? KhairColors.primary : KhairColors.islamicGreen,
                          online ? 'Platform' : context.l10n.eventDetailsLocation, tt,
                          online ? _detectPlatform(event) : (event.city ?? event.country ?? 'TBA'), tp,
                          online ? 'Virtual Event' : (event.address ?? ''), ts,
                        )),
                      ]),
                    ),

                    const SizedBox(height: 20),

                    // ═══ 3. ACTION SECTION ═══
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: online
                          ? _onlineActionCard(event, isDark, cardBg, bdr, tp, ts, tt)
                          : _inPersonActionCard(event, isDark, cardBg, bdr, tp, ts, tt),
                    ),

                    // ═══ PAYMENT INFO ═══
                    if (event.ticketPrice != null && event.ticketPrice! > 0) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _sectionCard(isDark, cardBg, bdr, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(Icons.payments_rounded, context.l10n.eventDetailsPaymentInfo, tp),
                            const SizedBox(height: 14),
                            // Price display
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: KhairColors.primarySurface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: KhairColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.attach_money_rounded,
                                      color: KhairColors.primary, size: 24),
                                ),
                                const SizedBox(width: 14),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(context.l10n.eventDetailsTicketPrice,
                                        style: TextStyle(color: tt, fontSize: 11, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${event.ticketPrice!.toStringAsFixed(event.ticketPrice! % 1 == 0 ? 0 : 2)} ${event.currency ?? 'USD'}',
                                      style: TextStyle(color: tp, fontSize: 22, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                )),
                              ]),
                            ),
                            const SizedBox(height: 12),
                            // Pay at location note
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.amber.withValues(alpha: 0.1) : const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                              ),
                              child: Row(children: [
                                Icon(Icons.info_outline_rounded, color: Colors.amber[700], size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text(
                                  context.l10n.eventDetailsPayAtLocation,
                                  style: TextStyle(color: Colors.amber[800], fontSize: 13, height: 1.4),
                                )),
                              ]),
                            ),
                          ],
                        )),
                      ),
                    ],

                    // ═══ 4. ABOUT ═══
                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _sectionCard(isDark, cardBg, bdr, child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(Icons.info_outline_rounded, context.l10n.eventDetailsAbout, tp),
                            const SizedBox(height: 14),
                            Text(event.description!,
                                style: TextStyle(color: ts, fontSize: 14, height: 1.7)),
                            if (event.eventType.isNotEmpty || event.language != null) ...[
                              const SizedBox(height: 16),
                              Wrap(spacing: 8, runSpacing: 8, children: [
                                _chip(event.eventType, isDark, KhairColors.primary),
                                if (event.language != null)
                                  _chip(event.language!, isDark, KhairColors.islamicGreen),
                              ]),
                            ],
                          ],
                        )),
                      ),
                    ],

                    // ═══ 5. ORGANIZER ═══
                    if (event.organizerName != null) ...[
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _sectionCard(isDark, cardBg, bdr, child: Row(children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: KhairColors.primarySurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(child: Text(
                              event.organizerName![0].toUpperCase(),
                              style: TextStyle(color: KhairColors.primary, fontSize: 20, fontWeight: FontWeight.w700),
                            )),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.l10n.eventDetailsOrganizedBy, style: TextStyle(
                                  color: tt, fontSize: 11, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Row(children: [
                                Flexible(child: Text(event.organizerName!, style: TextStyle(
                                    color: tp, fontSize: 15, fontWeight: FontWeight.w600))),
                                const SizedBox(width: 6),
                                Icon(Icons.verified_rounded, color: KhairColors.primary, size: 16),
                              ]),
                            ],
                          )),
                        ])),
                      ),
                    ],

                    // ═══ 6. ATTENDEES ═══
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _attendeesCard(event, isDark, cardBg, bdr, tp, ts),
                    ),

                    // Bottom padding
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  BOTTOM BAR (via Scaffold.bottomNavigationBar)
  // ═══════════════════════════════════════════════════
  Widget _buildBottomBar(Event event, bool isDark, Color bg, Color border) {
    final isPast = (event.endDate ?? event.startDate).isBefore(DateTime.now());
    final isFull = event.capacity != null && event.reservedCount >= event.capacity!;
    final isJoined = _registrationStatus != null;

    String label;
    Color btnColor;
    IconData btnIcon;
    bool disabled;

    if (isPast) {
      label = context.l10n.eventDetailsEventEnded;
      btnColor = KhairColors.neutral400;
      btnIcon = Icons.event_busy_rounded;
      disabled = true;
    } else if (isJoined) {
      label = context.l10n.eventDetailsAlreadyJoinedBtn;
      btnColor = KhairColors.success;
      btnIcon = Icons.check_circle_rounded;
      disabled = true;
    } else if (isFull) {
      label = context.l10n.eventDetailsSoldOut;
      btnColor = KhairColors.neutral400;
      btnIcon = Icons.event_busy_rounded;
      disabled = true;
    } else {
      label = context.l10n.eventDetailsJoin;
      btnColor = KhairColors.primary;
      btnIcon = Icons.event_available_rounded;
      disabled = false;
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          // Capacity info
          if (event.capacity != null && !isPast)
            Expanded(flex: 2, child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFull
                      ? context.l10n.eventDetailsSoldOut
                      : context.l10n.eventDetailsSeatsLeft(event.capacity! - event.reservedCount),
                  style: TextStyle(
                    color: isFull ? KhairColors.error : KhairColors.success,
                    fontSize: 13, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: event.capacity! > 0
                        ? (event.reservedCount / event.capacity!).clamp(0.0, 1.0) : 0,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(isFull ? KhairColors.error : KhairColors.primary),
                    minHeight: 4,
                  ),
                ),
              ],
            )),
          if (event.capacity != null && !isPast) const SizedBox(width: 14),

          // Bookmark
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: _isSaved ? KhairColors.primary : (isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary),
                size: 22,
              ),
              onPressed: () => setState(() => _isSaved = !_isSaved),
            ),
          ),
          const SizedBox(width: 12),

          // Join CTA
          Expanded(flex: 3, child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: disabled ? null
                  : () => _handleJoinTap(context, event.id, event.title),
              icon: Icon(btnIcon, size: 20),
              label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: btnColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: btnColor.withValues(alpha: 0.6),
                disabledForegroundColor: Colors.white70,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: disabled ? 0 : 2,
              ),
            ),
          )),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ONLINE ACTION CARD
  // ═══════════════════════════════════════════════════
  Widget _onlineActionCard(Event event, bool isDark,
      Color cardBg, Color bdr, Color tp, Color ts, Color tt) {
    final platform = _detectPlatform(event);
    final isJoined = _registrationStatus != null;
    final now = DateTime.now();
    final unlockTime = event.startDate.subtract(
      Duration(minutes: event.joinLinkVisibleBeforeMinutes),
    );
    final isLinkUnlocked = now.isAfter(unlockTime);
    final hasOnlineLink = event.onlineLink != null && event.onlineLink!.isNotEmpty;
    // Fallback to meetingUrl for backward compat
    final linkToUse = hasOnlineLink ? event.onlineLink! : (event.meetingUrl ?? '');
    final hasLink = linkToUse.isNotEmpty;
    final isLive = now.isAfter(event.startDate) &&
        (event.endDate == null || now.isBefore(event.endDate!));
    final isPast = (event.endDate ?? event.startDate).isBefore(now);

    return _sectionCard(isDark, cardBg, bdr, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with LIVE badge
        Row(children: [
          Expanded(child: _sectionHeader(
            Icons.videocam_rounded,
            isLive ? 'Live Now' : 'Join Online',
            tp,
          )),
          if (isLive && !isPast)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: KhairColors.error,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text('LIVE', style: TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: 0.5,
                )),
              ]),
            )
          else if (!isPast)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: KhairColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(platform, style: TextStyle(
                color: KhairColors.primary, fontSize: 11, fontWeight: FontWeight.w700,
              )),
            ),
        ]),
        const SizedBox(height: 14),

        // ── STATE: Not joined yet ──
        if (!isJoined && !isPast)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: KhairColors.primarySurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: KhairColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'Join this event to access the online meeting link.',
                style: TextStyle(color: KhairColors.primary, fontSize: 13, height: 1.4),
              )),
            ]),
          ),

        // ── STATE: Joined but link locked ──
        if (isJoined && !isLinkUnlocked && !isPast) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.amber.withValues(alpha: 0.1) : const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.lock_clock_rounded, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    'Link available ${event.joinLinkVisibleBeforeMinutes} minutes before start',
                    style: TextStyle(color: Colors.amber[800], fontSize: 13, fontWeight: FontWeight.w600),
                  )),
                ]),
                const SizedBox(height: 12),
                // Countdown
                _buildCountdown(event.startDate, isDark, tp, ts),
              ],
            ),
          ),
        ],

        // ── STATE: Joined and link unlocked ──
        if (isJoined && isLinkUnlocked && !isPast && hasLink) ...[
          // Link display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: bdr),
            ),
            child: Row(children: [
              Icon(Icons.link_rounded, color: tt, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(linkToUse, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: KhairColors.primary, fontSize: 13, fontWeight: FontWeight.w500))),
            ]),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _launchUrl(linkToUse),
              icon: Icon(isLive ? Icons.play_circle_filled_rounded : Icons.open_in_new_rounded, size: 18),
              label: Text(isLive ? 'Join Now' : 'Open Link',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLive ? KhairColors.error : KhairColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            )),
            const SizedBox(width: 10),
            _iconButton(bdr, Icons.copy_rounded, () {
              Clipboard.setData(ClipboardData(text: linkToUse));
              _showSnack('Link copied!');
            }),
          ]),
        ],

        // ── STATE: Joined, unlocked, but no link available ──
        if (isJoined && isLinkUnlocked && !hasLink && !isPast)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: KhairColors.warningLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: KhairColors.warning, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('The organizer hasn\'t shared the meeting link yet.',
                  style: TextStyle(color: KhairColors.warning, fontSize: 13))),
            ]),
          ),

        // ── Join instructions ──
        if (event.joinInstructions != null && event.joinInstructions!.isNotEmpty && isJoined) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.sticky_note_2_rounded, color: ts, size: 16),
                  const SizedBox(width: 8),
                  Text('Instructions', style: TextStyle(
                    color: tp, fontSize: 12, fontWeight: FontWeight.w700,
                  )),
                ]),
                const SizedBox(height: 8),
                Text(event.joinInstructions!,
                    style: TextStyle(color: ts, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],

        // ── Event ended ──
        if (isPast)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : KhairColors.neutral100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.event_busy_rounded, color: ts, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('This event has ended.',
                  style: TextStyle(color: ts, fontSize: 13))),
            ]),
          ),
      ],
    ));
  }

  /// Builds a countdown to event start time
  Widget _buildCountdown(DateTime startDate, bool isDark, Color tp, Color ts) {
    final now = DateTime.now();
    final diff = startDate.difference(now);

    if (diff.isNegative) return const SizedBox.shrink();

    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    return Row(children: [
      if (days > 0) _countdownUnit(days.toString(), 'days', isDark, tp, ts),
      if (days > 0) const SizedBox(width: 8),
      _countdownUnit(hours.toString().padLeft(2, '0'), 'hrs', isDark, tp, ts),
      const SizedBox(width: 8),
      _countdownUnit(minutes.toString().padLeft(2, '0'), 'min', isDark, tp, ts),
    ]);
  }

  Widget _countdownUnit(String value, String label, bool isDark, Color tp, Color ts) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(color: tp, fontSize: 18, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(color: ts, fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // ═══════════════════════════════════════════════════
  //  IN-PERSON ACTION CARD
  // ═══════════════════════════════════════════════════
  Widget _inPersonActionCard(Event event, bool isDark,
      Color cardBg, Color bdr, Color tp, Color ts, Color tt) {
    final displayAddress = event.fullAddress ?? event.address;
    final cityCountry = [event.city, event.country].where((e) => e != null).join(', ');
    final hasCoords = event.latitude != null && event.longitude != null;

    return Column(children: [
      // Map placeholder — tap to open Google Maps
      if (hasCoords) ...[
        GestureDetector(
          onTap: () => _openDirections(event.latitude!, event.longitude!, event.address),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A2332) : const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: bdr),
            ),
            child: Center(child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on_rounded, color: KhairColors.primary, size: 36),
                const SizedBox(height: 8),
                Text('Tap to open in Maps',
                    style: TextStyle(color: KhairColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            )),
          ),
        ),
        const SizedBox(height: 12),
      ],
      // Location card
      _sectionCard(isDark, cardBg, bdr, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(Icons.location_on_rounded, context.l10n.eventDetailsLocation, tp),
          if (cityCountry.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(cityCountry, style: TextStyle(color: ts, fontSize: 13))),
          if (displayAddress != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: bdr),
              ),
              child: Row(children: [
                Icon(Icons.pin_drop_rounded, color: tt, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(displayAddress, style: TextStyle(
                    color: tp, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4))),
              ]),
            ),
          ],
          if (displayAddress == null && !hasCoords) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: KhairColors.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: KhairColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text('Exact location will be announced soon.',
                    style: TextStyle(color: KhairColors.warning, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 14),
          Row(children: [
            if (hasCoords)
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _openDirections(event.latitude!, event.longitude!, event.address),
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: Text(context.l10n.eventDetailsGetDirections,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KhairColors.primary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              )),
            if (hasCoords && displayAddress != null) const SizedBox(width: 10),
            if (displayAddress != null)
              _iconButton(bdr, Icons.copy_rounded, () {
                Clipboard.setData(ClipboardData(text: displayAddress));
                _showSnack('Address copied!');
              }),
          ]),
        ],
      )),
    ]);
  }

  // ═══════════════════════════════════════════════════
  //  ATTENDEES CARD
  // ═══════════════════════════════════════════════════
  Widget _attendeesCard(Event event, bool isDark, Color cardBg, Color bdr, Color tp, Color ts) {
    final count = event.reservedCount;
    final isFull = event.capacity != null && count >= event.capacity!;

    return _sectionCard(isDark, cardBg, bdr, child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.people_rounded, color: KhairColors.primary, size: 22),
          const SizedBox(width: 10),
          Text('Attendees', style: TextStyle(color: tp, fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isFull ? KhairColors.errorLight : KhairColors.primarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              event.capacity != null ? '$count / ${event.capacity}' : '$count',
              style: TextStyle(
                color: isFull ? KhairColors.error : KhairColors.primary,
                fontSize: 13, fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (count > 0) ...[
          // Colored circles
          Wrap(spacing: -10, runSpacing: 4, children: List.generate(
            count.clamp(0, 6), (i) => Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: [KhairColors.primary, const Color(0xFF7C3AED), const Color(0xFFDB2777),
                  KhairColors.islamicGreen, const Color(0xFFD97706), const Color(0xFF0891B2)][i % 6],
                shape: BoxShape.circle,
                border: Border.all(color: cardBg, width: 2),
              ),
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
            ),
          )),
          if (count > 6)
            Padding(padding: const EdgeInsets.only(top: 8),
              child: Text('+${count - 6} more attending', style: TextStyle(color: ts, fontSize: 13))),
        ],
        if (count == 0)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.emoji_people_rounded, color: KhairColors.primary, size: 22),
              const SizedBox(width: 12),
              Text('Be the first to join!', style: TextStyle(color: tp, fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
    ));
  }

  // ═══════════════════════════════════════════════════
  //  SHARED HELPERS
  // ═══════════════════════════════════════════════════

  Widget _sectionCard(bool isDark, Color bg, Color border, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget _sectionHeader(IconData icon, String title, Color color) {
    return Row(children: [
      Icon(icon, color: KhairColors.primary, size: 22),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w700)),
    ]);
  }

  Widget _infoCard(bool isDark, Color bg, Color border,
      IconData icon, Color iconColor, String label, Color labelColor,
      String title, Color titleColor, String sub, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(height: 12),
        Text(label, style: TextStyle(color: labelColor, fontSize: 11,
            fontWeight: FontWeight.w600, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: titleColor, fontSize: 14,
            fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (sub.isNotEmpty) Text(sub, style: TextStyle(color: subColor, fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _badge({required IconData icon, required String label,
      required Color color, Color textColor = Colors.white}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: textColor, size: 13),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: textColor, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      ]),
    );
  }

  Widget _chip(String label, bool isDark, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _iconButton(Color border, IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, color: KhairColors.primary, size: 20),
        onPressed: onTap,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      ),
    );
  }

  // ═══════════════════════════════════════════════════
  //  IMAGE
  // ═══════════════════════════════════════════════════
  Widget _buildEventImage(Event event) {
    final url = resolveMediaUrl(event.imageUrl);
    if (url.isNotEmpty) {
      return Image.network(url, fit: BoxFit.cover, width: double.infinity,
          errorBuilder: (_, __, ___) => _placeholder(event.eventType));
    }
    return _placeholder(event.eventType);
  }

  Widget _placeholder([String? type]) {
    final t = (type ?? '').toLowerCase();
    final colors = t.contains('quran') || t.contains('recit')
        ? [const Color(0xFF1B4332), const Color(0xFF40916C)]
        : t.contains('masjid') || t.contains('mosque')
        ? [const Color(0xFF166534), const Color(0xFF22C55E)]
        : [const Color(0xFF1E3A5F), const Color(0xFF3B82F6)];
    final icon = t.contains('quran') ? Icons.menu_book_rounded
        : t.contains('masjid') || t.contains('mosque') ? Icons.mosque_rounded
        : t.contains('lecture') ? Icons.school_rounded
        : t.contains('charity') ? Icons.volunteer_activism_rounded
        : Icons.event_rounded;

    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
      child: Center(child: Icon(icon, size: 80, color: Colors.white.withValues(alpha: 0.12))),
    );
  }

  // ═══════════════════════════════════════════════════
  //  ACTIONS
  // ═══════════════════════════════════════════════════

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _launchUrl(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      _showSnack('Could not open link');
    }
  }

  Future<void> _openDirections(double lat, double lng, String? address) async {
    await _launchUrl('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
  }

  Future<void> _shareEvent(BuildContext ctx, Event event) async {
    const baseUrl = 'https://khair.it.com';
    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.get('/events/${event.id}/share');
      final data = response.data['data'] ?? response.data;
      final publicUrl = data['public_url'] ?? '$baseUrl/events/${event.id}';
      final title = data['title'] ?? event.title;
      final organizer = data['organizer'] ?? '';
      final description = data['description'] ?? '';
      final sb = StringBuffer();
      sb.writeln('🌿 $title');
      if (organizer.isNotEmpty) sb.writeln('📋 By $organizer');
      if (description.isNotEmpty) {
        sb.writeln(description.length > 100 ? '${description.substring(0, 100)}...' : description);
      }
      sb.writeln();
      sb.write('Join on Khair: $publicUrl');
      if (!ctx.mounted) return;
      await ShareHelper.share(ctx, sb.toString());
    } catch (_) {
      if (!ctx.mounted) return;
      await ShareHelper.share(ctx, '🌿 Check out "${event.title}" on Khair!\n$baseUrl/events/${event.id}');
    }
  }

  void _handleJoinTap(BuildContext ctx, String eventId, String title) {
    final authState = ctx.read<AuthBloc>().state;
    if (authState.status != AuthStatus.authenticated || authState.user == null) {
      showJoinEventModal(ctx, eventId, title);
      return;
    }
    _joinDirectly(ctx, eventId, title);
  }

  Future<void> _joinDirectly(BuildContext ctx, String eventId, String title) async {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        const SizedBox(width: 12),
        Text(context.l10n.eventDetailsJoining),
      ]),
      duration: const Duration(seconds: 10),
    ));

    try {
      final ds = JoinDataSource(getIt<ApiClient>());
      await ds.joinEvent(eventId);
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white),
          const SizedBox(width: 12),
          Text(context.l10n.eventDetailsReservedSuccess),
        ]),
        backgroundColor: KhairColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ));
      ctx.read<EventsBloc>().add(LoadEventDetails(eventId));
      setState(() => _registrationStatus = 'confirmed');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      String errorMsg = context.l10n.eventDetailsJoinFailed;
      String srvMsg = '';
      if (e is DioException && e.response?.data != null) {
        final d = e.response!.data;
        if (d is Map) srvMsg = (d['message'] ?? d['error'] ?? '').toString();
      }
      if (srvMsg.isEmpty) srvMsg = e.toString();
      if (srvMsg.contains('already')) errorMsg = context.l10n.eventDetailsAlreadyJoined;
      else if (srvMsg.contains('full') || srvMsg.contains('capacity') || srvMsg.contains('booked'))
        errorMsg = context.l10n.eventDetailsEventFull;
      else if (srvMsg.isNotEmpty && !srvMsg.contains('DioException')) errorMsg = srvMsg;

      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(errorMsg)),
        ]),
        backgroundColor: KhairColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}
