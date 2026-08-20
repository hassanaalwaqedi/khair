import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/navigation.dart';
import '../../../../shared/widgets/map_location_picker.dart';
import '../../../auth/data/datasources/countries_datasource.dart';
import '../../../auth/data/models/country_model.dart';
import '../../../auth/presentation/widgets/country_search_field.dart';
import '../../../events/domain/entities/event.dart';
import '../cubit/create_event_cubit.dart';
import '../cubit/create_event_state.dart';

class _CreateColors {
  static const rose = Color(0xFFF43F75);
  static const softRose = Color(0xFFFFF1F5);
  static const background = Color(0xFFFCFAFB);
  static const darkBackground = Color(0xFF101014);
  static const darkSurface = Color(0xFF19181E);
  static const text = Color(0xFF171126);
  static const muted = Color(0xFF726B7B);
  static const border = Color(0xFFEAE5E8);
  static const darkBorder = Color(0xFF302D35);
}

const _stepLabels = [
  'Basics',
  'Date & Location',
  'Audience',
  'Media',
  'Review'
];

class CreateEventPage extends StatelessWidget {
  const CreateEventPage({super.key, this.initialEvent});

  final Event? initialEvent;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = getIt<CreateEventCubit>()..loadCategories();
        if (initialEvent != null) {
          cubit.loadExistingEvent(initialEvent!);
        } else {
          cubit.loadLocalDraft();
        }
        return cubit;
      },
      child: _CreateEventView(),
    );
  }
}

class _CreateEventView extends StatefulWidget {
  const _CreateEventView();

  @override
  State<_CreateEventView> createState() => _CreateEventViewState();
}

