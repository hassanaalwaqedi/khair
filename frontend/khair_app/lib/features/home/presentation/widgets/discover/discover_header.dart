import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/l10n/generated/app_localizations.dart';

import '../../../../../core/layout/app_breakpoints.dart';
import '../../../../../core/theme/khair_theme.dart';
import '../../../../../tokens/tokens.dart';
import '../../../../../core/widgets/khair_brand.dart';
import '../../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../events/presentation/bloc/events_bloc.dart';
import '../../../../location/presentation/bloc/location_bloc.dart';
import '../../../../notifications/presentation/widgets/notification_bell_button.dart';

class DiscoverHeader extends StatelessWidget {
  const DiscoverHeader({super.key, required this.onLocation});
  final VoidCallback onLocation;

  @override
  Widget build(BuildContext context) {
    if (AppBreakpoints.isDesktop(context)) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const KhairBrand(
              size: 27,
              gap: 7,
              nameStyle: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            Expanded(child: _DiscoverLocationButton(onPressed: onLocation)),
            if (auth.isAuthenticated)
              const NotificationBellButton()
            else
              const SizedBox.shrink(),
            if (auth.isAuthenticated)
              IconButton(
                tooltip: AppLocalizations.of(context)!.profileTooltip,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => context.go('/profile'),
                icon: const Icon(Icons.account_circle_outlined,
                    size: 28, color: AppColors.textPrimary),
              )
            else
              TextButton(
                onPressed: () => context.go('/login'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: AppColors.primarySoft,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                child: Text(AppLocalizations.of(context)!.signIn,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiscoverLocationButton extends StatelessWidget {
  const _DiscoverLocationButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => BlocBuilder<EventsBloc, EventsState>(
        builder: (context, events) {
          final selectedCity = events.filter.city?.trim();
          return BlocBuilder<LocationBloc, LocationState>(
            builder: (context, location) {
              final cachedCity = location is LocationLoaded
                  ? location.location.city.trim()
                  : '';
              final city =
                  selectedCity?.isNotEmpty == true ? selectedCity! : cachedCity;
              final displayCity = city.isEmpty
                  ? AppLocalizations.of(context)!.chooseArea
                  : city;

              return Center(
                child: InkWell(
                  onTap: onPressed,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📍 ', style: TextStyle(fontSize: 16)),
                        Flexible(
                          child: Text(
                            displayCity,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down,
                            size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
}
