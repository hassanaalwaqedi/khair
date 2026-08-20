import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../data/datasources/organizer_hub_datasource.dart';

/// Production organizer overview. The page renders only the server aggregate
/// returned by /organizer/dashboard; it never manufactures events or metrics.
class OrganizerHubPage extends StatefulWidget {
  const OrganizerHubPage({super.key});

  @override
  State<OrganizerHubPage> createState() => _OrganizerHubPageState();
}

class _OrganizerHubPageState extends State<OrganizerHubPage> {
  final _dataSource = getIt<OrganizerHubDataSource>();
  Map<String, dynamic>? _dashboard;
  Object? _error;
  bool _loading = true;
  String _range = '30d';
  DateTime? _customStart;
  DateTime? _customEnd;
  int _eventTab = 0;
  String _performanceMetric = 'views';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({String? range}) async {
    final selected = range ?? _range;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _range = selected;
      });
    }
    try {
      final dashboard = await _dataSource.getDashboard(
        range: selected,
        start: selected == 'custom' ? _customStart : null,
        end: selected == 'custom' ? _customEnd : null,
      );
      if (!mounted) return;
      setState(() => _dashboard = dashboard);
    } catch (error) {
      if (!mounted) return;
      if (error is DioException) {
        if (error.response?.statusCode == 403) {
          context.go('/organizer/apply');
          return;
        }
        if (error.response?.statusCode == 401) {
          context.go('/login?next=${Uri.encodeComponent('/organizer')}');
          return;
        }
      }
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseCustomRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: now.subtract(Duration(days: 29)), end: now),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: _HubColors.rose,
                onPrimary: Colors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (result == null) return;
    _customStart =
        DateTime(result.start.year, result.start.month, result.start.day);
    _customEnd =
        DateTime(result.end.year, result.end.month, result.end.day, 23, 59, 59);
    await _load(range: 'custom');
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? _HubColors.darkBackground : _HubColors.background;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: _dashboard == null
            ? _error != null
                ? _ErrorState(
                    message: _friendlyError(_error!),
                    onRetry: _load,
                  )
                : Center(
                    child: CircularProgressIndicator(color: _HubColors.rose),
                  )
            : RefreshIndicator(
                color: _HubColors.rose,
                onRefresh: _load,
                child: CustomScrollView(
                  physics: AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 1240),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 54),
                            child: _HubContent(
                              dashboard: _dashboard!,
                              range: _range,
                              eventTab: _eventTab,
                              performanceMetric: _performanceMetric,
                              refreshing: _loading,
                              onRangeChanged: (range) => range == 'custom'
                                  ? _chooseCustomRange()
                                  : _load(range: range),
                              onEventTabChanged: (tab) =>
                                  setState(() => _eventTab = tab),
                              onPerformanceMetricChanged: (metric) =>
                                  setState(() => _performanceMetric = metric),
                              onCreateEvent: () =>
                                  context.push('/organizer/events/create'),
                              onManageEvents: () =>
                                  context.push('/organizer/events'),
                              onProfile: () =>
                                  context.push('/organizer/profile'),
                              onNotifications: () =>
                                  context.push('/notifications'),
                              onAttendees: _showAttendees,
                              onSendUpdate: _showAnnouncement,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Future<void> _showAttendees(Map<String, dynamic> event) async {
    final organizer = _asMap(_dashboard?['organizer']);
    try {
      final attendees = await _dataSource.getAttendees(
        organizationId: _asString(organizer['id']),
        eventId: _asString(event['id']),
      );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AttendeeSheet(
          eventTitle: _asString(event['title'], fallback: 'Event'),
          attendees: attendees,
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  Future<void> _showAnnouncement(Map<String, dynamic> event) async {
    final draft = await showDialog<_AnnouncementDraft>(
      context: context,
      builder: (_) => _AnnouncementDialog(
        eventTitle: _asString(event['title'], fallback: 'your event'),
      ),
    );
    if (draft == null) return;
    try {
      await _dataSource.sendAnnouncement(
        eventId: _asString(event['id']),
        title: draft.title,
        message: draft.message,
        type: draft.type,
      );
      if (!mounted) return;
      _showMessage('Update saved and queued for confirmed attendees.');
      await _load();
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HubContent extends StatelessWidget {
  const _HubContent({
    required this.dashboard,
    required this.range,
    required this.eventTab,
    required this.performanceMetric,
    required this.refreshing,
    required this.onRangeChanged,
    required this.onEventTabChanged,
    required this.onPerformanceMetricChanged,
    required this.onCreateEvent,
    required this.onManageEvents,
    required this.onProfile,
    required this.onNotifications,
    required this.onAttendees,
    required this.onSendUpdate,
  });

  final Map<String, dynamic> dashboard;
  final String range;
  final int eventTab;
  final String performanceMetric;
  final bool refreshing;
  final ValueChanged<String> onRangeChanged;
  final ValueChanged<int> onEventTabChanged;
  final ValueChanged<String> onPerformanceMetricChanged;
  final VoidCallback onCreateEvent;
  final VoidCallback onManageEvents;
  final VoidCallback onProfile;
  final VoidCallback onNotifications;
  final ValueChanged<Map<String, dynamic>> onAttendees;
  final ValueChanged<Map<String, dynamic>> onSendUpdate;

  @override
  Widget build(BuildContext context) {
    final organizer = _asMap(dashboard['organizer']);
    final metrics = _asMap(dashboard['metrics']);
    final events = _asMap(dashboard['events']);
    final attention = _asList(dashboard['attention']);
    final performance = _asList(dashboard['performance']);
    final activity = _asList(dashboard['activity']);
    final upcoming = _asList(events['upcoming']);
    final displayName = _asString(organizer['name'], fallback: 'organizer');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HubTopBar(
          organizer: displayName,
          logoUrl: _nullableString(organizer['logo_url']),
          onNotifications: onNotifications,
          onProfile: onProfile,
        ),
        SizedBox(height: 42),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final intro = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_timeGreeting(context)}, $displayName 👋',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _HubColors.rose,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SizedBox(height: 8),
                Text(
                  context.l10n.organizerHub,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.1,
                      ),
                ),
                SizedBox(height: 10),
                Text(
                  _summaryText(context, metrics, range),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: _muted(context),
                      ),
                ),
              ],
            );
            final action = FilledButton.icon(
              key: Key('organizer-create-event'),
              onPressed: onCreateEvent,
              icon: Icon(Icons.add_rounded, size: 20),
              label: Text(context.l10n.createEvent1),
              style: FilledButton.styleFrom(
                backgroundColor: _HubColors.rose,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            );
            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, SizedBox(height: 20), action],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [Expanded(child: intro), action],
            );
          },
        ),
        SizedBox(height: 30),
        _RangeSelector(selected: range, onChanged: onRangeChanged),
        SizedBox(height: 18),
        _MetricsGrid(metrics: metrics),
        SizedBox(height: 34),
        _SectionHeading(
          title: context.l10n.yourNextEvent,
          action: upcoming.isEmpty ? null : 'View all events',
          onAction: onManageEvents,
        ),
        SizedBox(height: 14),
        if (dashboard['next_event'] is Map)
          _NextEventCard(
            event: _asMap(dashboard['next_event']),
            onManage: onManageEvents,
            onAttendees: onAttendees,
            onSendUpdate: onSendUpdate,
          )
        else
          _NoNextEventCard(onCreateEvent: onCreateEvent),
        SizedBox(height: 34),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 930;
            final eventPanel = _EventsPanel(
              events: events,
              selectedTab: eventTab,
              onTabChanged: onEventTabChanged,
              onManage: onManageEvents,
              onAttendees: onAttendees,
              onSendUpdate: onSendUpdate,
            );
            final attentionPanel = _AttentionPanel(
              items: attention,
              events: _allEvents(events),
              onManage: onManageEvents,
              onAttendees: onAttendees,
              onSendUpdate: onSendUpdate,
            );
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: eventPanel),
                  SizedBox(width: 22),
                  Expanded(flex: 4, child: attentionPanel),
                ],
              );
            }
            return Column(
              children: [
                eventPanel,
                SizedBox(height: 22),
                attentionPanel,
              ],
            );
          },
        ),
        SizedBox(height: 34),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 930;
            final chart = _PerformancePanel(
              points: performance,
              metric: performanceMetric,
              onMetricChanged: onPerformanceMetricChanged,
            );
            final feed = _ActivityPanel(items: activity);
            if (wide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: chart),
                  SizedBox(width: 22),
                  Expanded(flex: 4, child: feed),
                ],
              );
            }
            return Column(
              children: [chart, SizedBox(height: 22), feed],
            );
          },
        ),
        if (refreshing) ...[
          SizedBox(height: 20),
          LinearProgressIndicator(color: _HubColors.rose),
        ],
      ],
    );
  }
}