class _CreateEventViewState extends State<_CreateEventView> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _categorySearch;
  late final TextEditingController _tags;
  late final TextEditingController _city;
  late final TextEditingController _venue;
  late final TextEditingController _address;
  late final TextEditingController _onlineLink;
  late final TextEditingController _onlineInstructions;
  late final TextEditingController _capacity;
  late final TextEditingController _guidelines;
  late final TextEditingController _priceAmount;
  late final TextEditingController _currency;
  final _countriesSource = CountriesDataSource(getIt<ApiClient>());
  final _imagePicker = ImagePicker();
  List<Country> _countries = const [];
  Country? _selectedCountry;
  bool _loadingCountries = true;
  String _categoryQuery = '';
  late final CreateEventCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<CreateEventCubit>();
    final data = _cubit.state.formData;
    _title = TextEditingController(text: data.title);
    _description = TextEditingController(text: data.description);
    _categorySearch = TextEditingController();
    _tags = TextEditingController();
    _city = TextEditingController(text: data.city ?? '');
    _venue = TextEditingController(text: data.venueName ?? '');
    _address = TextEditingController(text: data.address ?? '');
    _onlineLink = TextEditingController(text: data.onlineLink ?? '');
    _onlineInstructions =
        TextEditingController(text: data.onlineInstructions ?? '');
    _capacity = TextEditingController(text: data.capacity?.toString() ?? '');
    _guidelines = TextEditingController(text: data.guidelines);
    _priceAmount = TextEditingController(text: data.priceAmount ?? '');
    _currency = TextEditingController(text: data.currency ?? 'USD');
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final values = await _countriesSource.getAll();
      if (mounted) {
        final countryCode = _cubit.state.formData.countryCode?.toLowerCase();
        final selectedCountry = countryCode == null
            ? null
            : values
                .where(
                    (country) => country.isoCode.toLowerCase() == countryCode)
                .firstOrNull;
        setState(() {
          _countries = values;
          _selectedCountry = selectedCountry;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _countries = const []);
    } finally {
      if (mounted) setState(() => _loadingCountries = false);
    }
  }

  @override
  void dispose() {
    _cubit.disposeAutosave();
    for (final controller in [
      _title,
      _description,
      _categorySearch,
      _tags,
      _city,
      _venue,
      _address,
      _onlineLink,
      _onlineInstructions,
      _capacity,
      _guidelines,
      _priceAmount,
      _currency,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CreateEventCubit, CreateEventState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.isLocalDraftLoaded != current.isLocalDraftLoaded ||
          previous.aiDescriptionSuggestion != current.aiDescriptionSuggestion ||
          previous.aiCategorySuggestion != current.aiCategorySuggestion,
      listener: (context, state) {
        if (!state.isLocalDraftLoaded) return;

        if (state.status == CreateEventStatus.failure &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(_snack(state.errorMessage!, error: true));
        }
        if (state.status == CreateEventStatus.success) {
          _showSubmittedDialog();
        }

        // When the local draft finishes loading for the first time, populate controllers
        if (state.isLocalDraftLoaded) {
          final data = state.formData;
          if (_title.text != data.title) {
            _title.text = data.title;
          }
          if (_description.text != data.description) {
            _description.text = data.description;
          }
          if (_city.text != (data.city ?? '')) {
            _city.text = data.city ?? '';
          }
          if (_venue.text != (data.venueName ?? '')) {
            _venue.text = data.venueName ?? '';
          }
          if (_address.text != (data.address ?? '')) {
            _address.text = data.address ?? '';
          }
          if (_onlineLink.text != (data.onlineLink ?? '')) {
            _onlineLink.text = data.onlineLink ?? '';
          }
          if (_onlineInstructions.text != (data.onlineInstructions ?? '')) {
            _onlineInstructions.text = data.onlineInstructions ?? '';
          }
          final capStr = data.capacity?.toString() ?? '';
          if (_capacity.text != capStr) {
            _capacity.text = capStr;
          }
          if (_guidelines.text != data.guidelines) {
            _guidelines.text = data.guidelines;
          }
        }
      },
      child: BlocBuilder<CreateEventCubit, CreateEventState>(
        builder: (context, state) {
          final dark = Theme.of(context).brightness == Brightness.dark;
          return PopScope(
            canPop: state.currentStep == 0 && context.canNavigateBack,
            onPopInvokedWithResult: (didPop, result) {
              if (didPop) return;
              if (state.currentStep > 0) {
                context.read<CreateEventCubit>().previousStep();
              } else {
                context.popOrGo('/organizer');
              }
            },
            child: Scaffold(
              backgroundColor: dark
                  ? _CreateColors.darkBackground
                  : _CreateColors.background,
              body: SafeArea(
                child: Column(
                  children: [
                    _topBar(context, state, dark),
                    _progress(context, state, dark),
                    Expanded(child: _editor(context, state, dark)),
                  ],
                ),
              ),
              // Keep navigation pinned to the viewport. Putting it inside the
              // scrolling body allowed it to disappear below the editor on
              // shorter browser windows.
              bottomNavigationBar: SafeArea(
                top: false,
                child: _bottomBar(context, state, dark),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _topBar(BuildContext context, CreateEventState state, bool dark) {
    final savedLabel = switch (state.status) {
      CreateEventStatus.saving => 'Saving…',
      CreateEventStatus.saved => 'Saved just now',
      _ => 'Draft editor',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          _iconButton(
            Icons.close_rounded,
            () => context.popOrGo('/organizer'),
            dark,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.createAnEvent,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : _CreateColors.text)),
                Text(savedLabel,
                    style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.white54 : _CreateColors.muted)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: state.status == CreateEventStatus.saving
                ? null
                : () => context.read<CreateEventCubit>().saveDraft(),
            icon: Icon(Icons.bookmark_border_rounded, size: 18),
            label: Text(context.l10n.saveDraft),
            style: TextButton.styleFrom(foregroundColor: _CreateColors.rose),
          ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context, CreateEventState state, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 640) {
            return Row(
              children: [
                Text(context.l10n.createEventStep(state.currentStep + 1),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white : _CreateColors.text)),
                Text(
                    context.l10n
                        .createEventStepLabel(_stepLabels[state.currentStep]),
                    style: TextStyle(
                        color: dark ? Colors.white60 : _CreateColors.muted)),
                Spacer(),
                Text(
                    context.l10n.progressPercent(
                        ((state.currentStep + 1) / 5 * 100).round()),
                    style: TextStyle(
                        color: _CreateColors.rose,
                        fontWeight: FontWeight.w700)),
              ],
            );
          }
          return Row(
            children: _stepLabels.asMap().entries.map((entry) {
              final index = entry.key;
              final completed = index < state.currentStep;
              final current = index == state.currentStep;
              return Expanded(
                child: InkWell(
                  onTap: index <= state.currentStep ||
                          context
                              .read<CreateEventCubit>()
                              .validateStep(index - 1)
                      ? () => context.read<CreateEventCubit>().goToStep(index)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Container(
                                  height: 3,
                                  color: index == 0
                                      ? Colors.transparent
                                      : (completed
                                          ? _CreateColors.rose
                                          : (dark
                                              ? _CreateColors.darkBorder
                                              : _CreateColors.border)))),
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: completed
                                    ? _CreateColors.rose
                                    : (current
                                        ? _CreateColors.softRose
                                        : (dark
                                            ? _CreateColors.darkSurface
                                            : Colors.white)),
                                border: Border.all(
                                    color: current || completed
                                        ? _CreateColors.rose
                                        : (dark
                                            ? _CreateColors.darkBorder
                                            : _CreateColors.border),
                                    width: current ? 2 : 1)),
                            child: Icon(
                                completed ? Icons.check_rounded : Icons.circle,
                                size: completed ? 17 : 7,
                                color: completed || current
                                    ? _CreateColors.rose
                                    : (dark
                                        ? Colors.white38
                                        : _CreateColors.muted)),
                          ),
                          Expanded(
                              child: Container(
                                  height: 3,
                                  color: index == _stepLabels.length - 1
                                      ? Colors.transparent
                                      : (index < state.currentStep
                                          ? _CreateColors.rose
                                          : (dark
                                              ? _CreateColors.darkBorder
                                              : _CreateColors.border)))),
                        ]),
                        SizedBox(height: 5),
                        Text(
                            '${(index + 1).toString().padLeft(2, '0')}  ${entry.value}',
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    current ? FontWeight.w800 : FontWeight.w600,
                                color: current
                                    ? _CreateColors.rose
                                    : (dark
                                        ? Colors.white54
                                        : _CreateColors.muted))),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _editor(BuildContext context, CreateEventState state, bool dark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1050;
        final horizontalPadding = desktop ? 32.0 : 20.0;
        final availableWidth =
            (constraints.maxWidth - horizontalPadding * 2).clamp(0.0, 1180.0);
        final content = SingleChildScrollView(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 32),
          child: Center(
            child: SizedBox(
              width: availableWidth,
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Expanded(child: _stepContent(context, state, dark)),
                          SizedBox(width: 28),
                          SizedBox(width: 330, child: _LivePreview())
                        ])
                  : _stepContent(context, state, dark),
            ),
          ),
        );
        return content;
      },
    );
  }

  Widget _stepContent(BuildContext context, CreateEventState state, bool dark) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: 180),
      child: KeyedSubtree(
          key: ValueKey(state.currentStep),
          child: switch (state.currentStep) {
            0 => _basics(context, state, dark),
            1 => _dateLocation(context, state, dark),
            2 => _audience(context, state, dark),
            3 => _media(context, state, dark),
            _ => _review(context, state, dark),
          }),
    );
  }

  Widget _basics(BuildContext context, CreateEventState state, bool dark) {
    final cubit = context.read<CreateEventCubit>();
    final filtered = state.categoryOptions
        .where((value) => value.contains(_categoryQuery.toLowerCase()))
        .toList();
    return _stepFrame(
      title: context.l10n.letsStartWithTheBasics,
      subtitle: context.l10n.tellPeopleWhatYourEventIsAbout,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _field(
            label: context.l10n.eventTitle1,
            hint: 'Give your event a clear, memorable title',
            controller: _title,
            maxLength: 120,
            onChanged: cubit.updateTitle,
            dark: dark),
        _counter(_title.text.length, 120, dark),
        SizedBox(height: 22),
        _sectionLabel('Category', dark),
        SizedBox(height: 8),
        _field(
            label: '',
            hint: 'Search categories',
            controller: _categorySearch,
            prefix: Icons.search_rounded,
            onChanged: (value) => setState(() => _categoryQuery = value),
            dark: dark),
        SizedBox(height: 10),
        if (state.categoriesLoading)
          LinearProgressIndicator(color: _CreateColors.rose, minHeight: 2),
        if (!state.categoriesLoading && filtered.isEmpty)
          _hintBox(
              'Categories will appear here when they are available from Khair.',
              Icons.info_outline_rounded,
              dark),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filtered
                .map((category) => _choiceChip(
                    category,
                    state.formData.category == category,
                    () => cubit.updateCategory(category),
                    dark))
                .toList()),
        if (state.aiCategorySuggestion != null &&
            state.aiCategorySuggestion!.isNotEmpty)
          _aiSuggestion(
            icon: Icons.auto_awesome_rounded,
            title:
                'Khair AI suggests ${_titleCase(state.aiCategorySuggestion!)}',
            detail: state.aiCategoryReason ??
                'Based on your title and description.',
            action: 'Use suggestion',
            onAction: cubit.useCategorySuggestion,
            dark: dark,
          ),
        Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
                onPressed: state.status == CreateEventStatus.aiGenerating
                    ? null
                    : cubit.suggestCategory,
                icon: Icon(Icons.auto_awesome_rounded, size: 17),
                label: Text(context.l10n.suggestCategoryWithAi),
                style:
                    TextButton.styleFrom(foregroundColor: _CreateColors.rose))),
        SizedBox(height: 14),
        _sectionLabel('Description', dark),
        SizedBox(height: 8),
        _field(
            label: '',
            hint:
                'Tell people what to expect, who this event is for, and why they should join.',
            controller: _description,
            maxLines: 8,
            maxLength: 2000,
            onChanged: cubit.updateDescription,
            dark: dark),
        _counter(_description.text.length, 2000, dark, minimum: 50),
        _aiSuggestionEditor(context, state, dark),
        SizedBox(height: 16),
        _sectionLabel('Tags', dark),
        SizedBox(height: 8),
        _field(
            label: '',
            hint: 'Add tags such as networking, family, charity…',
            controller: _tags,
            prefix: Icons.tag_rounded,
            onSubmitted: (value) {
              cubit.addTag(value);
              _tags.clear();
            },
            dark: dark),
        SizedBox(height: 10),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            children: state.formData.tags
                .map((tag) => InputChip(
                    label: Text('#$tag'),
                    onDeleted: () => cubit.removeTag(tag),
                    selected: true,
                    selectedColor: _CreateColors.softRose,
                    side: BorderSide(color: _CreateColors.rose),
                    labelStyle: TextStyle(color: _CreateColors.rose)))
                .toList()),
        if (state.aiTagSuggestions.isNotEmpty)
          Wrap(
              spacing: 8,
              children: state.aiTagSuggestions
                  .map((tag) => ActionChip(
                      label: Text('+$tag'),
                      onPressed: () => cubit.useSuggestedTag(tag),
                      side: BorderSide(color: _CreateColors.border)))
                  .toList()),
        SizedBox(height: 22),
        _sectionLabel('Event format', dark),
        SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _selectCard(
                  Icons.location_on_outlined,
                  'In-person',
                  'Meet at a physical location',
                  state.formData.eventType == 'offline',
                  () => cubit.updateEventType('offline'),
                  dark)),
          SizedBox(width: 12),
          Expanded(
              child: _selectCard(
                  Icons.laptop_mac_outlined,
                  'Online',
                  'Host the event virtually',
                  state.formData.eventType == 'online',
                  () => cubit.updateEventType('online'),
                  dark))
        ]),
        SizedBox(height: 20),
        _sectionLabel('Event language', dark),
        SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          _choiceChip('English', state.formData.language == 'en',
              () => cubit.updateLanguage('en'), dark),
          _choiceChip('Arabic', state.formData.language == 'ar',
              () => cubit.updateLanguage('ar'), dark),
          _choiceChip('Turkish', state.formData.language == 'tr',
              () => cubit.updateLanguage('tr'), dark),
        ]),
      ]),
    );
  }

  Widget _dateLocation(
      BuildContext context, CreateEventState state, bool dark) {
    final cubit = context.read<CreateEventCubit>();
    final data = state.formData;
    return _stepFrame(
      title: context.l10n.whenAndWhereIsItHappening,
      subtitle: context.l10n.giveAttendeesTheDetailsTheyNee,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Date and time', dark),
        SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _dateButton(
                  context,
                  'Start date',
                  data.startDate,
                  (value) =>
                      cubit.updateFormData(data.copyWith(startDate: value)),
                  dark)),
          SizedBox(width: 10),
          Expanded(
              child: _timeButton(
                  context,
                  'Start time',
                  data.startTime,
                  (value) =>
                      cubit.updateFormData(data.copyWith(startTime: value)),
                  dark))
        ]),
        SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _dateButton(
                  context,
                  'End date (optional)',
                  data.endDate,
                  (value) =>
                      cubit.updateFormData(data.copyWith(endDate: value)),
                  dark)),
          SizedBox(width: 10),
          Expanded(
              child: _timeButton(
                  context,
                  'End time (optional)',
                  data.endTime,
                  (value) =>
                      cubit.updateFormData(data.copyWith(endTime: value)),
                  dark))
        ]),
        SizedBox(height: 10),
        _field(
            label: context.l10n.timezone,
            hint: 'UTC',
            controller: TextEditingController(text: data.timezone),
            prefix: Icons.schedule_rounded,
            onChanged: (value) =>
                cubit.updateFormData(data.copyWith(timezone: value)),
            dark: dark),
        SizedBox(height: 24),
        if (data.eventType == 'offline') ...[
          _sectionLabel('Location', dark),
          SizedBox(height: 8),
          if (_countries.isEmpty && !_loadingCountries)
            _hintBox(
                'Country data could not be loaded. Check your connection and try again.',
                Icons.cloud_off_rounded,
                dark),
          CountrySearchField(
              countries: _countries,
              selectedCountry: _selectedCountry,
              isLoading: _loadingCountries,
              onCountrySelected: (country) {
                setState(() => _selectedCountry = country);
                cubit.updateFormData(data.copyWith(
                    countryCode: country.isoCode, countryName: country.name));
              }),
          SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: _field(
                    label: context.l10n.city,
                    hint: 'Search or enter a city',
                    controller: _city,
                    prefix: Icons.location_city_outlined,
                    onChanged: (value) =>
                        cubit.updateFormData(data.copyWith(city: value)),
                    dark: dark)),
            SizedBox(width: 10),
            Expanded(
                child: _field(
                    label: context.l10n.venueName,
                    hint: 'Optional venue name',
                    controller: _venue,
                    prefix: Icons.business_outlined,
                    onChanged: (value) =>
                        cubit.updateFormData(data.copyWith(venueName: value)),
                    dark: dark))
          ]),
          SizedBox(height: 12),
          _field(
              label: context.l10n.streetAddress,
              hint: 'Street, building, district',
              controller: _address,
              maxLines: 2,
              prefix: Icons.place_outlined,
              onChanged: (value) =>
                  cubit.updateFormData(data.copyWith(address: value)),
              dark: dark),
          SizedBox(height: 16),
          Text(context.l10n.pinpointTheLocation,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : _CreateColors.text)),
          SizedBox(height: 8),
          ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: MapLocationPicker(
                  initialLatitude: data.latitude,
                  initialLongitude: data.longitude,
                  searchHint: 'Search location',
                  useCurrentLocationLabel: 'Use my location',
                  tapToSelectLabel: 'Tap to select',
                  selectedLocationLabel: 'Selected location',
                  searchingLabel: 'Searching…',
                  onLocationSelected:
                      (lat, lng, address, city, country, countryCode) {
                    _city.text = city ?? _city.text;
                    _address.text = address ?? _address.text;
                    final match = _countries
                        .where((item) =>
                            item.isoCode.toLowerCase() ==
                            (countryCode ?? '').toLowerCase())
                        .firstOrNull;
                    if (match != null) setState(() => _selectedCountry = match);
                    cubit.updateFormData(data.copyWith(
                        latitude: lat,
                        longitude: lng,
                        city: city ?? data.city,
                        address: address ?? data.address,
                        countryCode:
                            match?.isoCode ?? countryCode ?? data.countryCode,
                        countryName:
                            match?.name ?? country ?? data.countryName));
                  })),
        ] else ...[
          _sectionLabel('Online event details', dark),
          SizedBox(height: 10),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['zoom', 'meet', 'teams', 'other']
                  .map((value) => _choiceChip(
                      _titleCase(value),
                      data.onlinePlatform == value,
                      () => cubit
                          .updateFormData(data.copyWith(onlinePlatform: value)),
                      dark))
                  .toList()),
          SizedBox(height: 14),
          _field(
              label: context.l10n.meetingUrl,
              hint: 'https://…',
              controller: _onlineLink,
              prefix: Icons.link_rounded,
              keyboardType: TextInputType.url,
              onChanged: (value) =>
                  cubit.updateFormData(data.copyWith(onlineLink: value)),
              dark: dark),
          SizedBox(height: 12),
          _field(
              label: context.l10n.instructionsOptional,
              hint: 'Anything attendees should know before joining',
              controller: _onlineInstructions,
              maxLines: 4,
              prefix: Icons.notes_rounded,
              onChanged: (value) => cubit
                  .updateFormData(data.copyWith(onlineInstructions: value)),
              dark: dark),
          SizedBox(height: 12),
          _hintBox(
              'The meeting link is protected and is only shared with eligible attendees according to Khair’s access policy.',
              Icons.lock_outline_rounded,
              dark),
        ],
      ]),
    );
  }

  Widget _audience(BuildContext context, CreateEventState state, bool dark) {
    final cubit = context.read<CreateEventCubit>();
    final data = state.formData;
    return _stepFrame(
        title: context.l10n.whoIsThisEventFor,
        subtitle: context.l10n.setAttendanceAndAccessPreferen,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Audience', dark),
          SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _selectCard(
                    Icons.groups_outlined,
                    'Mixed',
                    'Open to everyone',
                    data.genderPolicy == 'mixed',
                    () => cubit.updateGenderPolicy('mixed'),
                    dark)),
            SizedBox(width: 10),
            Expanded(
                child: _selectCard(
                    Icons.man_outlined,
                    'Men',
                    'For male attendees',
                    data.genderPolicy == 'male_only',
                    () => cubit.updateGenderPolicy('male_only'),
                    dark)),
            SizedBox(width: 10),
            Expanded(
                child: _selectCard(
                    Icons.woman_outlined,
                    'Women',
                    'For female attendees',
                    data.genderPolicy == 'female_only',
                    () => cubit.updateGenderPolicy('female_only'),
                    dark))
          ]),
          SizedBox(height: 24),
          _sectionLabel('Age preference', dark),
          SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _choiceChip('All ages', data.agePolicy == 'all_ages',
                () => cubit.updateAgePolicy('all_ages'), dark),
            _choiceChip('18+', data.agePolicy == '18_plus',
                () => cubit.updateAgePolicy('18_plus'), dark),
            _choiceChip('Families', data.agePolicy == 'families',
                () => cubit.updateAgePolicy('families'), dark),
            _choiceChip('Custom', data.agePolicy == 'custom',
                () => cubit.updateAgePolicy('custom'), dark),
          ]),
          SizedBox(height: 24),
          _sectionLabel('Maximum attendees', dark),
          SizedBox(height: 8),
          Row(children: [
            ChoiceChip(
                label: Text(context.l10n.unlimited),
                selected: data.unlimitedCapacity,
                onSelected: (_) => cubit.updateCapacity(unlimited: true),
                selectedColor: _CreateColors.softRose,
                side: BorderSide(
                    color: data.unlimitedCapacity
                        ? _CreateColors.rose
                        : _CreateColors.border)),
            SizedBox(width: 8),
            ChoiceChip(
                label: Text(context.l10n.limited),
                selected: !data.unlimitedCapacity,
                onSelected: (_) => cubit.updateCapacity(
                    unlimited: false, value: int.tryParse(_capacity.text)),
                selectedColor: _CreateColors.softRose,
                side: BorderSide(
                    color: !data.unlimitedCapacity
                        ? _CreateColors.rose
                        : _CreateColors.border))
          ]),
          if (!data.unlimitedCapacity) ...[
            SizedBox(height: 10),
            _field(
                label: '',
                hint: '100',
                controller: _capacity,
                prefix: Icons.people_outline_rounded,
                keyboardType: TextInputType.number,
                onChanged: (value) => cubit.updateCapacity(
                    unlimited: false, value: int.tryParse(value)),
                dark: dark)
          ],
          SizedBox(height: 24),
          _sectionLabel('Registration', dark),
          SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _choiceChip(
                    'Instant join',
                    data.registrationMode == 'instant',
                    () => cubit.updateRegistrationMode('instant'),
                    dark)),
            SizedBox(width: 8),
            Expanded(
                child: _choiceChip(
                    'Approval required',
                    data.registrationMode == 'approval_required',
                    () => cubit.updateRegistrationMode('approval_required'),
                    dark))
          ]),
          SizedBox(height: 10),
          _dateButton(
              context,
              'Registration deadline (optional)',
              data.registrationDeadline,
              (value) => cubit
                  .updateFormData(data.copyWith(registrationDeadline: value)),
              dark),
          SizedBox(height: 24),
          _sectionLabel('Pricing', dark),
          SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _choiceChip('Free', data.pricingType == 'free',
                    () => cubit.updatePricingType('free'), dark)),
            SizedBox(width: 8),
            Expanded(
                child: _choiceChip('Paid', data.pricingType == 'paid', () {
              if (data.eventType == 'online') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text(context.l10n.paidOnlineEventsAreNotSupporte)),
                );
              } else {
                cubit.updatePricingType('paid');
              }
            }, dark))
          ]),
          if (data.pricingType == 'paid') ...[
            SizedBox(height: 16),
            Row(children: [
              Expanded(
                flex: 2,
                child: _field(
                  label: context.l10n.price,
                  hint: 'e.g. 50',
                  controller: _priceAmount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  prefix: Icons.attach_money_outlined,
                  onChanged: (val) => cubit.updatePriceAmount(val),
                  dark: dark,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _field(
                  label: context.l10n.currency,
                  hint: 'USD',
                  controller: _currency,
                  onChanged: (val) => cubit.updateCurrency(val),
                  dark: dark,
                ),
              ),
            ]),
            SizedBox(height: 8),
            _hintBox(
                'Payment will be collected at the venue. Khair does not process payments.',
                Icons.payments_outlined,
                dark),
          ],
          SizedBox(height: 18),
          _field(
              label: context.l10n.anythingAttendeesShouldKnowOpt,
              hint: 'Bring ID, arrive 15 minutes early…',
              controller: _guidelines,
              maxLines: 4,
              prefix: Icons.tips_and_updates_outlined,
              onChanged: (value) =>
                  cubit.updateFormData(data.copyWith(guidelines: value)),
              dark: dark),
        ]));
  }

  Widget _media(BuildContext context, CreateEventState state, bool dark) {
    final cubit = context.read<CreateEventCubit>();
    final url = state.formData.coverImageUrl;
    final previewBytes = state.formData.coverImagePreviewBytes;
    final uploading = state.status == CreateEventStatus.imageUploading;
    return _stepFrame(
        title: context.l10n.makeYourEventStandOut,
        subtitle:
            'Add a strong cover image so people instantly understand your event.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            onTap: uploading
                ? null
                : () async {
                    final picked = await _imagePicker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1800,
                        imageQuality: 88);
                    if (picked != null && mounted) cubit.uploadImage(picked);
                  },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
                duration: Duration(milliseconds: 180),
                height: 260,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: dark ? _CreateColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: url != null
                            ? _CreateColors.rose
                            : (dark
                                ? _CreateColors.darkBorder
                                : _CreateColors.border),
                        width: url != null ? 2 : 1)),
                child: previewBytes == null && url == null
                    ? _UploadEmpty()
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: Stack(fit: StackFit.expand, children: [
                          if (previewBytes != null)
                            Image.memory(
                              previewBytes,
                              fit: BoxFit.cover,
                              cacheWidth: 720,
                              cacheHeight: 405,
                            )
                          else
                            Image.network(ApiConfig.resolveUrl(url),
                                fit: BoxFit.cover,
                                cacheWidth: 720,
                                cacheHeight: 405,
                                errorBuilder: (_, __, ___) =>
                                    const _UploadEmpty()),
                          if (uploading)
                            ColoredBox(
                              color: const Color(0x88000000),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                        color: Colors.white),
                                    const SizedBox(height: 12),
                                    Text(context.l10n.imageUploading,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            Container(
                                decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                  Colors.transparent,
                                  Color(0x66000000)
                                ]))),
                            Positioned(
                                bottom: 16,
                                left: 18,
                                child: Text(context.l10n.replaceCoverImage,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700))),
                          ],
                        ]))),
          ),
          SizedBox(height: 10),
          Text(context.l10n.jpgPngOrWebpUpTo10Mb169Recomme,
              style: TextStyle(
                  fontSize: 13,
                  color: dark ? Colors.white54 : _CreateColors.muted)),
          SizedBox(height: 20),
          _hintBox(
              'A real image upload is required. The file is sent to Khair storage and the permanent URL is saved with your draft.',
              Icons.cloud_upload_outlined,
              dark),
          SizedBox(height: 18),
          _sectionLabel('Preview', dark),
          SizedBox(height: 10),
          const _LivePreview(compact: true),
        ]));
  }

  Widget _review(BuildContext context, CreateEventState state, bool dark) {
    final data = state.formData;
    final cubit = context.read<CreateEventCubit>();
    final checks = <MapEntry<String, bool>>[
      MapEntry('Event title', data.title.trim().isNotEmpty),
      MapEntry('Description', data.description.trim().length >= 50),
      MapEntry('Date', cubit.validateStep(1)),
      MapEntry(
          'Location',
          data.eventType == 'online'
              ? data.onlineLink?.isNotEmpty == true
              : data.latitude != null),
      MapEntry('Cover image', data.coverImageUrl?.isNotEmpty == true),
      MapEntry('Audience', data.genderPolicy.isNotEmpty),
      MapEntry('Capacity', data.unlimitedCapacity || (data.capacity ?? 0) > 0),
    ];
    return _stepFrame(
        title: context.l10n.reviewYourEvent,
        subtitle:
            'Make sure everything looks right before sending it to Khair moderation.',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _LivePreview(),
          SizedBox(height: 20),
          _panel(dark,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.readyToSubmit,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : _CreateColors.text)),
                    SizedBox(height: 14),
                    ...checks.map((item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: [
                          Icon(
                              item.value
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              size: 18,
                              color: item.value
                                  ? _CreateColors.rose
                                  : Colors.orange),
                          SizedBox(width: 10),
                          Text(item.key,
                              style: TextStyle(
                                  color: dark
                                      ? Colors.white70
                                      : _CreateColors.text,
                                  fontWeight: FontWeight.w600)),
                          if (!item.value) Spacer(),
                          if (!item.value)
                            Text(context.l10n.add,
                                style: TextStyle(
                                    color: _CreateColors.rose,
                                    fontWeight: FontWeight.w700))
                        ])))
                  ])),
          SizedBox(height: 18),
          _panel(dark,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.l10n.submission,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : _CreateColors.text)),
                    SizedBox(height: 8),
                    Text(
                        'Your event will be saved as pending review. It becomes discoverable only after admin approval.',
                        style: TextStyle(
                            color: dark ? Colors.white60 : _CreateColors.muted,
                            height: 1.45)),
                    SizedBox(height: 14),
                    CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: data.finalConfirmed,
                        onChanged: (value) =>
                            cubit.setFinalConfirmed(value ?? false),
                        activeColor: _CreateColors.rose,
                        title: Text(
                            'I confirm these event details are accurate.',
                            style: TextStyle(
                                color:
                                    dark ? Colors.white70 : _CreateColors.text,
                                fontWeight: FontWeight.w600)))
                  ])),
        ]));
  }

  Widget _stepFrame(
      {required String title,
      required String subtitle,
      required Widget child}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  color: dark ? Colors.white : _CreateColors.text)),
          SizedBox(height: 8),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: dark ? Colors.white60 : _CreateColors.muted)),
          SizedBox(height: 24),
          _panel(dark, child: child),
        ]);
  }

  Widget _panel(bool dark, {required Widget child}) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: dark ? _CreateColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: dark ? _CreateColors.darkBorder : _CreateColors.border),
          boxShadow: dark
              ? null
              : const [
                  BoxShadow(
                      color: Color(0x0A171126),
                      blurRadius: 24,
                      offset: Offset(0, 8))
                ]),
      child: child);

  Widget _sectionLabel(String label, bool dark) => Text(label,
      style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: dark ? Colors.white70 : _CreateColors.text));

  Widget _field(
      {required String label,
      required String hint,
      required TextEditingController controller,
      required bool dark,
      IconData? prefix,
      int maxLines = 1,
      int? maxLength,
      TextInputType? keyboardType,
      ValueChanged<String>? onChanged,
      ValueChanged<String>? onSubmitted}) {
    return TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        onChanged: (value) {
          onChanged?.call(value);
          if (mounted) setState(() {});
        },
        onSubmitted: onSubmitted,
        style: TextStyle(
            color: dark ? Colors.white : _CreateColors.text, fontSize: 15),
        decoration: InputDecoration(
            labelText: label.isEmpty ? null : label,
            hintText: hint,
            hintStyle:
                TextStyle(color: dark ? Colors.white38 : _CreateColors.muted),
            prefixIcon: prefix == null
                ? null
                : Icon(prefix,
                    size: 20,
                    color: dark ? Colors.white54 : _CreateColors.muted),
            counterText: '',
            filled: true,
            fillColor: dark ? Color(0x22101014) : Color(0xFFFCFAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: dark
                        ? _CreateColors.darkBorder
                        : _CreateColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                    color: dark
                        ? _CreateColors.darkBorder
                        : _CreateColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: _CreateColors.rose, width: 1.5))));
  }

  Widget _counter(int value, int max, bool dark, {int minimum = 0}) => Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Text(
              '$value / $max${minimum > 0 ? ' · minimum $minimum' : ''}',
              style: TextStyle(
                  fontSize: 12,
                  color: value > 0 && value < minimum
                      ? Colors.orange
                      : (dark ? Colors.white38 : _CreateColors.muted)))));

  Widget _choiceChip(
          String label, bool selected, VoidCallback onTap, bool dark) =>
      ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: _CreateColors.softRose,
          labelStyle: TextStyle(
              color: selected
                  ? _CreateColors.rose
                  : (dark ? Colors.white70 : _CreateColors.text),
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
          side: BorderSide(
              color: selected
                  ? _CreateColors.rose
                  : (dark ? _CreateColors.darkBorder : _CreateColors.border)));

  Widget _selectCard(IconData icon, String title, String subtitle,
      bool selected, VoidCallback onTap, bool dark) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? (dark ? Color(0x22F43F75) : _CreateColors.softRose)
              : (dark ? Color(0x22101014) : _CreateColors.background),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _CreateColors.rose
                : (dark ? _CreateColors.darkBorder : _CreateColors.border),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon,
                  color: selected
                      ? _CreateColors.rose
                      : (dark ? Colors.white54 : _CreateColors.muted)),
              Spacer(),
              if (selected)
                Icon(Icons.check_circle_rounded,
                    color: _CreateColors.rose, size: 19),
            ]),
            SizedBox(height: 12),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: dark ? Colors.white : _CreateColors.text)),
            SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(
                    fontSize: 12,
                    color: dark ? Colors.white54 : _CreateColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _dateButton(BuildContext context, String label, DateTime? value,
          ValueChanged<DateTime> onChanged, bool dark) =>
      InkWell(
          onTap: () async {
            final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now().add(Duration(days: 7)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(Duration(days: 730)));
            if (picked != null) onChanged(picked);
          },
          borderRadius: BorderRadius.circular(14),
          child: _displayField(
              Icons.calendar_today_outlined,
              label,
              value == null
                  ? 'Select date'
                  : DateFormat('EEE, MMM d, yyyy').format(value),
              dark));

  Widget _timeButton(BuildContext context, String label, TimeOfDay? value,
          ValueChanged<TimeOfDay> onChanged, bool dark) =>
      InkWell(
          onTap: () async {
            final picked = await showTimePicker(
                context: context,
                initialTime: value ?? TimeOfDay(hour: 9, minute: 0));
            if (picked != null) onChanged(picked);
          },
          borderRadius: BorderRadius.circular(14),
          child: _displayField(Icons.access_time_outlined, label,
              value?.format(context) ?? 'Select time', dark));

  Widget _displayField(IconData icon, String label, String value, bool dark) =>
      Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
              color: dark ? Color(0x22101014) : _CreateColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color:
                      dark ? _CreateColors.darkBorder : _CreateColors.border)),
          child: Row(children: [
            Icon(icon,
                size: 19, color: dark ? Colors.white54 : _CreateColors.muted),
            SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: dark ? Colors.white38 : _CreateColors.muted)),
                  SizedBox(height: 3),
                  Text(value,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: dark ? Colors.white : _CreateColors.text))
                ]))
          ]));

  Widget _hintBox(String text, IconData icon, bool dark) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: dark ? Color(0x22101014) : Color(0xFFF8F4F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: dark ? _CreateColors.darkBorder : _CreateColors.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 18, color: _CreateColors.rose),
        SizedBox(width: 10),
        Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: dark ? Colors.white60 : _CreateColors.muted)))
      ]));

  Widget _aiSuggestion(
          {required IconData icon,
          required String title,
          required String detail,
          required String action,
          required VoidCallback onAction,
          required bool dark}) =>
      Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: dark ? Color(0x22F43F75) : _CreateColors.softRose,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _CreateColors.rose.withValues(alpha: .35))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: _CreateColors.rose, size: 18),
            SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color: _CreateColors.rose,
                          fontWeight: FontWeight.w800)),
                  SizedBox(height: 3),
                  Text(detail,
                      style: TextStyle(
                          fontSize: 12,
                          color: dark ? Colors.white60 : _CreateColors.muted))
                ])),
            TextButton(
                onPressed: onAction,
                child: Text(action,
                    style: TextStyle(
                        color: _CreateColors.rose,
                        fontWeight: FontWeight.w800)))
          ]));

  Widget _aiSuggestionEditor(
      BuildContext context, CreateEventState state, bool dark) {
    final cubit = context.read<CreateEventCubit>();
    if (state.aiDescriptionSuggestion == null ||
        state.aiDescriptionSuggestion!.isEmpty) {
      final isDescriptionEmpty = state.formData.description.trim().isEmpty;
      return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
              onPressed: state.status == CreateEventStatus.aiGenerating
                  ? null
                  : cubit.suggestDescription,
              icon: Icon(Icons.auto_awesome_rounded, size: 17),
              label: Text(state.status == CreateEventStatus.aiGenerating
                  ? 'Khair AI is thinking…'
                  : isDescriptionEmpty
                      ? 'Generate description with Khair AI'
                      : 'Improve with Khair AI'),
              style:
                  TextButton.styleFrom(foregroundColor: _CreateColors.rose)));
    }
    return _aiSuggestion(
        icon: Icons.auto_awesome_rounded,
        title: context.l10n.aiSuggestion,
        detail: state.aiDescriptionSuggestion!,
        action: 'Use suggestion',
        onAction: () {
          final suggestion = state.aiDescriptionSuggestion;
          if (suggestion != null) {
            _description.text = suggestion;
          }
          cubit.useDescriptionSuggestion();
        },
        dark: dark);
  }

  Widget _bottomBar(BuildContext context, CreateEventState state, bool dark) {
    final cubit = context.read<CreateEventCubit>();
    final busy = state.status == CreateEventStatus.submitting ||
        state.status == CreateEventStatus.saving;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
      decoration: BoxDecoration(
        color: dark ? _CreateColors.darkSurface : Colors.white,
        border: Border(
            top: BorderSide(
                color: dark ? _CreateColors.darkBorder : _CreateColors.border)),
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                    color: Color(0x0A171126),
                    blurRadius: 18,
                    offset: Offset(0, -5))
              ],
      ),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 1180),
          child: Row(
            children: [
              if (!state.isFirstStep)
                OutlinedButton.icon(
                  onPressed: busy ? null : cubit.previousStep,
                  icon: Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(context.l10n.createEventBack),
                  style: OutlinedButton.styleFrom(
                      foregroundColor:
                          dark ? Colors.white70 : _CreateColors.text,
                      side: BorderSide(
                          color: dark
                              ? _CreateColors.darkBorder
                              : _CreateColors.border)),
                ),
              Spacer(),
              if (state.isLastStep)
                FilledButton.icon(
                  onPressed: busy ? null : cubit.submitEvent,
                  icon: busy
                      ? SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Icon(Icons.send_rounded, size: 17),
                  label: Text(busy
                      ? context.l10n.postingEvent
                      : context.l10n.postEvent),
                  style: FilledButton.styleFrom(
                      backgroundColor: _CreateColors.rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14)),
                )
              else
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          if (!cubit.nextStep()) {
                            ScaffoldMessenger.of(context).showSnackBar(_snack(
                                cubit.validationMessage(state.currentStep),
                                error: true));
                          }
                        },
                  icon: Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(context.l10n.createEventContinue),
                  style: FilledButton.styleFrom(
                      backgroundColor: _CreateColors.rose,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 14)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, VoidCallback onTap, bool dark) =>
      IconButton(
          onPressed: onTap,
          icon: Icon(icon),
          style: IconButton.styleFrom(
              backgroundColor: dark ? _CreateColors.darkSurface : Colors.white,
              foregroundColor: dark ? Colors.white70 : _CreateColors.text,
              side: BorderSide(
                  color:
                      dark ? _CreateColors.darkBorder : _CreateColors.border)));

  SnackBar _snack(String message, {required bool error}) => SnackBar(
      content: Text(message),
      backgroundColor: error ? Color(0xFFB4234B) : _CreateColors.rose,
      behavior: SnackBarBehavior.fixed);

  Future<void> _showSubmittedDialog() async {
    await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
                title: Text(context.l10n.yourEventIsUnderReview),
                content: Text(
                    'Your event has been submitted for review. We will notify you when moderation is complete.'),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(context.l10n.backToOrganizerHub))
                ]));

    if (mounted) {
      context.go('/organizer');
    }
  }
}

