import 'package:flutter/material.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';
import '../../../../../tokens/tokens.dart';

class DiscoverSearchBar extends StatelessWidget {
  const DiscoverSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onOpenFilters,
    this.activeFilterCount = 0,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenFilters;

  /// Number of active filters (excluding search query itself). When > 0, a
  /// badge is shown on the filter icon so the user knows filters are applied.
  final int activeFilterCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF211F26),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x260F0918),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFF302D35), width: 1),
      ),
      child: TextField(
        controller: controller,
        onChanged: onSearch,
        onSubmitted: onSearch,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchEventsOrCities,
          hintStyle: const TextStyle(
              color: Color(0xFFB7AFBC), fontWeight: FontWeight.w400),
          prefixIcon: const Padding(
            padding: EdgeInsetsDirectional.only(start: 8.0),
            child: Icon(Icons.search_rounded, color: Color(0xFFE7E1E9)),
          ),
          suffixIcon: _FilterIconButton(
            activeCount: activeFilterCount,
            onTap: onOpenFilters,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.activeCount, required this.onTap});
  final int activeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 7),
          child: Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.tune_rounded, color: Colors.white, size: 21),
              ),
            ),
          ),
        ),
        if (activeCount > 0)
          Positioned(
            top: 2,
            right: 2,
            child: Container(
              width: 16,
              height: 16,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  activeCount > 9 ? '9+' : activeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
