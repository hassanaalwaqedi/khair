import 'package:flutter/material.dart';

import '../../data/models/country_model.dart';

/// Shared country selector for organizer and profile forms.
class CountrySearchField extends StatelessWidget {
  final List<Country> countries;
  final Country? selectedCountry;
  final bool isLoading;
  final ValueChanged<Country> onCountrySelected;
  const CountrySearchField({
    super.key,
    required this.countries,
    required this.selectedCountry,
    required this.isLoading,
    required this.onCountrySelected,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const LinearProgressIndicator();
    return DropdownButtonFormField<Country>(
      key: ValueKey(selectedCountry?.isoCode),
      initialValue: selectedCountry,
      isExpanded: true,
      decoration: const InputDecoration(hintText: 'Select country'),
      items: countries
          .map((country) => DropdownMenuItem(
                value: country,
                child: Text('${country.flagEmoji}  ${country.name}'),
              ))
          .toList(),
      onChanged: (country) {
        if (country != null) onCountrySelected(country);
      },
    );
  }
}