class _HubTopBar extends StatelessWidget {
  const _HubTopBar({
    required this.organizer,
    required this.logoUrl,
    required this.onNotifications,
    required this.onProfile,
  });

  final String organizer;
  final String? logoUrl;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BrandMark(imageUrl: logoUrl),
        SizedBox(width: 10),
        Text(
          'Khair',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
        Spacer(),
        IconButton(
          onPressed: onNotifications,
          tooltip: context.l10n.orgNotifications,
          icon: Icon(Icons.notifications_none_rounded),
        ),
        SizedBox(width: 4),
        InkWell(
          onTap: onProfile,
          borderRadius: BorderRadius.circular(24),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: _HubColors.softRose,
            child: Text(
              organizer.isEmpty
                  ? 'K'
                  : organizer.characters.first.toUpperCase(),
              style: TextStyle(
                  color: _HubColors.rose, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({this.imageUrl});
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final image = imageUrl;
    if (image != null && image.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          image,
          width: 38,
          height: 38,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _HubColors.rose,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.volunteer_activism_rounded,
            color: Colors.white, size: 21),
      );
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    const choices = <Map<String, String>>[
      {'key': '7d', 'label': 'Last 7 days'},
      {'key': '30d', 'label': 'Last 30 days'},
      {'key': 'this_month', 'label': 'This month'},
      {'key': 'last_month', 'label': 'Last month'},
      {'key': 'custom', 'label': 'Custom range'},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: choices.map((choice) {
          final isSelected = choice['key'] == selected;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(choice['label']!),
              avatar: choice['key'] == 'custom'
                  ? Icon(Icons.date_range_outlined, size: 16)
                  : null,
              selected: isSelected,
              onSelected: (_) => onChanged(choice['key']!),
              selectedColor: _HubColors.softRose,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? _HubColors.darkSurface
                  : Colors.white,
              side: BorderSide(
                color: isSelected ? _HubColors.rose : _border(context),
              ),
              labelStyle: TextStyle(
                color: isSelected ? _HubColors.rose : _muted(context),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.metrics});
  final Map<String, dynamic> metrics;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        label: context.l10n.upcomingEvents,
        value: _asNumber(metrics['upcoming_events']).toString(),
        icon: Icons.event_available_outlined,
        tone: _HubColors.violet,
      ),
      _MetricData(
        label: context.l10n.confirmedAttendees,
        value: _asNumber(metrics['total_attendees']).toString(),
        change: _asDoubleOrNull(metrics['attendee_change']),
        icon: Icons.groups_2_outlined,
        tone: _HubColors.rose,
      ),
      _MetricData(
        label: context.l10n.eventViews,
        value: _asNumber(metrics['event_views']).toString(),
        change: _asDoubleOrNull(metrics['view_change']),
        icon: Icons.visibility_outlined,
        tone: _HubColors.blue,
      ),
      _MetricData(
        label: context.l10n.joinRate,
        value: _asNumber(metrics['event_views']) == 0
            ? '—'
            : '${_asDouble(metrics['join_rate']).toStringAsFixed(1)}%',
        change: _asDoubleOrNull(metrics['join_rate_change']),
        icon: Icons.trending_up_rounded,
        tone: _HubColors.orange,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 980
            ? 4
            : constraints.maxWidth >= 580
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: columns == 1 ? 3.25 : 1.7,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          children: items.map((item) => _MetricCard(item: item)).toList(),
        );
      },
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.change,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final double? change;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.item});
  final _MetricData item;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: item.tone.withAlpha(20),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(item.icon, color: item.tone, size: 19),
                ),
                Spacer(),
                if (item.change != null) _ChangeBadge(change: item.change!),
              ],
            ),
            Spacer(),
            Text(
              item.value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                  ),
            ),
            SizedBox(height: 3),
            Text(item.label, style: TextStyle(color: _muted(context))),
          ],
        ),
      ),
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  const _ChangeBadge({required this.change});
  final double change;

  @override
  Widget build(BuildContext context) {
    final positive = change >= 0;
    final color = positive ? _HubColors.success : _HubColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${positive ? '+' : ''}${change.toStringAsFixed(0)}%',
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _NextEventCard extends StatelessWidget {
  const _NextEventCard({
    required this.event,
    required this.onManage,
    required this.onAttendees,
    required this.onSendUpdate,
  });
  final Map<String, dynamic> event;
  final VoidCallback onManage;
  final ValueChanged<Map<String, dynamic>> onAttendees;
  final ValueChanged<Map<String, dynamic>> onSendUpdate;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 680;
          final image = _EventImage(event: event, height: compact ? 190 : 250);
          final details = Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusBadge(status: _asString(event['status'])),
                SizedBox(height: 12),
                Text(
                  _asString(event['title'], fallback: 'Untitled event'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
                SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 9,
                  children: [
                    _Meta(
                        icon: Icons.calendar_today_outlined,
                        value: _formatDate(event['start_date'])),
                    _Meta(
                        icon: Icons.schedule_outlined,
                        value: _formatTime(event['start_date'])),
                    _Meta(
                      icon: event['is_online'] == true
                          ? Icons.videocam_outlined
                          : Icons.location_on_outlined,
                      value: event['is_online'] == true
                          ? context.l10n.online
                          : _asString(event['city'], fallback: 'Venue TBA'),
                    ),
                  ],
                ),
                SizedBox(height: 18),
                _AttendeeProgress(event: event),
                SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                        onPressed: onManage,
                        child: Text(context.l10n.manageEvent)),
                    OutlinedButton(
                      onPressed: () => onAttendees(event),
                      child: Text(context.l10n.attendees),
                    ),
                    if (_canSendUpdate(event))
                      FilledButton(
                        onPressed: () => onSendUpdate(event),
                        style: FilledButton.styleFrom(
                            backgroundColor: _HubColors.rose,
                            foregroundColor: Colors.white),
                        child: Text(context.l10n.sendUpdate),
                      ),
                  ],
                ),
              ],
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [image, details],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 310, child: image),
                Expanded(child: details)
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoNextEventCard extends StatelessWidget {
  const _NoNextEventCard({required this.onCreateEvent});
  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _HubColors.softRose,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.auto_awesome_outlined, color: _HubColors.rose),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.readyToHostYourNextEvent,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  SizedBox(height: 5),
                  Text(context.l10n.createAnEventAndStartBuildingY,
                      style: TextStyle(color: _muted(context))),
                ],
              ),
            ),
            SizedBox(width: 12),
            FilledButton(
              onPressed: onCreateEvent,
              style: FilledButton.styleFrom(
                  backgroundColor: _HubColors.rose,
                  foregroundColor: Colors.white),
              child: Text(context.l10n.createEvent1),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsPanel extends StatelessWidget {
  const _EventsPanel({
    required this.events,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onManage,
    required this.onAttendees,
    required this.onSendUpdate,
  });
  final Map<String, dynamic> events;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onManage;
  final ValueChanged<Map<String, dynamic>> onAttendees;
  final ValueChanged<Map<String, dynamic>> onSendUpdate;

  @override
  Widget build(BuildContext context) {
    final labels = [
      context.l10n.upcomingEvents,
      context.l10n.draftEvents,
      context.l10n.past,
    ];
    const keys = ['upcoming', 'drafts', 'past'];
    final safeTab = selectedTab.clamp(0, labels.length - 1);
    final items = _asList(events[keys[safeTab]]);

    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
                title: context.l10n.yourEvents,
                action: context.l10n.viewAll,
                onAction: onManage),
            SizedBox(height: 15),
            Wrap(
              spacing: 7,
              children: List.generate(
                labels.length,
                (index) => ChoiceChip(
                  label: Text(labels[index]),
                  selected: index == safeTab,
                  onSelected: (_) => onTabChanged(index),
                  selectedColor: _HubColors.softRose,
                  side: BorderSide(
                      color: index == safeTab
                          ? _HubColors.rose
                          : _border(context)),
                  labelStyle: TextStyle(
                      color:
                          index == safeTab ? _HubColors.rose : _muted(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ),
            SizedBox(height: 7),
            if (items.isEmpty)
              _InlineEmpty(
                  message: safeTab == 0
                      ? context.l10n.noUpcomingEventsYet
                      : safeTab == 1
                          ? context.l10n.noDraftEvents
                          : context.l10n.noPastEvents)
            else
              ...items.map((item) => _EventRow(
                    event: _asMap(item),
                    onManage: onManage,
                    onAttendees: onAttendees,
                    onSendUpdate: onSendUpdate,
                  )),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.onManage,
    required this.onAttendees,
    required this.onSendUpdate,
  });
  final Map<String, dynamic> event;
  final VoidCallback onManage;
  final ValueChanged<Map<String, dynamic>> onAttendees;
  final ValueChanged<Map<String, dynamic>> onSendUpdate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            height: 58,
            child: _EventImage(event: event, radius: 11),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _asString(event['title'], fallback: 'Untitled event'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                SizedBox(height: 5),
                Text(
                  '${_formatDate(event['start_date'])} · ${_asNumber(event['attendees'])} attendees',
                  style: TextStyle(color: _muted(context), fontSize: 12),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          _StatusBadge(status: _asString(event['status'])),
          PopupMenuButton<String>(
            tooltip: context.l10n.eventActions,
            onSelected: (value) {
              switch (value) {
                case 'manage':
                  onManage();
                case 'attendees':
                  onAttendees(event);
                case 'update':
                  onSendUpdate(event);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                  value: 'manage', child: Text(context.l10n.manageEvent)),
              if (_isLiveEvent(event))
                PopupMenuItem(
                    value: 'attendees',
                    child: Text(context.l10n.viewAttendees)),
              if (_canSendUpdate(event))
                PopupMenuItem(
                    value: 'update', child: Text(context.l10n.sendUpdate)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({
    required this.items,
    required this.events,
    required this.onManage,
    required this.onAttendees,
    required this.onSendUpdate,
  });
  final List<dynamic> items;
  final List<Map<String, dynamic>> events;
  final VoidCallback onManage;
  final ValueChanged<Map<String, dynamic>> onAttendees;
  final ValueChanged<Map<String, dynamic>> onSendUpdate;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(title: context.l10n.needsYourAttention),
            SizedBox(height: 12),
            if (items.isEmpty)
              _InlineEmpty(message: context.l10n.noAttentionNeeded)
            else
              ...items.map((raw) {
                final item = _asMap(raw);
                final severity = _asString(item['severity']);
                final color = severity == 'urgent'
                    ? _HubColors.danger
                    : severity == 'warning'
                        ? _HubColors.orange
                        : _HubColors.blue;
                final related = events
                    .where((event) =>
                        _asString(event['id']) == _asString(item['event_id']))
                    .toList();
                final event = related.isEmpty ? null : related.first;
                final action = _asString(item['action']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withAlpha(14),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: color.withAlpha(35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        severity == 'urgent'
                            ? Icons.priority_high_rounded
                            : Icons.info_outline_rounded,
                        color: color,
                        size: 19,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_asString(item['title']),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13)),
                            SizedBox(height: 3),
                            Text(_asString(item['detail']),
                                style: TextStyle(
                                    color: _muted(context), fontSize: 12)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: event == null
                            ? onManage
                            : action == 'attendees'
                                ? () => onAttendees(event)
                                : action == 'send_update'
                                    ? () => onSendUpdate(event)
                                    : onManage,
                        child: Text(action == 'attendees'
                            ? context.l10n.open
                            : context.l10n.review),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _PerformancePanel extends StatelessWidget {
  const _PerformancePanel({
    required this.points,
    required this.metric,
    required this.onMetricChanged,
  });
  final List<dynamic> points;
  final String metric;
  final ValueChanged<String> onMetricChanged;

  @override
  Widget build(BuildContext context) {
    final parsed = points.map(_asMap).toList();
    final values = parsed
        .map((point) =>
            _asNumber(point[metric == 'views' ? 'views' : 'attendees']))
        .toList();
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: _SectionHeading(title: context.l10n.performance)),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'views', label: Text(context.l10n.views)),
                    ButtonSegment(
                        value: 'attendees', label: Text(context.l10n.joins)),
                  ],
                  selected: {metric},
                  onSelectionChanged: (value) => onMetricChanged(value.first),
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    textStyle: WidgetStateProperty.all(
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            SizedBox(height: 5),
            Text(
              metric == 'views'
                  ? context.l10n.performanceViewsRange
                  : context.l10n.performanceJoinsRange,
              style: TextStyle(color: _muted(context), fontSize: 12),
            ),
            SizedBox(height: 18),
            if (parsed.isEmpty)
              SizedBox(
                  height: 190,
                  child:
                      _InlineEmpty(message: context.l10n.noPerformanceDataYet))
            else
              _LineChart(
                points: parsed,
                values: values,
                color: _HubColors.rose,
                onPointTap: (index) {
                  if (index < 0 || index >= parsed.length) return;
                  final point = parsed[index];
                  final date = _parseDate(point['date']);
                  final label = date == null
                      ? _asString(point['date'])
                      : DateFormat('MMM d').format(date);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '$label · ${values[index]} ${metric == 'views' ? 'views' : 'joins'}')));
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({
    required this.points,
    required this.values,
    required this.color,
    required this.onPointTap,
  });
  final List<Map<String, dynamic>> points;
  final List<int> values;
  final Color color;
  final ValueChanged<int> onPointTap;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(context.l10n.noPerformanceDataYet,
            style: TextStyle(color: _HubColors.muted)),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          children: [
            SizedBox(
              height: 184,
              width: width,
              child: GestureDetector(
                onTapUp: (details) {
                  if (values.isEmpty || width <= 0) return;
                  final fraction =
                      (details.localPosition.dx / width).clamp(0.0, 0.999999);
                  onPointTap((fraction * values.length).floor());
                },
                child: CustomPaint(
                  painter: _ChartPainter(values: values, color: color),
                ),
              ),
            ),
            SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chartDate(points.first['date']),
                if (points.length > 2)
                  _chartDate(points[points.length ~/ 2]['date']),
                _chartDate(points.last['date']),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _chartDate(dynamic value) => Text(
        _formatShortDate(value),
        style: TextStyle(fontSize: 10, color: _HubColors.muted),
      );
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter({required this.values, required this.color});
  final List<int> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 6.0;
    const verticalPadding = 9.0;
    final plot = Rect.fromLTWH(horizontalPadding, verticalPadding,
        size.width - horizontalPadding * 2, size.height - verticalPadding * 2);
    final gridPaint = Paint()
      ..color = color.withAlpha(22)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = plot.top + plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
    }
    if (values.isEmpty) return;
    final maxValue =
        values.fold<int>(0, (max, value) => value > max ? value : max);
    final effectiveMax = maxValue == 0 ? 1 : maxValue;
    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? plot.center.dx
          : plot.left + plot.width * i / (values.length - 1);
      final y = plot.bottom - (values[i] / effectiveMax) * plot.height;
      final point = Offset(x, y);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
        fill.moveTo(point.dx, plot.bottom);
        fill.lineTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
        fill.lineTo(point.dx, point.dy);
      }
    }
    fill.lineTo(plot.right, plot.bottom);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withAlpha(50), color.withAlpha(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(plot),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    if (values.length <= 31) {
      final pointPaint = Paint()..color = color;
      for (var i = 0; i < values.length; i++) {
        final x = values.length == 1
            ? plot.center.dx
            : plot.left + plot.width * i / (values.length - 1);
        final y = plot.bottom - (values[i] / effectiveMax) * plot.height;
        canvas.drawCircle(Offset(x, y), 2.7, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.items});
  final List<dynamic> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(title: context.l10n.recentActivity),
            SizedBox(height: 14),
            if (items.isEmpty)
              _InlineEmpty(message: context.l10n.organizerActivityWillAppear)
            else
              ...items.take(6).map((raw) {
                final item = _asMap(raw);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                            color: _HubColors.rose, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activityTitle(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            if (_asString(item['detail']).isNotEmpty) ...[
                              SizedBox(height: 2),
                              Text(
                                _asString(item['detail']),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: _muted(context), fontSize: 12),
                              ),
                            ],
                            SizedBox(height: 2),
                            Text(
                              _relativeDate(item['created_at']),
                              style: TextStyle(
                                  color: _muted(context), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _AttendeeProgress extends StatelessWidget {
  const _AttendeeProgress({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final attendees = _asNumber(event['attendees']);
    final capacity = _asNullableInt(event['capacity']);
    final ratio = capacity != null && capacity > 0
        ? (attendees / capacity).clamp(0.0, 1.0)
        : null;

    final preview = event['attendee_preview'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (attendees == 0)
          Row(
            children: [
              Icon(Icons.groups_2_outlined, size: 17, color: _muted(context)),
              SizedBox(width: 7),
              Text(
                'No attendees yet. They will appear here.',
                style: TextStyle(color: _muted(context), fontSize: 13),
              ),
            ],
          )
        else
          Row(
            children: [
              SizedBox(
                height: 28,
                width: preview.isEmpty ? 0 : (preview.length * 20.0) + 8,
                child: Stack(
                  children: List.generate(preview.length, (index) {
                    final p = preview[index] as Map? ?? {};
                    final avatar = p['avatar_url']?.toString();
                    return Positioned(
                      left: index * 20.0,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: _HubColors.softRose,
                          backgroundImage:
                              avatar != null ? NetworkImage(avatar) : null,
                          child: avatar == null
                              ? Icon(Icons.person,
                                  size: 14, color: _HubColors.rose)
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              if (preview.isNotEmpty) SizedBox(width: 8),
              Text(
                capacity == null
                    ? '$attendees confirmed attendees'
                    : '$attendees / $capacity confirmed attendees',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        if (ratio != null) ...[
          SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: _HubColors.softRose,
              color: _HubColors.rose,
            ),
          ),
        ],
      ],
    );
  }
}

class _EventImage extends StatelessWidget {
  const _EventImage({required this.event, this.height, this.radius = 0});
  final Map<String, dynamic> event;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = _nullableString(event['image_url']);
    final placeholder = Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_HubColors.rose, Color(0xFFB92F6C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
          child: Icon(Icons.event_rounded, color: Colors.white, size: 35)),
    );
    final image = url == null || url.isEmpty
        ? placeholder
        : Image.network(
            url,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => placeholder,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(height: height, child: image),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase().replaceAll('_', ' ');
    final tone = switch (status.toLowerCase()) {
      'published' || 'approved' => _HubColors.success,
      'pending' => _HubColors.orange,
      'needs_revision' || 'rejected' => _HubColors.danger,
      'draft' => _HubColors.muted,
      _ => _HubColors.blue,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withAlpha(18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized,
        style:
            TextStyle(color: tone, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _HubColors.rose),
          SizedBox(width: 6),
          Text(value, style: TextStyle(color: _muted(context), fontSize: 12)),
        ],
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                  foregroundColor: _HubColors.rose,
                  padding: const EdgeInsets.symmetric(horizontal: 6)),
              child: Text(action!),
            ),
        ],
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? _HubColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: dark ? _HubColors.darkBorder : _HubColors.border),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                    color: Color(0x0A171126),
                    blurRadius: 24,
                    offset: Offset(0, 8)),
              ],
      ),
      child: child,
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 27),
        child: Row(
          children: [
            Icon(Icons.inbox_outlined, color: _muted(context), size: 19),
            SizedBox(width: 9),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: _muted(context), fontSize: 13)),
            ),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, color: _HubColors.rose, size: 42),
              SizedBox(height: 14),
              Text(context.l10n.adminActionFailed,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
              SizedBox(height: 7),
              Text(message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted(context))),
              SizedBox(height: 18),
              FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                      backgroundColor: _HubColors.rose,
                      foregroundColor: Colors.white),
                  child: Text(context.l10n.tryAgain)),
            ],
          ),
        ),
      );
}

class _AttendeeSheet extends StatelessWidget {
  const _AttendeeSheet({required this.eventTitle, required this.attendees});
  final String eventTitle;
  final List<Map<String, dynamic>> attendees;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: 640),
        padding: EdgeInsets.fromLTRB(20, 13, 20, 20 + bottom),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                    color: _border(context),
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            SizedBox(height: 18),
            Text(context.l10n.attendees,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            SizedBox(height: 3),
            Text(eventTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _muted(context))),
            SizedBox(height: 16),
            if (attendees.isEmpty)
              Expanded(
                  child:
                      _InlineEmpty(message: context.l10n.noConfirmedAttendees))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: attendees.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (_, index) {
                    final attendee = attendees[index];
                    final name = _asString(attendee['display_name'],
                        fallback:
                            _asString(attendee['email'], fallback: 'Attendee'));
                    final avatar = attendee['avatar_url']?.toString();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: _HubColors.softRose,
                        backgroundImage:
                            avatar != null ? NetworkImage(avatar) : null,
                        child: avatar == null
                            ? Text(name.characters.first.toUpperCase(),
                                style: TextStyle(color: _HubColors.rose))
                            : null,
                      ),
                      title: Text(name,
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(_relativeDate(
                          attendee['joined_at'] ?? attendee['registered_at'])),
                      trailing: attendee['attended'] == true
                          ? Icon(Icons.check_circle,
                              color: _HubColors.success, size: 19)
                          : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementDraft {
  const _AnnouncementDraft(
      {required this.title, required this.message, required this.type});
  final String title;
  final String message;
  final String type;
}

class _AnnouncementDialog extends StatefulWidget {
  const _AnnouncementDialog({required this.eventTitle});
  final String eventTitle;

  @override
  State<_AnnouncementDialog> createState() => _AnnouncementDialogState();
}

class _AnnouncementDialogState extends State<_AnnouncementDialog> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  String _type = 'general';

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(context.l10n.sendAnEventUpdate),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.eventTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted(context))),
                SizedBox(height: 17),
                TextField(
                  controller: _title,
                  maxLength: 160,
                  decoration: InputDecoration(
                      labelText: context.l10n.title,
                      hintText: context.l10n.aShortUpdateTitle),
                ),
                SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration:
                      InputDecoration(labelText: context.l10n.updateType),
                  items: [
                    DropdownMenuItem(
                        value: 'general',
                        child: Text(context.l10n.generalUpdate)),
                    DropdownMenuItem(
                        value: 'schedule_change',
                        child: Text(context.l10n.scheduleUpdate)),
                    DropdownMenuItem(
                        value: 'reminder', child: Text(context.l10n.reminder)),
                    DropdownMenuItem(
                        value: 'important',
                        child: Text(context.l10n.importantUpdate)),
                  ],
                  onChanged: (value) =>
                      setState(() => _type = value ?? 'general'),
                ),
                SizedBox(height: 10),
                TextField(
                  controller: _message,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 2000,
                  decoration: InputDecoration(
                      labelText: context.l10n.message,
                      hintText: context.l10n.writeTheUpdateForAttendees),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.adminCancel)),
          FilledButton(
            onPressed: () {
              final message = _message.text.trim();
              if (message.isEmpty) return;
              Navigator.of(context).pop(_AnnouncementDraft(
                title: _title.text.trim(),
                message: message,
                type: _type,
              ));
            },
            style: FilledButton.styleFrom(
                backgroundColor: _HubColors.rose,
                foregroundColor: Colors.white),
            child: Text(context.l10n.sendUpdate),
          ),
        ],
      );
}

