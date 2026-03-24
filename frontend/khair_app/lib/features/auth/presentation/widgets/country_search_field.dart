import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../data/models/country_model.dart';

/// Glassmorphic searchable country dropdown with flag emojis
class CountrySearchField extends StatefulWidget {
  final List<Country> countries;
  final Country? selectedCountry;
  final ValueChanged<Country> onCountrySelected;
  final bool isLoading;

  const CountrySearchField({
    super.key,
    required this.countries,
    required this.selectedCountry,
    required this.onCountrySelected,
    this.isLoading = false,
  });

  @override
  State<CountrySearchField> createState() => _CountrySearchFieldState();
}

class _CountrySearchFieldState extends State<CountrySearchField> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isOpen = false;
  List<Country> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _isOpen) {
        setState(() => _isOpen = false);
      }
    });
  }

  @override
  void didUpdateWidget(CountrySearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.countries != oldWidget.countries) {
      _filter(_searchController.text);
    }
  }

  void _filter(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.countries;
      } else {
        final q = query.toLowerCase();
        _filtered = widget.countries.where((c) {
          return c.name.toLowerCase().contains(q) ||
              c.isoCode.toLowerCase() == q ||
              c.phoneCode.contains(q);
        }).toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The "field" button that opens the dropdown
        GestureDetector(
          onTap: () {
            setState(() => _isOpen = !_isOpen);
            if (_isOpen) {
              _focusNode.requestFocus();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isOpen
                    ? AppColors.primary
                    : Colors.white.withValues(alpha: 0.12),
                width: _isOpen ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.public, color: Colors.white.withValues(alpha: 0.5), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: widget.isLoading
                      ? Text(
                          'Loading countries...',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                        )
                      : widget.selectedCountry != null
                          ? Text(
                              widget.selectedCountry!.shortLabel,
                              style: const TextStyle(color: Colors.white, fontSize: 15),
                            )
                          : Text(
                              'Select Country *',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
                            ),
                ),
                Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Dropdown
        if (_isOpen)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 280),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: _filter,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search country...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4), size: 18),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                // Results list
                Flexible(
                  child: _filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No countries found',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final country = _filtered[index];
                            final isSelected = widget.selectedCountry?.id == country.id;
                            return InkWell(
                              onTap: () {
                                widget.onCountrySelected(country);
                                setState(() {
                                  _isOpen = false;
                                  _searchController.clear();
                                  _filter('');
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : null,
                                child: Row(
                                  children: [
                                    Text(
                                      country.flagEmoji,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        country.name,
                                        style: TextStyle(
                                          color: isSelected ? AppColors.primary : Colors.white,
                                          fontSize: 13.5,
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      country.phoneCode,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.35),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 6),
                                      Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
