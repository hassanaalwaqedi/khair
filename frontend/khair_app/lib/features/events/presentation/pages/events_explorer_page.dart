import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/core/widgets/khair_components.dart';
import 'package:khair_app/features/events/domain/entities/event.dart';
import 'package:khair_app/features/events/presentation/bloc/events_bloc.dart';

/// Events Explorer Page - Core user journey
/// Uses real data from EventsBloc, no mock data
class EventsExplorerPage extends StatefulWidget {
  const EventsExplorerPage({super.key});

  @override
  State<EventsExplorerPage> createState() => _EventsExplorerPageState();
}

class _EventsExplorerPageState extends State<EventsExplorerPage> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Today', 'This Week', 'Lectures', 'Community', 'Classes'];

  @override
  void initState() {
    super.initState();
    // Load events when page initializes
    context.read<EventsBloc>().add(LoadEvents());
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.go('/map'),
            tooltip: 'Map View',
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchSheet(context),
            tooltip: 'Search',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter bar
          _buildFilterBar(),

          // Content
          Expanded(
            child: BlocBuilder<EventsBloc, EventsState>(
              builder: (context, state) {
                if (isWide) {
                  return Row(
                    children: [
                      // Sidebar filters (wide screens)
                      Container(
                        width: 280,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(color: KhairColors.border),
                          ),
                        ),
                        child: _buildAdvancedFilters(state),
                      ),
                      // Event grid
                      Expanded(child: _buildEventGrid(state, isWide)),
                    ],
                  );
                }
                return _buildEventList(state);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: KhairColors.surface,
        border: Border(
          bottom: BorderSide(color: KhairColors.border),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: KhairFilterChip(
                label: filter,
                isSelected: _selectedFilter == filter,
                onTap: () {
                  setState(() => _selectedFilter = filter);
                  _applyFilter(filter);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _applyFilter(String filter) {
    final bloc = context.read<EventsBloc>();
    EventFilter newFilter;

    switch (filter) {
      case 'Today':
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        newFilter = EventFilter(startDate: startOfDay, endDate: endOfDay);
        break;
      case 'This Week':
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 7));
        newFilter = EventFilter(
          startDate: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          endDate: DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day),
        );
        break;
      case 'Lectures':
        newFilter = const EventFilter(eventType: 'lecture');
        break;
      case 'Community':
        newFilter = const EventFilter(eventType: 'community');
        break;
      case 'Classes':
        newFilter = const EventFilter(eventType: 'class');
        break;
      default:
        newFilter = const EventFilter();
    }

    bloc.add(UpdateFilter(newFilter));
  }

  Widget _buildAdvancedFilters(EventsState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filters', style: KhairTypography.headlineSmall),
          const SizedBox(height: 24),

          // Location
          _buildFilterSection(
            'Location',
            Icons.location_on_outlined,
            [
              _buildFilterOption('All Locations', state.filter.country == null && state.filter.city == null, () {
                context.read<EventsBloc>().add(UpdateFilter(state.filter.copyWith()));
              }),
              _buildFilterOption('Near Me', false, () {}), // TODO: Implement geolocation
            ],
          ),

          const SizedBox(height: 24),

          // Event Type
          _buildFilterSection(
            'Type',
            Icons.category_outlined,
            [
              _buildFilterOption('All Types', state.filter.eventType == null, () {
                context.read<EventsBloc>().add(UpdateFilter(const EventFilter()));
              }),
              _buildFilterOption('Lectures', state.filter.eventType == 'lecture', () {
                context.read<EventsBloc>().add(
                  UpdateFilter(state.filter.copyWith(eventType: 'lecture')),
                );
              }),
              _buildFilterOption('Classes', state.filter.eventType == 'class', () {
                context.read<EventsBloc>().add(
                  UpdateFilter(state.filter.copyWith(eventType: 'class')),
                );
              }),
              _buildFilterOption('Community', state.filter.eventType == 'community', () {
                context.read<EventsBloc>().add(
                  UpdateFilter(state.filter.copyWith(eventType: 'community')),
                );
              }),
              _buildFilterOption('Prayer', state.filter.eventType == 'prayer', () {
                context.read<EventsBloc>().add(
                  UpdateFilter(state.filter.copyWith(eventType: 'prayer')),
                );
              }),
            ],
          ),

          const SizedBox(height: 24),

          // Language
          _buildFilterSection(
            'Language',
            Icons.language,
            [
              _buildFilterOption('All Languages', state.filter.language == null, () {
                context.read<EventsBloc>().add(UpdateFilter(const EventFilter()));
              }),
              _buildFilterOption('English', state.filter.language == 'en', () {
                context.read<EventsBloc>().add(
                  UpdateFilter(state.filter.copyWith(language: 'en')),
                );
              }),
              _buildFilterOption('Arabic', state.filter.language == 'ar', () {
                context.read<EventsBloc>().add(
                  UpdateFilter(state.filter.copyWith(language: 'ar')),
                );
              }),
              _buildFilterOption('Urdu', state.filter.language == 'ur', () {
                context.read<EventsBloc>().add(
                  UpdateFilter(state.filter.copyWith(language: 'ur')),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, IconData icon, List<Widget> options) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: KhairColors.textSecondary),
            const SizedBox(width: 8),
            Text(title, style: KhairTypography.labelLarge),
          ],
        ),
        const SizedBox(height: 12),
        ...options,
      ],
    );
  }

  Widget _buildFilterOption(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: KhairRadius.small,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? KhairColors.primary : KhairColors.border,
                    width: 2,
                  ),
                  color: isSelected ? KhairColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: KhairTypography.bodyMedium.copyWith(
                  color: isSelected ? KhairColors.primary : KhairColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventGrid(EventsState state, bool isWide) {
    if (state.status == EventsStatus.loading) {
      return const KhairLoadingState(message: 'Loading events...');
    }

    if (state.status == EventsStatus.failure) {
      return KhairErrorState(
        message: state.errorMessage ?? 'Failed to load events. Please try again.',
        onRetry: () => context.read<EventsBloc>().add(LoadEvents()),
      );
    }

    if (state.events.isEmpty) {
      return KhairEmptyState(
        icon: Icons.event_busy,
        title: 'No Events Found',
        message: 'No events match your current filters. Try adjusting your search criteria.',
        actionLabel: 'Clear Filters',
        onAction: () {
          setState(() => _selectedFilter = 'All');
          context.read<EventsBloc>().add(const UpdateFilter(EventFilter()));
        },
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            !state.hasReachedMax &&
            state.status != EventsStatus.loadingMore) {
          context.read<EventsBloc>().add(LoadMoreEvents());
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
        ),
        itemCount: state.events.length + (state.status == EventsStatus.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.events.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildEventCard(state.events[index]);
        },
      ),
    );
  }

  Widget _buildEventList(EventsState state) {
    if (state.status == EventsStatus.loading) {
      return const KhairLoadingState(message: 'Loading events...');
    }

    if (state.status == EventsStatus.failure) {
      return KhairErrorState(
        message: state.errorMessage ?? 'Failed to load events. Please try again.',
        onRetry: () => context.read<EventsBloc>().add(LoadEvents()),
      );
    }

    if (state.events.isEmpty) {
      return KhairEmptyState(
        icon: Icons.event_busy,
        title: 'No Events Found',
        message: 'No events match your current filters. Try adjusting your search criteria.',
        actionLabel: 'Clear Filters',
        onAction: () {
          setState(() => _selectedFilter = 'All');
          context.read<EventsBloc>().add(const UpdateFilter(EventFilter()));
        },
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            !state.hasReachedMax &&
            state.status != EventsStatus.loadingMore) {
          context.read<EventsBloc>().add(LoadMoreEvents());
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.events.length + (state.status == EventsStatus.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.events.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildEventCard(state.events[index]),
          );
        },
      ),
    );
  }

  Widget _buildEventCard(Event event) {
    return KhairCard(
      onTap: () => context.go('/events/${event.id}'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: KhairColors.primarySurface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              image: event.imageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(event.imageUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: event.imageUrl == null
                ? Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.event,
                          size: 48,
                          color: KhairColors.primary.withAlpha(77),
                        ),
                      ),
                      // Type badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: KhairColors.surface,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatEventType(event.eventType),
                            style: KhairTypography.labelSmall,
                          ),
                        ),
                      ),
                    ],
                  )
                : Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: KhairColors.surface.withAlpha(230),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatEventType(event.eventType),
                        style: KhairTypography.labelSmall,
                      ),
                    ),
                  ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: KhairTypography.headlineSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.organizerName ?? 'Unknown Organizer',
                        style: KhairTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (event.status == 'approved') ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        size: 14,
                        color: KhairColors.verified,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 14,
                      color: KhairColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(_formatDate(event.startDate), style: KhairTypography.bodySmall),
                    if (event.city != null) ...[
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: KhairColors.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          event.city!,
                          style: KhairTypography.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventType(String type) {
    return type.substring(0, 1).toUpperCase() + type.substring(1);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDay = DateTime(date.year, date.month, date.day);

    String dayStr;
    if (eventDay == today) {
      dayStr = 'Today';
    } else if (eventDay == tomorrow) {
      dayStr = 'Tomorrow';
    } else {
      dayStr = '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';
    }

    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$dayStr, $hour:${date.minute.toString().padLeft(2, '0')} $period';
  }

  String _weekday(int day) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[day - 1];
  }

  String _month(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: KhairColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: KhairColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                onSubmitted: (query) {
                  Navigator.pop(context);
                  // TODO: Implement search functionality
                },
              ),
            ),
            const Divider(height: 1),
            // Info text
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Enter your search term and press enter',
                style: KhairTypography.bodyMedium.copyWith(
                  color: KhairColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