class _HubColors {
  static const rose = Color(0xFFF43F75);
  static const softRose = Color(0xFFFFF1F5);
  static const background = Color(0xFFFCFAFB);
  static const border = Color(0xFFEAE5E8);
  static const muted = Color(0xFF726B7B);
  static const darkBackground = Color(0xFF101014);
  static const darkSurface = Color(0xFF19181E);
  static const darkBorder = Color(0xFF302D35);
  static const violet = Color(0xFF8B5CF6);
  static const blue = Color(0xFF0EA5E9);
  static const orange = Color(0xFFF59E0B);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFDC2626);
}

String _summaryText(
    BuildContext context, Map<String, dynamic> metrics, String range) {
  final upcoming = _asNumber(metrics['upcoming_events']);
  final attendees = _asNumber(metrics['total_attendees']);
  final label = switch (range) {
    '7d' => context.l10n.organizerRangeLast7Days,
    'this_month' => context.l10n.organizerRangeThisMonth,
    'last_month' => context.l10n.organizerRangeLastMonth,
    'custom' => context.l10n.organizerRangeSelected,
    _ => context.l10n.organizerRangeLast30Days,
  };
  if (upcoming == 0) {
    return context.l10n.organizerSummaryNoUpcoming(attendees, label);
  }
  return context.l10n.organizerSummaryUpcoming(
      upcoming,
      upcoming == 1
          ? context.l10n.organizerEvent
          : context.l10n.organizerEvents,
      attendees,
      label);
}

