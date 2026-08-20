import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';

/// Event-only public information pages. Legal copy should be reviewed before a
/// production policy update is published.
class StaticPage extends StatelessWidget {
  final String pageType;
  const StaticPage({super.key, required this.pageType});

  @override
  Widget build(BuildContext context) {
    final content = switch (pageType) {
      'about' => ('About Khair', 'Discover meaningful events. Join communities. Help organizers bring people together.\n\nKhair connects people with local and online events, and gives verified organizers the tools to publish, manage attendees, and share updates.'),
      'verification' => ('Organizer verification', 'Organizers may be asked to provide identity or organization information before publishing events. Our team reviews applications and may request more information.'),
      'content' => ('Content policy', 'Events must be accurate, lawful, and respectful. Organizers must provide clear dates, locations, accessibility details, and contact information. We may remove harmful, deceptive, or unsafe content.'),
      'privacy' => ('Privacy policy', 'Khair collects account, device, and optional location information to provide event discovery, registrations, notifications, and safety features. We do not sell personal information. Event organizers receive only the attendee information needed to run their event.'),
      'terms' => ('Terms of use', 'Users may browse, join, and manage event attendance. Approved organizers may publish and manage events. You are responsible for accurate account and event information, and for using the service lawfully and respectfully.'),
      _ => ('Khair', 'Discover meaningful events and join your community.'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(content.$1)),
      body: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(content.$1, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          SizedBox(height: 20),
          Text(content.$2, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7)),
          SizedBox(height: 28),
          Text(context.l10n.lastUpdatedAugust2026, style: TextStyle(color: Colors.grey)),
        ])),
      )),
    );
  }
}