class _UploadEmpty extends StatelessWidget {
  const _UploadEmpty();
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.add_photo_alternate_outlined,
            size: 42, color: _CreateColors.rose),
        SizedBox(height: 12),
        Text(context.l10n.chooseACoverImage,
            style: TextStyle(
                fontWeight: FontWeight.w800, color: _CreateColors.text)),
        SizedBox(height: 5),
        Text(context.l10n.dragAndDropOrTapToBrowse,
            style: TextStyle(color: _CreateColors.muted))
      ]));
}

class _LivePreview extends StatelessWidget {
  final bool compact;
  const _LivePreview({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CreateEventCubit>().state;
    final data = state.formData;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final image = data.coverImageUrl;
    return Container(
        decoration: BoxDecoration(
            color: dark ? _CreateColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: dark ? _CreateColors.darkBorder : _CreateColors.border),
            boxShadow: dark
                ? null
                : const [
                    BoxShadow(
                        color: Color(0x0A171126),
                        blurRadius: 22,
                        offset: Offset(0, 8))
                  ]),
        clipBehavior: Clip.antiAlias,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact)
                Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: Row(children: [
                      Icon(Icons.visibility_outlined,
                          color: _CreateColors.rose, size: 18),
                      SizedBox(width: 8),
                      Text(context.l10n.livePreview,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: dark ? Colors.white : _CreateColors.text))
                    ])),
              SizedBox(
                  height: compact ? 150 : 180,
                  width: double.infinity,
                  child: data.coverImagePreviewBytes != null
                      ? Image.memory(
                          data.coverImagePreviewBytes!,
                          fit: BoxFit.cover,
                          cacheWidth: 720,
                          cacheHeight: 405,
                        )
                      : image == null
                          ? ColoredBox(
                              color: _CreateColors.softRose,
                              child: Center(
                                  child: Icon(Icons.event_outlined,
                                      color: _CreateColors.rose, size: 42)))
                          : Image.network(ApiConfig.resolveUrl(image),
                              fit: BoxFit.cover,
                              cacheWidth: 720,
                              cacheHeight: 405,
                              errorBuilder: (_, __, ___) => ColoredBox(
                                  color: _CreateColors.softRose,
                                  child: Center(
                                      child: Icon(Icons.event_outlined,
                                          color: _CreateColors.rose,
                                          size: 42))))),
              Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (data.category.isNotEmpty)
                          Text(_titleCase(data.category),
                              style: TextStyle(
                                  color: _CreateColors.rose,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        SizedBox(height: 7),
                        Text(
                            data.title.isEmpty
                                ? 'Your event title'
                                : data.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 19,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                color:
                                    dark ? Colors.white : _CreateColors.text)),
                        SizedBox(height: 12),
                        _previewLine(
                            Icons.calendar_today_outlined,
                            DateFormat('EEE, MMM d · h:mm a')
                                .format(data.startDateTime),
                            dark),
                        SizedBox(height: 7),
                        _previewLine(
                            data.eventType == 'online'
                                ? Icons.videocam_outlined
                                : Icons.place_outlined,
                            data.eventType == 'online'
                                ? 'Online event'
                                : (data.city?.isNotEmpty == true
                                    ? '${data.city}, ${data.countryName ?? ''}'
                                    : 'Location to be added'),
                            dark),
                        if (data.genderPolicy.isNotEmpty) ...[
                          SizedBox(height: 7),
                          _previewLine(
                              Icons.groups_outlined,
                              _titleCase(
                                  data.genderPolicy.replaceAll('_', ' ')),
                              dark)
                        ]
                      ]))
            ]));
  }

  Widget _previewLine(IconData icon, String text, bool dark) => Row(children: [
        Icon(icon,
            size: 15, color: dark ? Colors.white54 : _CreateColors.muted),
        SizedBox(width: 7),
        Expanded(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    color: dark ? Colors.white60 : _CreateColors.muted)))
      ]);
}

String _titleCase(String value) => value
    .split(RegExp(r'[_ -]+'))
    .where((item) => item.isNotEmpty)
    .map((item) => '${item[0].toUpperCase()}${item.substring(1)}')
    .join(' ');
