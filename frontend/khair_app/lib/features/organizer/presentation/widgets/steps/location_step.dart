import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/locale/l10n_extension.dart';
import '../../../../../core/theme/app_design_system.dart';
import '../../../../../shared/widgets/app_components.dart';
import '../../../../auth/data/models/country_model.dart';
import '../../../../auth/presentation/widgets/country_search_field.dart';
import '../../cubit/create_event_cubit.dart';
import '../../cubit/create_event_state.dart';

/// Step 2: Offline → Country + City + Address | Online → Platform + Link
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
    return BlocBuilder<CreateEventCubit, CreateEventState>(
      buildWhen: (p, c) =>
          p.formData.eventType != c.formData.eventType ||
          p.formData.countryCode != c.formData.countryCode ||
          p.formData.onlinePlatform != c.formData.onlinePlatform,
      builder: (context, state) {
        final cubit = context.read<CreateEventCubit>();
        final fd = state.formData;
        final isOffline = fd.eventType == 'offline';

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOffline ? context.l10n.createEventVenueDetails : context.l10n.createEventOnlineSetup,
                style: AppTypography.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.lg),

              if (isOffline) ...[
                Text(context.l10n.createEventCountry, style: AppTypography.label),
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
                  label: context.l10n.city,
                  hint: context.l10n.createEventCityHint,
                  icon: Icons.location_city_rounded,
                  onChanged: (v) =>
                      cubit.updateFormData(fd.copyWith(city: v)),
                ),
                const SizedBox(height: AppSpacing.md),
                AppInputField(
                  controller: _addressCtrl,
                  label: context.l10n.createEventAddress,
                  hint: context.l10n.createEventAddressHint,
                  icon: Icons.place_rounded,
                  maxLines: 2,
                  onChanged: (v) =>
                      cubit.updateFormData(fd.copyWith(address: v)),
                ),
              ] else ...[
                Text(context.l10n.createEventPlatform, style: AppTypography.label),
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
                  label: context.l10n.createEventMeetingLink,
                  hint: context.l10n.createEventMeetingLinkHint,
                  icon: Icons.link_rounded,
                  onChanged: (v) =>
                      cubit.updateFormData(fd.copyWith(onlineLink: v)),
                ),
                const SizedBox(height: AppSpacing.md),
                AppInputField(
                  controller: _passwordCtrl,
                  label: context.l10n.createEventPasswordOptional,
                  hint: context.l10n.createEventPasswordHint,
                  icon: Icons.lock_rounded,
                  onChanged: (v) => cubit.updateFormData(
                      fd.copyWith(onlinePassword: v)),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.inputRadius,
                    color: AppColors.info.withValues(alpha: 0.08),
                    border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.visibility_rounded,
                          color: AppColors.info, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(context.l10n.createEventLinkVisibility,
                                style: const TextStyle(
                                    color: AppColors.info,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              context.l10n.createEventLinkVisibilityDesc,
                              style: TextStyle(
                                  color: AppColors.whiteAlpha(0.5),
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
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
