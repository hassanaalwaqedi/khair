import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../tokens/tokens.dart';
import '../../../../events/domain/entities/event.dart';
import '../../../../events/presentation/bloc/events_bloc.dart';

/// A fully-functional filter bottom sheet for the Discover page.
/// Covers: date presets, format (online/in-person), price (free/paid),
/// city text field, and country text field.
class DiscoverFiltersSheet extends StatefulWidget {
  const DiscoverFiltersSheet({super.key});

  @override
  State<DiscoverFiltersSheet> createState() => _DiscoverFiltersSheetState();
}

class _DiscoverFiltersSheetState extends State<DiscoverFiltersSheet> {
  late EventFilter _draft;
  late TextEditingController _cityCtrl;
  late TextEditingController _countryCtrl;

  @override
  void initState() {
    super.initState();
    _draft = context.read<EventsBloc>().state.filter;
    _cityCtrl = TextEditingController(text: _draft.city ?? '');
    _countryCtrl = TextEditingController(text: _draft.country ?? '');
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final city = _cityCtrl.text.trim();
    final country = _countryCtrl.text.trim();
    final updated = _draft.copyWith(
      city: city.isEmpty ? null : city,
      clearCity: city.isEmpty,
      country: country.isEmpty ? null : country,
      clearCountry: country.isEmpty,
      page: 1,
    );
    context.read<EventsBloc>().add(UpdateFilter(updated));
    Navigator.of(context).pop();
  }

  void _clearAll() {
    context.read<EventsBloc>().add(ClearAllFilters());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  const Text(
                    'Filter Events',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text(
                      'Clear all',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable content
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  // ── Date ──────────────────────────────────────────────────
                  _SectionLabel(label: 'Date'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Today',
                        icon: Icons.today_outlined,
                        selected: _draft.dateFilter == DateFilter.today,
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(
                            dateFilter: _draft.dateFilter == DateFilter.today
                                ? null
                                : DateFilter.today,
                            clearDateFilter: _draft.dateFilter == DateFilter.today,
                          );
                        }),
                      ),
                      _FilterChip(
                        label: 'This weekend',
                        icon: Icons.weekend_outlined,
                        selected: _draft.dateFilter == DateFilter.thisWeekend,
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(
                            dateFilter: _draft.dateFilter == DateFilter.thisWeekend
                                ? null
                                : DateFilter.thisWeekend,
                            clearDateFilter: _draft.dateFilter == DateFilter.thisWeekend,
                          );
                        }),
                      ),
                      _FilterChip(
                        label: 'This week',
                        icon: Icons.date_range_outlined,
                        selected: _draft.dateFilter == DateFilter.thisWeek,
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(
                            dateFilter: _draft.dateFilter == DateFilter.thisWeek
                                ? null
                                : DateFilter.thisWeek,
                            clearDateFilter: _draft.dateFilter == DateFilter.thisWeek,
                          );
                        }),
                      ),
                      _FilterChip(
                        label: 'This month',
                        icon: Icons.calendar_month_outlined,
                        selected: _draft.dateFilter == DateFilter.thisMonth,
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(
                            dateFilter: _draft.dateFilter == DateFilter.thisMonth
                                ? null
                                : DateFilter.thisMonth,
                            clearDateFilter: _draft.dateFilter == DateFilter.thisMonth,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Format ────────────────────────────────────────────────
                  _SectionLabel(label: 'Format'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Online',
                        icon: Icons.videocam_outlined,
                        selected: _draft.onlineOnly,
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(onlineOnly: !_draft.onlineOnly);
                        }),
                      ),
                      _FilterChip(
                        label: 'In-Person',
                        icon: Icons.location_on_outlined,
                        selected: !_draft.onlineOnly && _draft.eventType == 'offline',
                        onTap: () => setState(() {
                          final alreadyInPerson = _draft.eventType == 'offline';
                          _draft = _draft.copyWith(
                            eventType: alreadyInPerson ? null : 'offline',
                            clearEventType: alreadyInPerson,
                            onlineOnly: false,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Price ─────────────────────────────────────────────────
                  _SectionLabel(label: 'Price'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterChip(
                        label: 'Free',
                        icon: Icons.sell_outlined,
                        selected: _draft.freeOnly || _draft.pricingType == 'free',
                        onTap: () => setState(() {
                          final selected = _draft.freeOnly || _draft.pricingType == 'free';
                          _draft = _draft.copyWith(
                            freeOnly: !selected,
                            pricingType: selected ? null : 'free',
                            clearPricingType: selected,
                          );
                        }),
                      ),
                      _FilterChip(
                        label: 'Paid',
                        icon: Icons.credit_card_outlined,
                        selected: _draft.pricingType == 'paid',
                        onTap: () => setState(() {
                          final alreadyPaid = _draft.pricingType == 'paid';
                          _draft = _draft.copyWith(
                            pricingType: alreadyPaid ? null : 'paid',
                            clearPricingType: alreadyPaid,
                            freeOnly: false,
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Location ──────────────────────────────────────────────
                  _SectionLabel(label: 'Location'),
                  const SizedBox(height: 12),
                  _LocationField(
                    controller: _cityCtrl,
                    label: 'City',
                    hint: 'e.g. Riyadh, Istanbul, London',
                    icon: Icons.location_city_outlined,
                  ),
                  const SizedBox(height: 12),
                  _LocationField(
                    controller: _countryCtrl,
                    label: 'Country',
                    hint: 'e.g. Saudi Arabia, Turkey, UK',
                    icon: Icons.flag_outlined,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            // ── Apply button ──────────────────────────────────────────────
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                    ),
                    onPressed: _apply,
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : AppColors.background,
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      ),
    );
  }
}
