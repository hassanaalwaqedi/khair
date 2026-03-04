import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/models/map_models.dart';

class FilterPanel extends StatefulWidget {
  const FilterPanel({
    super.key,
    required this.initialFilters,
    required this.options,
    required this.onApply,
  });

  final MapFilters initialFilters;
  final MapFilterOptions options;
  final ValueChanged<MapFilters> onApply;

  @override
  State<FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<FilterPanel> {
  late MapFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final radiusOptions = widget.options.radiusOptionsKm.isEmpty
        ? const [5, 10, 25, 50]
        : widget.options.radiusOptionsKm;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.mapFiltersTitle, style: theme.textTheme.titleLarge),
              const SizedBox(height: 14),
              Text(l10n.mapRadius, style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: radiusOptions.map((radius) {
                  return ChoiceChip(
                    label: Text('$radius km'),
                    selected: _draft.radiusKm.round() == radius,
                    onSelected: (_) => setState(() {
                      _draft = _draft.copyWith(radiusKm: radius.toDouble());
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Text(l10n.mapDate, style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: [
                  _dateChip(l10n.mapAny, MapDatePreset.any),
                  _dateChip(l10n.today, MapDatePreset.today),
                  _dateChip(l10n.mapWeekend, MapDatePreset.weekend),
                  _dateChip(l10n.mapCustom, MapDatePreset.custom),
                ],
              ),
              if (_draft.datePreset == MapDatePreset.custom) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _pickDateRange,
                  child: Text(
                    _draft.dateFrom != null && _draft.dateTo != null
                        ? '${_formatDate(_draft.dateFrom!)} - ${_formatDate(_draft.dateTo!)}'
                        : l10n.mapChooseDateRange,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Text(l10n.mapGender, style: theme.textTheme.titleSmall),
              DropdownButtonFormField<String>(
                initialValue: _draft.gender,
                hint: Text(l10n.mapAny),
                items: [
                  DropdownMenuItem(value: null, child: Text(l10n.mapAny)),
                  ...widget.options.genderRestrictions.map(
                    (gender) => DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _draft = _draft.copyWith(
                        gender: value, clearGender: value == null);
                  });
                },
              ),
              const SizedBox(height: 14),
              Text(l10n.mapAgePreference, style: theme.textTheme.titleSmall),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      min: 12,
                      max: 80,
                      divisions: 68,
                      value: (_draft.age ?? 25).toDouble(),
                      label: '${_draft.age ?? 25}',
                      onChanged: (value) {
                        setState(() {
                          _draft = _draft.copyWith(age: value.round());
                        });
                      },
                    ),
                  ),
                  Text('${_draft.age ?? 25}'),
                ],
              ),
              const SizedBox(height: 14),
              Text(l10n.mapCategories, style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.options.categories.map((category) {
                  final selected = _draft.categories.contains(category);
                  return FilterChip(
                    label: Text(category),
                    selected: selected,
                    onSelected: (on) {
                      final updated = Set<String>.from(_draft.categories);
                      if (on) {
                        updated.add(category);
                      } else {
                        updated.remove(category);
                      }
                      setState(() {
                        _draft = _draft.copyWith(categories: updated);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                value: _draft.freeOnly,
                onChanged: (value) =>
                    setState(() => _draft = _draft.copyWith(freeOnly: value)),
                title: Text(l10n.mapFreeEventsOnly),
                dense: true,
              ),
              SwitchListTile(
                value: _draft.almostFullOnly,
                onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(almostFullOnly: value)),
                title: Text(l10n.mapAlmostFull),
                dense: true,
              ),
              SwitchListTile(
                value: _draft.personalized,
                onChanged: (value) => setState(
                    () => _draft = _draft.copyWith(personalized: value)),
                title: Text(l10n.mapPersonalizedRecommendations),
                subtitle: Text(l10n.mapRequiresSignIn),
                dense: true,
              ),
              const SizedBox(height: 8),
              Text(l10n.mapContextLayers, style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: ContextLayerType.values.map((layer) {
                  final enabled = _draft.contextLayers.contains(layer);
                  return FilterChip(
                    selected: enabled,
                    label: Text(_contextLayerLabel(context, layer)),
                    onSelected: (on) {
                      final updated =
                          Set<ContextLayerType>.from(_draft.contextLayers);
                      if (on) {
                        updated.add(layer);
                      } else {
                        updated.remove(layer);
                      }
                      setState(() {
                        _draft = _draft.copyWith(contextLayers: updated);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _draft = const MapFilters();
                        });
                      },
                      child: Text(l10n.clear),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => widget.onApply(_draft),
                      child: Text(l10n.mapApply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ChoiceChip _dateChip(String label, MapDatePreset preset) {
    return ChoiceChip(
      label: Text(label),
      selected: _draft.datePreset == preset,
      onSelected: (_) => setState(() {
        _draft = _draft.copyWith(
          datePreset: preset,
          clearDateRange: preset != MapDatePreset.custom,
        );
      }),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      locale: Localizations.localeOf(context),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _draft.dateFrom != null && _draft.dateTo != null
          ? DateTimeRange(start: _draft.dateFrom!, end: _draft.dateTo!)
          : null,
    );
    if (result == null) return;
    setState(() {
      _draft = _draft.copyWith(
        datePreset: MapDatePreset.custom,
        dateFrom: result.start,
        dateTo: result.end,
      );
    });
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _contextLayerLabel(BuildContext context, ContextLayerType layer) {
    final l10n = AppLocalizations.of(context)!;
    switch (layer) {
      case ContextLayerType.mosque:
        return l10n.mapContextMosques;
      case ContextLayerType.islamicCenter:
        return l10n.mapContextIslamicCenters;
      case ContextLayerType.halalRestaurant:
        return l10n.mapContextHalalRestaurants;
    }
  }
}
