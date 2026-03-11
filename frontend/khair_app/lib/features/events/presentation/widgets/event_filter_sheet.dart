import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../domain/entities/event.dart';
import '../bloc/events_bloc.dart';

class EventFilterSheet extends StatefulWidget {
  const EventFilterSheet({super.key});

  @override
  State<EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<EventFilterSheet> {
  late EventFilter _filter;
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filter = context.read<EventsBloc>().state.filter;
    _countryController.text = _filter.country ?? '';
    _cityController.text = _filter.city ?? '';
  }

  @override
  void dispose() {
    _countryController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.filterEventsTitle,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: _resetFilters,
                        child: Text(context.l10n.filterEventsReset),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Location
                  Text(
                    context.l10n.eventDetailsLocation,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _countryController,
                    decoration: InputDecoration(
                      labelText: context.l10n.filterEventsCountry,
                      prefixIcon: const Icon(Icons.public),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _filter = _filter.copyWith(
                          country: value.isNotEmpty ? value : null,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cityController,
                    decoration: InputDecoration(
                      labelText: context.l10n.city,
                      prefixIcon: const Icon(Icons.location_city),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _filter = _filter.copyWith(
                          city: value.isNotEmpty ? value : null,
                        );
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // Event Type
                  Text(
                    context.l10n.filterEventsType,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTypeChip('conference', context.l10n.eventTypeConference),
                      _buildTypeChip('workshop', context.l10n.eventTypeWorkshop),
                      _buildTypeChip('seminar', context.l10n.eventTypeSeminar),
                      _buildTypeChip('festival', context.l10n.eventTypeFestival),
                      _buildTypeChip('meetup', context.l10n.eventTypeMeetup),
                      _buildTypeChip('other', context.l10n.eventTypeOther),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Language
                  Text(
                    context.l10n.filterEventsLanguage,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildLanguageChip('en', context.l10n.langEnglish),
                      _buildLanguageChip('ar', context.l10n.langArabic),
                      _buildLanguageChip('fr', context.l10n.langFrench),
                      _buildLanguageChip('es', context.l10n.langSpanish),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        context.l10n.applyFilters,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTypeChip(String value, String label) {
    final isSelected = _filter.eventType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = _filter.copyWith(
            eventType: selected ? value : null,
          );
        });
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildLanguageChip(String value, String label) {
    final isSelected = _filter.language == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = _filter.copyWith(
            language: selected ? value : null,
          );
        });
      },
      selectedColor: AppTheme.primaryColor.withOpacity(0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      _filter = const EventFilter();
      _countryController.clear();
      _cityController.clear();
    });
  }

  void _applyFilters() {
    context.read<EventsBloc>().add(UpdateFilter(_filter));
    Navigator.pop(context);
  }
}
