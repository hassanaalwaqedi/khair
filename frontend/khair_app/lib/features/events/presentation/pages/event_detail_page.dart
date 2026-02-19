import 'package:flutter/material.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/core/widgets/khair_components.dart';

/// Event Detail Page - Show full event information
class EventDetailPage extends StatelessWidget {
  final String eventId;

  const EventDetailPage({
    super.key,
    required this.eventId,
  });

  // Mock event data
  Map<String, dynamic> get _event => {
        'id': eventId,
        'title': 'Friday Khutbah - The Importance of Community',
        'organizer': 'Al-Noor Islamic Center',
        'isVerified': true,
        'date': 'Friday, February 7, 2026',
        'time': '1:00 PM - 2:30 PM',
        'location': '123 Main Street, Downtown',
        'city': 'New York',
        'type': 'Prayer',
        'language': 'English & Arabic',
        'description':
            '''Join us for the weekly Friday Khutbah (sermon) followed by congregational Jumu'ah prayer.

Topic: "The Importance of Community in Islam"

Our resident Imam will discuss the significance of building strong Muslim communities and the collective responsibilities we share as believers.

All are welcome. Prayer mats will be provided. Please arrive 15 minutes early to find seating.''',
        'requirements': [
          'Wudu (ablution) required',
          'Modest dress',
          'Bring your own prayer mat (optional)',
        ],
        'amenities': [
          'Parking available',
          'Wheelchair accessible',
          'Sisters section',
          'Wudu facilities',
        ],
        'capacity': '500 attendees',
        'registrations': 234,
        'isRecurring': true,
        'recurringInfo': 'Every Friday',
      };

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App bar with image
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      KhairColors.primary,
                      KhairColors.primaryDark,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        Icons.mosque,
                        size: 80,
                        color: Colors.white.withAlpha(51),
                      ),
                    ),
                    // Type badge
                    Positioned(
                      bottom: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _event['type'],
                          style: KhairTypography.labelMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // Recurring badge
                    if (_event['isRecurring'])
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(51),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.repeat,
                                  size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                _event['recurringInfo'],
                                style: KhairTypography.labelMedium.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_border),
                onPressed: () {},
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 900),
                child: isWide
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildMainContent()),
                            const SizedBox(width: 24),
                            Expanded(child: _buildSidebar()),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildMainContent(),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: _buildSidebar(),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),

      // Bottom action bar (mobile)
      bottomNavigationBar: isWide
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: KhairColors.surface,
                border: const Border(
                  top: BorderSide(color: KhairColors.border),
                ),
              ),
              child: SafeArea(
                child: KhairButton(
                  label: 'Register to Attend',
                  fullWidth: true,
                  icon: Icons.check_circle_outline,
                  onPressed: () {},
                ),
              ),
            ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(_event['title'], style: KhairTypography.displaySmall),

        const SizedBox(height: 12),

        // Organizer
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: KhairColors.primarySurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  const Icon(Icons.business, color: KhairColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(_event['organizer'], style: KhairTypography.labelLarge),
                      if (_event['isVerified']) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.verified,
                            size: 16, color: KhairColors.verified),
                      ],
                    ],
                  ),
                  Text('Event Organizer', style: KhairTypography.bodySmall),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),

        // Quick info cards
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildInfoChip(Icons.calendar_today, _event['date']),
            _buildInfoChip(Icons.schedule, _event['time']),
            _buildInfoChip(Icons.language, _event['language']),
          ],
        ),

        const SizedBox(height: 32),

        // Description
        Text('About This Event', style: KhairTypography.headlineSmall),
        const SizedBox(height: 12),
        Text(
          _event['description'],
          style: KhairTypography.bodyLarge.copyWith(
            height: 1.7,
            color: KhairColors.textSecondary,
          ),
        ),

        const SizedBox(height: 32),

        // Requirements
        if (_event['requirements'] != null) ...[
          Text('Requirements', style: KhairTypography.headlineSmall),
          const SizedBox(height: 12),
          ...(_event['requirements'] as List).map(
            (req) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: KhairColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(req, style: KhairTypography.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: 32),

        // Amenities
        if (_event['amenities'] != null) ...[
          Text('Amenities', style: KhairTypography.headlineSmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (_event['amenities'] as List).map((amenity) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: KhairColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 14, color: KhairColors.success),
                    const SizedBox(width: 6),
                    Text(
                      amenity,
                      style: KhairTypography.labelMedium.copyWith(
                        color: KhairColors.success,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSidebar() {
    return Column(
      children: [
        // Action card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: KhairColors.surface,
            borderRadius: KhairRadius.medium,
            border: Border.all(color: KhairColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.people, color: KhairColors.textTertiary),
                  const SizedBox(width: 8),
                  Text('${_event['registrations']} attending',
                      style: KhairTypography.labelLarge),
                ],
              ),
              const SizedBox(height: 16),
              KhairButton(
                label: 'Register to Attend',
                fullWidth: true,
                icon: Icons.check_circle_outline,
                onPressed: () {},
              ),
              const SizedBox(height: 12),
              KhairButton(
                label: 'Save Event',
                fullWidth: true,
                isOutlined: true,
                icon: Icons.bookmark_border,
                onPressed: () {},
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Location card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: KhairColors.surface,
            borderRadius: KhairRadius.medium,
            border: Border.all(color: KhairColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Location', style: KhairTypography.labelLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.location_on,
                      color: KhairColors.textTertiary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_event['location'],
                        style: KhairTypography.bodyMedium),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_city,
                      color: KhairColors.textTertiary, size: 18),
                  const SizedBox(width: 8),
                  Text(_event['city'], style: KhairTypography.bodyMedium),
                ],
              ),
              const SizedBox(height: 16),
              // Map placeholder
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: KhairColors.surfaceVariant,
                  borderRadius: KhairRadius.small,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.map,
                          color: KhairColors.textTertiary, size: 32),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View on Map'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Report button
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.flag_outlined, size: 16),
          label: const Text('Report this event'),
          style: TextButton.styleFrom(
            foregroundColor: KhairColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KhairColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: KhairColors.textSecondary),
          const SizedBox(width: 8),
          Text(text, style: KhairTypography.bodyMedium),
        ],
      ),
    );
  }
}