String _timeGreeting(BuildContext context) {
  final hour = DateTime.now().hour;
  if (hour < 12) return context.l10n.greetingGoodMorning;
  if (hour < 18) return context.l10n.greetingGoodAfternoon;
  return context.l10n.greetingGoodEvening;
}

String _activityTitle(Map<String, dynamic> item) {
  final type = _asString(item['type']);
  final title = _asString(item['title']);
  return switch (type) {
    'attendee_joined' => 'A user joined $title',
    'announcement_sent' => 'Update sent for $title',
    'event.created' => '$title was created',
    'event.updated' => '$title was updated',
    'event.cancelled' => '$title was cancelled',
    _ => title.isEmpty ? 'Organizer activity' : title,
  };
}

bool _isLiveEvent(Map<String, dynamic> event) {
  final status = _asString(event['status']).toLowerCase();
  return status == 'approved' || status == 'published';
}

bool _canSendUpdate(Map<String, dynamic> event) {
  if (!_isLiveEvent(event)) return false;
  final date = _parseDate(event['start_date']);
  return date == null || date.isAfter(DateTime.now());
}

List<Map<String, dynamic>> _allEvents(Map<String, dynamic> groups) => [
      ..._asList(groups['upcoming']).map(_asMap),
      ..._asList(groups['drafts']).map(_asMap),
      ..._asList(groups['past']).map(_asMap),
    ];

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<dynamic> _asList(dynamic value) => value is List ? value : const [];

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

