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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TextField(
        controller: controller,
        onChanged: onSearch,
        onSubmitted: onSearch,
        textInputAction: TextInputAction.search,
        style: const TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.searchEventsOrCities,
          hintStyle: const TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w400),
          prefixIcon: const Padding(
            padding: EdgeInsetsDirectional.only(start: 8.0),
            child: Icon(Icons.search_rounded, color: AppColors.textSecondary),
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
        IconButton(
          icon: Icon(
            Icons.tune_rounded,
            color: activeCount > 0 ? AppColors.primary : AppColors.primary,
          ),
          onPressed: onTap,
        ),
        if (activeCount > 0)
          Positioned(
            top: 8,
            right: 8,
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
