import 'package:flutter/material.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';
import '../../../../../tokens/tokens.dart';

class DiscoverSearchBar extends StatelessWidget {
  const DiscoverSearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onOpenFilters,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;
  final VoidCallback onOpenFilters;

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
          hintStyle: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w400),
          prefixIcon: const Padding(
            padding: EdgeInsetsDirectional.only(start: 8.0),
            child: Icon(Icons.search_rounded, color: AppColors.textSecondary),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
            onPressed: onOpenFilters,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
