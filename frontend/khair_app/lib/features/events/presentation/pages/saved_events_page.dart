import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class SavedEventsPage extends StatefulWidget {
  const SavedEventsPage({super.key});

  @override
  State<SavedEventsPage> createState() => _SavedEventsPageState();
}

class _SavedEventsPageState extends State<SavedEventsPage> {
  late Future<List<Map<String, dynamic>>> _events;
  @override
  void initState() {
    super.initState();
    _events = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await getIt<ApiClient>().get('/me/saved-events');
    return ((response.data['data'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  void _reload() => setState(() => _events = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.savedEvents)),
        body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _events,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                    child: CircularProgressIndicator(color: Color(0xFFF43F75)));
              }
              if (snapshot.hasError) {
                return Center(
                    child: FilledButton(
                        onPressed: _reload,
                        child: Text(context.l10n.tryAgain)));
              }
              final events = snapshot.data ?? const [];
              if (events.isEmpty) {
                return Center(
                    child: Padding(
                        padding: const EdgeInsets.all(28),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.bookmark_border_rounded,
                              size: 48, color: Color(0xFFF43F75)),
                          SizedBox(height: 14),
                          Text(context.l10n.noSavedEventsYet,
                              style: Theme.of(context).textTheme.titleLarge),
                          SizedBox(height: 6),
                          Text(context.l10n.saveEventsYouWantToRevisit),
                          SizedBox(height: 16),
                          FilledButton(
                              onPressed: () => context.go('/'),
                              style: FilledButton.styleFrom(
                                  backgroundColor: Color(0xFFF43F75)),
                              child: Text(context.l10n.exploreEvents))
                        ])));
              }
              return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: events.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10),
                      itemBuilder: (_, index) =>
                          _SavedEventTile(event: events[index])));
            }),
      );
}

class _SavedEventTile extends StatelessWidget {
  const _SavedEventTile({required this.event});
  final Map<String, dynamic> event;
  @override
  Widget build(BuildContext context) {
    final id = event['id'].toString();
    final start = DateTime.tryParse(event['start_date']?.toString() ?? '');
    final image = event['image_url']?.toString();
    final place = event['is_online'] == true
        ? context.l10n.onlineEvent
        : [event['city'], event['country']]
            .whereType<String>()
            .where((v) => v.isNotEmpty)
            .join(', ');
    return Card(
        child: ListTile(
            contentPadding: const EdgeInsets.all(10),
            leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                    width: 58,
                    height: 58,
                    child: image?.isNotEmpty == true
                        ? Image.network(ApiConfig.resolveUrl(image),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => ColoredBox(
                                color: Color(0xFFFFF1F5),
                                child: Icon(Icons.event_outlined,
                                    color: Color(0xFFF43F75))))
                        : ColoredBox(
                            color: Color(0xFFFFF1F5),
                            child: Icon(Icons.event_outlined,
                                color: Color(0xFFF43F75))))),
            title: Text(
                event['title']?.toString() ?? context.l10n.eventFallback,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${start == null ? context.l10n.dateToBeAnnounced : DateFormat('EEE, MMM d · h:mm a').format(start)}\n${place.isEmpty ? context.l10n.locationToBeAnnounced : place}'),
            isThreeLine: true,
            trailing: Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/events/$id')));
  }
}
