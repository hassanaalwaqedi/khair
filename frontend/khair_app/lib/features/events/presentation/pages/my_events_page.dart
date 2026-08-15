import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../data/datasources/join_datasource.dart';

/// Attendee dashboard backed by the existing event reservation API.
class MyEventsPage extends StatefulWidget {
  const MyEventsPage({super.key});

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  late Future<List<dynamic>> _reservations;

  @override
  void initState() {
    super.initState();
    _reservations = getIt<JoinDataSource>().getMyReservations();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Events')),
    body: FutureBuilder<List<dynamic>>(
      future: _reservations,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) {
          return Center(child: FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const Text('Try again')));
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_available_outlined, size: 52),
            const SizedBox(height: 12),
            const Text('No joined events yet'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => context.go('/'), child: const Text('Discover events')),
          ]));
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final item = Map<String, dynamic>.from(items[index] as Map);
              final eventId = item['event_id']?.toString() ?? '';
              final title = item['event_title']?.toString() ?? item['title']?.toString() ?? 'Event';
              return Card(child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.event)),
                title: Text(title),
                subtitle: Text(item['status']?.toString() ?? 'Joined'),
                trailing: const Icon(Icons.chevron_right),
                onTap: eventId.isEmpty ? null : () => context.push('/events/$eventId'),
              ));
            },
          ),
        );
      },
    ),
  );

  void _reload() => setState(() => _reservations = getIt<JoinDataSource>().getMyReservations());
}