String? _nullableString(dynamic value) {
  final text = _asString(value);
  return text.isEmpty ? null : text;
}

int _asNumber(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

int? _asNullableInt(dynamic value) => value == null ? null : _asNumber(value);

double _asDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

double? _asDoubleOrNull(dynamic value) =>
    value is num ? value.toDouble() : null;

DateTime? _parseDate(dynamic value) =>
    value is DateTime ? value : DateTime.tryParse(_asString(value));

String _formatDate(dynamic value) {
  final date = _parseDate(value);
  return date == null
      ? 'Date unavailable'
      : DateFormat('EEE, MMM d, y').format(date.toLocal());
}

String _formatShortDate(dynamic value) {
  final date = _parseDate(value);
  return date == null ? '' : DateFormat('MMM d').format(date.toLocal());
}

String _formatTime(dynamic value) {
  final date = _parseDate(value);
  return date == null
      ? 'Time unavailable'
      : DateFormat('h:mm a').format(date.toLocal());
}

String _relativeDate(dynamic value) {
  final date = _parseDate(value)?.toLocal();
  if (date == null) return 'Date unavailable';
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  return DateFormat('MMM d').format(date);
}

Color _border(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? _HubColors.darkBorder
        : _HubColors.border;

Color _muted(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Color(0xFFAAA3B0)
        : _HubColors.muted;

String _friendlyError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    if (status == 401) return 'Please sign in again to continue.';
    if (status == 403) {
      return 'Your organizer account is not approved for this workspace.';
    }
  }
  return 'Check your connection and try again.';
}
