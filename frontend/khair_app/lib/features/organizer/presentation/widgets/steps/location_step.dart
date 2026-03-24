import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/locale/l10n_extension.dart';
import '../../../../../core/theme/app_design_system.dart';
import '../../../../../shared/widgets/app_components.dart';
import '../../../../../shared/widgets/map_location_picker.dart';
import '../../../../auth/data/models/country_model.dart';
import '../../../../auth/presentation/widgets/country_search_field.dart';
import '../../cubit/create_event_cubit.dart';
import '../../cubit/create_event_state.dart';

/// Step 2: Offline → Interactive map + address fields | Online → Platform + Link
class LocationStep extends StatefulWidget {
  const LocationStep({super.key});

  @override
  State<LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends State<LocationStep> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _linkCtrl;
  late final TextEditingController _passwordCtrl;

  List<Country> _countries = [];
  Country? _selectedCountry;
  bool _countriesLoading = true;

  @override
  void initState() {
    super.initState();
    final fd = context.read<CreateEventCubit>().state.formData;
    _cityCtrl = TextEditingController(text: fd.city ?? '');
    _addressCtrl = TextEditingController(text: fd.address ?? '');
    _linkCtrl = TextEditingController(text: fd.onlineLink ?? '');
    _passwordCtrl = TextEditingController(text: fd.onlinePassword ?? '');
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _countries = _defaultCountries;
      _countriesLoading = false;
    });
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _linkCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) =>
          p.formData.eventType != c.formData.eventType ||
          p.formData.countryCode != c.formData.countryCode ||
          p.formData.onlinePlatform != c.formData.onlinePlatform ||
          p.formData.latitude != c.formData.latitude ||
          p.formData.longitude != c.formData.longitude,
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final fd = state.formData;
        final isOffline = fd.eventType == 'offline';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isOffline) ...[
              // ── Map Location Picker ──
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.mapPickerTitle,
                            style: AppTypography.sectionTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.mapPickerTapToSelect,
                      style: TextStyle(
                        color: AppColors.whiteAlpha(0.4),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    MapLocationPicker(
                      initialLatitude: fd.latitude,
                      initialLongitude: fd.longitude,
                      searchHint: l10n.mapPickerSearchHint,
                      useCurrentLocationLabel:
                          l10n.mapPickerUseCurrentLocation,
                      tapToSelectLabel: l10n.mapPickerTapToSelect,
                      selectedLocationLabel:
                          l10n.mapPickerSelectedLocation,
                      searchingLabel: l10n.mapPickerSearching,
                      onLocationSelected:
                          (lat, lng, address, city, country, countryCode) {
                        // Auto-fill all location fields from map selection
                        if (city != null && city.isNotEmpty) {
                          _cityCtrl.text = city;
                        }
                        if (address != null && address.isNotEmpty) {
                          _addressCtrl.text = address;
                        }

                        // Find matching country in our list
                        Country? matchedCountry;
                        if (countryCode != null) {
                          try {
                            matchedCountry = _countries.firstWhere(
                              (c) =>
                                  c.isoCode.toLowerCase() ==
                                  countryCode.toLowerCase(),
                            );
                          } catch (_) {}
                        }

                        if (matchedCountry != null) {
                          setState(
                              () => _selectedCountry = matchedCountry);
                        }

                        cubit.updateFormData(fd.copyWith(
                          latitude: lat,
                          longitude: lng,
                          address: address,
                          city: city,
                          countryCode: matchedCountry?.isoCode ??
                              countryCode ??
                              fd.countryCode,
                          countryName: matchedCountry?.name ??
                              country ??
                              fd.countryName,
                        ));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Address Details (override/fine-tune) ──
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('✏️', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.createEventVenueDetails,
                            style: AppTypography.sectionTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.mapPickerRefineAddress,
                      style: TextStyle(
                        color: AppColors.whiteAlpha(0.4),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(l10n.createEventCountry,
                        style: AppTypography.label),
                    const SizedBox(height: AppSpacing.xs),
                    CountrySearchField(
                      countries: _countries,
                      selectedCountry: _selectedCountry,
                      isLoading: _countriesLoading,
                      onCountrySelected: (country) {
                        setState(() => _selectedCountry = country);
                        cubit.updateFormData(fd.copyWith(
                          countryCode: country.isoCode,
                          countryName: country.name,
                        ));
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppInputField(
                      controller: _cityCtrl,
                      label: l10n.city,
                      hint: l10n.createEventCityHint,
                      icon: Icons.location_city_rounded,
                      onChanged: (v) =>
                          cubit.updateFormData(fd.copyWith(city: v)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppInputField(
                      controller: _addressCtrl,
                      label: l10n.createEventAddress,
                      hint: l10n.createEventAddressHint,
                      icon: Icons.place_rounded,
                      maxLines: 2,
                      onChanged: (v) =>
                          cubit.updateFormData(fd.copyWith(address: v)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // ── Online Event ──
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('💻', style: TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.createEventOnlineSetup,
                            style: AppTypography.sectionTitle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(l10n.createEventPlatform,
                        style: AppTypography.label),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppChip(
                          label: 'Zoom',
                          icon: Icons.videocam_rounded,
                          isSelected: fd.onlinePlatform == 'zoom',
                          onTap: () => cubit.updateFormData(
                              fd.copyWith(onlinePlatform: 'zoom')),
                        ),
                        AppChip(
                          label: 'Google Meet',
                          icon: Icons.video_call_rounded,
                          isSelected: fd.onlinePlatform == 'meet',
                          onTap: () => cubit.updateFormData(
                              fd.copyWith(onlinePlatform: 'meet')),
                        ),
                        AppChip(
                          label: 'Teams',
                          icon: Icons.groups_rounded,
                          isSelected: fd.onlinePlatform == 'teams',
                          onTap: () => cubit.updateFormData(
                              fd.copyWith(onlinePlatform: 'teams')),
                        ),
                        AppChip(
                          label: 'Custom',
                          icon: Icons.link_rounded,
                          isSelected: fd.onlinePlatform == 'custom',
                          onTap: () => cubit.updateFormData(
                              fd.copyWith(onlinePlatform: 'custom')),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppInputField(
                      controller: _linkCtrl,
                      label: l10n.createEventMeetingLink,
                      hint: l10n.createEventMeetingLinkHint,
                      icon: Icons.link_rounded,
                      onChanged: (v) => cubit
                          .updateFormData(fd.copyWith(onlineLink: v)),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppInputField(
                      controller: _passwordCtrl,
                      label: l10n.createEventPasswordOptional,
                      hint: l10n.createEventPasswordHint,
                      icon: Icons.lock_rounded,
                      onChanged: (v) => cubit.updateFormData(
                          fd.copyWith(onlinePassword: v)),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.inputRadius,
                        color:
                            AppColors.info.withValues(alpha: 0.08),
                        border: Border.all(
                            color: AppColors.info
                                .withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🔒',
                              style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(l10n.createEventLinkVisibility,
                                    style: const TextStyle(
                                        color: AppColors.info,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.createEventLinkVisibilityDesc,
                                  style: TextStyle(
                                      color:
                                          AppColors.whiteAlpha(0.5),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Default country list
const _defaultCountries = [
  Country(id: 1, name: 'Saudi Arabia', isoCode: 'SA', phoneCode: '+966', flagEmoji: '🇸🇦', region: 'Middle East'),
  Country(id: 2, name: 'United Arab Emirates', isoCode: 'AE', phoneCode: '+971', flagEmoji: '🇦🇪', region: 'Middle East'),
  Country(id: 3, name: 'Egypt', isoCode: 'EG', phoneCode: '+20', flagEmoji: '🇪🇬', region: 'Africa'),
  Country(id: 4, name: 'Turkey', isoCode: 'TR', phoneCode: '+90', flagEmoji: '🇹🇷', region: 'Europe'),
  Country(id: 5, name: 'Malaysia', isoCode: 'MY', phoneCode: '+60', flagEmoji: '🇲🇾', region: 'Asia'),
  Country(id: 6, name: 'Indonesia', isoCode: 'ID', phoneCode: '+62', flagEmoji: '🇮🇩', region: 'Asia'),
  Country(id: 7, name: 'United Kingdom', isoCode: 'GB', phoneCode: '+44', flagEmoji: '🇬🇧', region: 'Europe'),
  Country(id: 8, name: 'United States', isoCode: 'US', phoneCode: '+1', flagEmoji: '🇺🇸', region: 'Americas'),
  Country(id: 9, name: 'Canada', isoCode: 'CA', phoneCode: '+1', flagEmoji: '🇨🇦', region: 'Americas'),
  Country(id: 10, name: 'France', isoCode: 'FR', phoneCode: '+33', flagEmoji: '🇫🇷', region: 'Europe'),
  Country(id: 11, name: 'Germany', isoCode: 'DE', phoneCode: '+49', flagEmoji: '🇩🇪', region: 'Europe'),
  Country(id: 12, name: 'Jordan', isoCode: 'JO', phoneCode: '+962', flagEmoji: '🇯🇴', region: 'Middle East'),
  Country(id: 13, name: 'Kuwait', isoCode: 'KW', phoneCode: '+965', flagEmoji: '🇰🇼', region: 'Middle East'),
  Country(id: 14, name: 'Qatar', isoCode: 'QA', phoneCode: '+974', flagEmoji: '🇶🇦', region: 'Middle East'),
  Country(id: 15, name: 'Bahrain', isoCode: 'BH', phoneCode: '+973', flagEmoji: '🇧🇭', region: 'Middle East'),
  Country(id: 16, name: 'Oman', isoCode: 'OM', phoneCode: '+968', flagEmoji: '🇴🇲', region: 'Middle East'),
  Country(id: 17, name: 'Pakistan', isoCode: 'PK', phoneCode: '+92', flagEmoji: '🇵🇰', region: 'Asia'),
  Country(id: 18, name: 'Bangladesh', isoCode: 'BD', phoneCode: '+880', flagEmoji: '🇧🇩', region: 'Asia'),
  Country(id: 19, name: 'Morocco', isoCode: 'MA', phoneCode: '+212', flagEmoji: '🇲🇦', region: 'Africa'),
  Country(id: 20, name: 'Tunisia', isoCode: 'TN', phoneCode: '+216', flagEmoji: '🇹🇳', region: 'Africa'),
];
