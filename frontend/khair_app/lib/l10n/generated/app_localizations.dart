import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Khair'**
  String get appTitle;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover Meaningful Gatherings'**
  String get discoverTitle;

  /// No description provided for @discoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with knowledge, community, and purposeful events'**
  String get discoverSubtitle;

  /// No description provided for @searchGatherings.
  ///
  /// In en, this message translates to:
  /// **'Search gatherings...'**
  String get searchGatherings;

  /// No description provided for @khairCommunity.
  ///
  /// In en, this message translates to:
  /// **'Khair Community'**
  String get khairCommunity;

  /// No description provided for @searchEventsHint.
  ///
  /// In en, this message translates to:
  /// **'Search events, topics, cities...'**
  String get searchEventsHint;

  /// No description provided for @happeningInCommunity.
  ///
  /// In en, this message translates to:
  /// **'Happening in Your Community'**
  String get happeningInCommunity;

  /// No description provided for @motivationalLine1.
  ///
  /// In en, this message translates to:
  /// **'Indeed, with hardship comes ease 🌿'**
  String get motivationalLine1;

  /// No description provided for @motivationalLine2.
  ///
  /// In en, this message translates to:
  /// **'And We made you peoples and tribes so that you may know one another 🤍'**
  String get motivationalLine2;

  /// No description provided for @motivationalLine3.
  ///
  /// In en, this message translates to:
  /// **'Allah is Gentle with His servants 🌙'**
  String get motivationalLine3;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @heroTagline.
  ///
  /// In en, this message translates to:
  /// **'🌍 Connecting Communities Worldwide'**
  String get heroTagline;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover Islamic Events\nNear You'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find verified Islamic events, lectures, and gatherings in your community. Connect with trusted organizers and stay informed.'**
  String get heroSubtitle;

  /// No description provided for @browseEvents.
  ///
  /// In en, this message translates to:
  /// **'Browse Events'**
  String get browseEvents;

  /// No description provided for @registerOrganization.
  ///
  /// In en, this message translates to:
  /// **'Register Organization'**
  String get registerOrganization;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @organizations.
  ///
  /// In en, this message translates to:
  /// **'Organizations'**
  String get organizations;

  /// No description provided for @cities.
  ///
  /// In en, this message translates to:
  /// **'Cities'**
  String get cities;

  /// No description provided for @catKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get catKnowledge;

  /// No description provided for @catQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get catQuran;

  /// No description provided for @catLectures.
  ///
  /// In en, this message translates to:
  /// **'Lectures'**
  String get catLectures;

  /// No description provided for @catCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get catCommunity;

  /// No description provided for @catYouth.
  ///
  /// In en, this message translates to:
  /// **'Youth'**
  String get catYouth;

  /// No description provided for @catCharity.
  ///
  /// In en, this message translates to:
  /// **'Charity'**
  String get catCharity;

  /// No description provided for @catFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get catFamily;

  /// No description provided for @whyChooseKhair.
  ///
  /// In en, this message translates to:
  /// **'Why Choose Khair?'**
  String get whyChooseKhair;

  /// No description provided for @whyChooseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A trusted platform designed for the Muslim community'**
  String get whyChooseSubtitle;

  /// No description provided for @featureVerifiedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verified Organizers'**
  String get featureVerifiedTitle;

  /// No description provided for @featureVerifiedDesc.
  ///
  /// In en, this message translates to:
  /// **'All organizers are vetted to ensure authenticity and trust.'**
  String get featureVerifiedDesc;

  /// No description provided for @featureMapTitle.
  ///
  /// In en, this message translates to:
  /// **'Interactive Map'**
  String get featureMapTitle;

  /// No description provided for @featureMapDesc.
  ///
  /// In en, this message translates to:
  /// **'Discover events, mosques, and Islamic centers near you.'**
  String get featureMapDesc;

  /// No description provided for @featureLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-Language'**
  String get featureLanguageTitle;

  /// No description provided for @featureLanguageDesc.
  ///
  /// In en, this message translates to:
  /// **'Find events in your preferred language.'**
  String get featureLanguageDesc;

  /// No description provided for @featureDiscoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Discovery'**
  String get featureDiscoveryTitle;

  /// No description provided for @featureDiscoveryDesc.
  ///
  /// In en, this message translates to:
  /// **'Never miss important community events in your area.'**
  String get featureDiscoveryDesc;

  /// No description provided for @featureSafeTitle.
  ///
  /// In en, this message translates to:
  /// **'Safe & Moderated'**
  String get featureSafeTitle;

  /// No description provided for @featureSafeDesc.
  ///
  /// In en, this message translates to:
  /// **'Content is reviewed to maintain community standards.'**
  String get featureSafeDesc;

  /// No description provided for @featureCommunityTitle.
  ///
  /// In en, this message translates to:
  /// **'Global Community'**
  String get featureCommunityTitle;

  /// No description provided for @featureCommunityDesc.
  ///
  /// In en, this message translates to:
  /// **'Connect with Muslims worldwide through shared events.'**
  String get featureCommunityDesc;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How It Works'**
  String get howItWorks;

  /// No description provided for @step1Title.
  ///
  /// In en, this message translates to:
  /// **'Browse Events'**
  String get step1Title;

  /// No description provided for @step1Desc.
  ///
  /// In en, this message translates to:
  /// **'Explore upcoming events in your city or nearby.'**
  String get step1Desc;

  /// No description provided for @step2Title.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get step2Title;

  /// No description provided for @step2Desc.
  ///
  /// In en, this message translates to:
  /// **'Check event info, organizer profile, and location.'**
  String get step2Desc;

  /// No description provided for @step3Title.
  ///
  /// In en, this message translates to:
  /// **'Attend'**
  String get step3Title;

  /// No description provided for @step3Desc.
  ///
  /// In en, this message translates to:
  /// **'Join the event and connect with your community.'**
  String get step3Desc;

  /// No description provided for @ctaTitle.
  ///
  /// In en, this message translates to:
  /// **'Are You an Organization?'**
  String get ctaTitle;

  /// No description provided for @ctaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Register your mosque, center, or organization to publish events and reach your community.'**
  String get ctaSubtitle;

  /// No description provided for @footerAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get footerAbout;

  /// No description provided for @footerPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get footerPrivacy;

  /// No description provided for @footerTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get footerTerms;

  /// No description provided for @footerContent.
  ///
  /// In en, this message translates to:
  /// **'Content Policy'**
  String get footerContent;

  /// No description provided for @footerVerification.
  ///
  /// In en, this message translates to:
  /// **'Verification Policy'**
  String get footerVerification;

  /// No description provided for @footerCopyright.
  ///
  /// In en, this message translates to:
  /// **'© 2026 Khair. All rights reserved.'**
  String get footerCopyright;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome\nBack'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get signOutConfirmMessage;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @noAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get noAccount;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get enterEmail;

  /// No description provided for @validEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get validEmail;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get enterPassword;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create\nAccount'**
  String get createAccount;

  /// No description provided for @joinCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join the Khair community'**
  String get joinCommunity;

  /// No description provided for @organizationName.
  ///
  /// In en, this message translates to:
  /// **'Organization Name'**
  String get organizationName;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @enterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your organization name'**
  String get enterName;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsNoMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsNoMatch;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @notSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @accountInformation.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get accountInformation;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// No description provided for @organizerProfile.
  ///
  /// In en, this message translates to:
  /// **'Organizer Profile'**
  String get organizerProfile;

  /// No description provided for @organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organization;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @organizerDashboard.
  ///
  /// In en, this message translates to:
  /// **'Organizer Dashboard'**
  String get organizerDashboard;

  /// No description provided for @createNewEvent.
  ///
  /// In en, this message translates to:
  /// **'Create New Event'**
  String get createNewEvent;

  /// No description provided for @becomeOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Become an Organizer'**
  String get becomeOrganizer;

  /// No description provided for @adminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get adminPanel;

  /// No description provided for @createEvent.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get createEvent;

  /// No description provided for @basicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get basicInfo;

  /// No description provided for @eventTitle.
  ///
  /// In en, this message translates to:
  /// **'Event Title'**
  String get eventTitle;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @eventType.
  ///
  /// In en, this message translates to:
  /// **'Event Type'**
  String get eventType;

  /// No description provided for @dateAndTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get dateAndTime;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @reserveSeat.
  ///
  /// In en, this message translates to:
  /// **'Reserve Seat'**
  String get reserveSeat;

  /// No description provided for @attendGathering.
  ///
  /// In en, this message translates to:
  /// **'Attend Gathering'**
  String get attendGathering;

  /// No description provided for @emptyGatheringsTitle.
  ///
  /// In en, this message translates to:
  /// **'No gatherings available at the moment'**
  String get emptyGatheringsTitle;

  /// No description provided for @emptyGatheringsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check back soon for beneficial events'**
  String get emptyGatheringsSubtitle;

  /// No description provided for @verifiedOrg.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get verifiedOrg;

  /// No description provided for @seatsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} seats remaining'**
  String seatsRemaining(int count);

  /// No description provided for @reservationSuccess.
  ///
  /// In en, this message translates to:
  /// **'May this gathering bring benefit to you'**
  String get reservationSuccess;

  /// No description provided for @refreshEvents.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshEvents;

  /// No description provided for @filterByDate.
  ///
  /// In en, this message translates to:
  /// **'Filter by Date'**
  String get filterByDate;

  /// No description provided for @clearDateFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Date Filter'**
  String get clearDateFilter;

  /// No description provided for @noInternetConnection.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get noInternetConnection;

  /// No description provided for @backOnline.
  ///
  /// In en, this message translates to:
  /// **'Back online'**
  String get backOnline;

  /// No description provided for @eventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get eventNotFound;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noEventsFound.
  ///
  /// In en, this message translates to:
  /// **'No events found'**
  String get noEventsFound;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get arabic;

  /// No description provided for @switchLanguage.
  ///
  /// In en, this message translates to:
  /// **'Switch Language'**
  String get switchLanguage;

  /// No description provided for @pageNotFound.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get pageNotFound;

  /// No description provided for @goHome.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get goHome;

  /// No description provided for @toggleTheme.
  ///
  /// In en, this message translates to:
  /// **'Toggle theme'**
  String get toggleTheme;

  /// No description provided for @locating.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get locating;

  /// No description provided for @trending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trending;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get thisWeek;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @mapDiscoverNearbyEvents.
  ///
  /// In en, this message translates to:
  /// **'Discover nearby Islamic events'**
  String get mapDiscoverNearbyEvents;

  /// No description provided for @mapLoadingEvents.
  ///
  /// In en, this message translates to:
  /// **'Loading events...'**
  String get mapLoadingEvents;

  /// No description provided for @mapLoadingCachedResults.
  ///
  /// In en, this message translates to:
  /// **'Loading cached map results...'**
  String get mapLoadingCachedResults;

  /// No description provided for @mapFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Map Filters'**
  String get mapFiltersTitle;

  /// No description provided for @mapRadius.
  ///
  /// In en, this message translates to:
  /// **'Radius'**
  String get mapRadius;

  /// No description provided for @mapDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get mapDate;

  /// No description provided for @weekend.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get weekend;

  /// No description provided for @mapAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get mapAny;

  /// No description provided for @mapWeekend.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get mapWeekend;

  /// No description provided for @mapCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get mapCustom;

  /// No description provided for @mapChooseDateRange.
  ///
  /// In en, this message translates to:
  /// **'Choose date range'**
  String get mapChooseDateRange;

  /// No description provided for @mapGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get mapGender;

  /// No description provided for @mapAgePreference.
  ///
  /// In en, this message translates to:
  /// **'Age Preference'**
  String get mapAgePreference;

  /// No description provided for @mapCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get mapCategories;

  /// No description provided for @mapFreeEventsOnly.
  ///
  /// In en, this message translates to:
  /// **'Free events only'**
  String get mapFreeEventsOnly;

  /// No description provided for @mapAlmostFull.
  ///
  /// In en, this message translates to:
  /// **'Almost full'**
  String get mapAlmostFull;

  /// No description provided for @mapPersonalizedRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Personalized recommendations'**
  String get mapPersonalizedRecommendations;

  /// No description provided for @mapRequiresSignIn.
  ///
  /// In en, this message translates to:
  /// **'Requires signed-in account'**
  String get mapRequiresSignIn;

  /// No description provided for @mapContextLayers.
  ///
  /// In en, this message translates to:
  /// **'Context Layers'**
  String get mapContextLayers;

  /// No description provided for @mapApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get mapApply;

  /// No description provided for @mapVerifiedBadge.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get mapVerifiedBadge;

  /// No description provided for @mapRemainingSeats.
  ///
  /// In en, this message translates to:
  /// **'Remaining seats: {count}'**
  String mapRemainingSeats(int count);

  /// No description provided for @mapReserveSeat.
  ///
  /// In en, this message translates to:
  /// **'Reserve Seat'**
  String get mapReserveSeat;

  /// No description provided for @mapGetDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get mapGetDirections;

  /// No description provided for @mapDirectionsCopied.
  ///
  /// In en, this message translates to:
  /// **'Directions link copied to clipboard'**
  String get mapDirectionsCopied;

  /// No description provided for @mapKmAway.
  ///
  /// In en, this message translates to:
  /// **'{distance} km away'**
  String mapKmAway(String distance);

  /// No description provided for @mapRecommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get mapRecommended;

  /// No description provided for @mapEndingSoon.
  ///
  /// In en, this message translates to:
  /// **'Ending Soon'**
  String get mapEndingSoon;

  /// No description provided for @mapContextMosques.
  ///
  /// In en, this message translates to:
  /// **'Mosques'**
  String get mapContextMosques;

  /// No description provided for @mapContextIslamicCenters.
  ///
  /// In en, this message translates to:
  /// **'Islamic Centers'**
  String get mapContextIslamicCenters;

  /// No description provided for @mapContextHalalRestaurants.
  ///
  /// In en, this message translates to:
  /// **'Halal Restaurants'**
  String get mapContextHalalRestaurants;

  /// No description provided for @mapDistanceOrg.
  ///
  /// In en, this message translates to:
  /// **'{distance} km • {organization}'**
  String mapDistanceOrg(String distance, String organization);

  /// No description provided for @registrationBismillahArabic.
  ///
  /// In en, this message translates to:
  /// **'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ'**
  String get registrationBismillahArabic;

  /// No description provided for @registrationBismillahTranslation.
  ///
  /// In en, this message translates to:
  /// **'In the name of God, the Most Gracious, the Most Merciful'**
  String get registrationBismillahTranslation;

  /// No description provided for @registrationJoinUmmah.
  ///
  /// In en, this message translates to:
  /// **'Join the Ummah'**
  String get registrationJoinUmmah;

  /// No description provided for @registrationChooseContribution.
  ///
  /// In en, this message translates to:
  /// **'Choose how you\'d like to contribute to the community'**
  String get registrationChooseContribution;

  /// No description provided for @registrationContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get registrationContinue;

  /// No description provided for @registrationCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Your Account'**
  String get registrationCreateAccountTitle;

  /// No description provided for @registrationCredentialsSecure.
  ///
  /// In en, this message translates to:
  /// **'Your credentials are securely encrypted'**
  String get registrationCredentialsSecure;

  /// No description provided for @registrationFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get registrationFullName;

  /// No description provided for @registrationEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get registrationEnterFullName;

  /// No description provided for @registrationAboutYouTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell Us About You'**
  String get registrationAboutYouTitle;

  /// No description provided for @registrationAboutYouSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Help us personalize your experience'**
  String get registrationAboutYouSubtitle;

  /// No description provided for @registrationDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get registrationDisplayName;

  /// No description provided for @registrationEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get registrationEnterName;

  /// No description provided for @registrationBriefBioOptional.
  ///
  /// In en, this message translates to:
  /// **'Brief bio (optional)'**
  String get registrationBriefBioOptional;

  /// No description provided for @registrationOrganizationType.
  ///
  /// In en, this message translates to:
  /// **'Organization Type'**
  String get registrationOrganizationType;

  /// No description provided for @registrationOrgTypeMosque.
  ///
  /// In en, this message translates to:
  /// **'Mosque'**
  String get registrationOrgTypeMosque;

  /// No description provided for @registrationOrgTypeQuranCenter.
  ///
  /// In en, this message translates to:
  /// **'Quran Center'**
  String get registrationOrgTypeQuranCenter;

  /// No description provided for @registrationOrgTypeCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community Center'**
  String get registrationOrgTypeCommunity;

  /// No description provided for @registrationOrgTypeCharity.
  ///
  /// In en, this message translates to:
  /// **'Charity'**
  String get registrationOrgTypeCharity;

  /// No description provided for @registrationOrgTypeEducational.
  ///
  /// In en, this message translates to:
  /// **'Educational Institute'**
  String get registrationOrgTypeEducational;

  /// No description provided for @registrationOrgTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get registrationOrgTypeOther;

  /// No description provided for @registrationRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get registrationRequired;

  /// No description provided for @registrationSpecialization.
  ///
  /// In en, this message translates to:
  /// **'Specialization'**
  String get registrationSpecialization;

  /// No description provided for @registrationSpecializationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Fiqh, Tafseer, Hadith'**
  String get registrationSpecializationHint;

  /// No description provided for @registrationIjazahCertifications.
  ///
  /// In en, this message translates to:
  /// **'Ijazah & Certifications'**
  String get registrationIjazahCertifications;

  /// No description provided for @registrationDescribeCredentials.
  ///
  /// In en, this message translates to:
  /// **'Describe your credentials and qualifications'**
  String get registrationDescribeCredentials;

  /// No description provided for @registrationSubmitVerificationDocs.
  ///
  /// In en, this message translates to:
  /// **'You can submit verification documents after registration'**
  String get registrationSubmitVerificationDocs;

  /// No description provided for @registrationWelcomeIslam.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Islam!'**
  String get registrationWelcomeIslam;

  /// No description provided for @registrationWelcomeIslamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re here to support you on your journey. You\'ll be connected with mentors and resources.'**
  String get registrationWelcomeIslamSubtitle;

  /// No description provided for @registrationPreferredLearningLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred Learning Language'**
  String get registrationPreferredLearningLanguage;

  /// No description provided for @registrationLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get registrationLanguageEnglish;

  /// No description provided for @registrationLanguageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get registrationLanguageArabic;

  /// No description provided for @registrationLanguageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get registrationLanguageFrench;

  /// No description provided for @registrationLanguageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get registrationLanguageSpanish;

  /// No description provided for @registrationLanguageTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get registrationLanguageTurkish;

  /// No description provided for @registrationLanguageUrdu.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get registrationLanguageUrdu;

  /// No description provided for @registrationLearningGoals.
  ///
  /// In en, this message translates to:
  /// **'Learning Goals'**
  String get registrationLearningGoals;

  /// No description provided for @registrationLearningGoalsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Quran memorization, Arabic language, Islamic studies'**
  String get registrationLearningGoalsHint;

  /// No description provided for @registrationCurrentLevel.
  ///
  /// In en, this message translates to:
  /// **'Current Level'**
  String get registrationCurrentLevel;

  /// No description provided for @registrationLevelBeginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get registrationLevelBeginner;

  /// No description provided for @registrationLevelIntermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get registrationLevelIntermediate;

  /// No description provided for @registrationLevelAdvanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get registrationLevelAdvanced;

  /// No description provided for @registrationCommunityGroupName.
  ///
  /// In en, this message translates to:
  /// **'Community / Group Name'**
  String get registrationCommunityGroupName;

  /// No description provided for @registrationCommunityFocus.
  ///
  /// In en, this message translates to:
  /// **'Community Focus Area'**
  String get registrationCommunityFocus;

  /// No description provided for @registrationCommunityFocusHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Youth programs, da\'wah, social services'**
  String get registrationCommunityFocusHint;

  /// No description provided for @registrationSelectRolePrompt.
  ///
  /// In en, this message translates to:
  /// **'Please select a role to continue'**
  String get registrationSelectRolePrompt;

  /// No description provided for @registrationRoleStepTitleOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization Details'**
  String get registrationRoleStepTitleOrganization;

  /// No description provided for @registrationRoleStepTitleSheikh.
  ///
  /// In en, this message translates to:
  /// **'Scholar Profile'**
  String get registrationRoleStepTitleSheikh;

  /// No description provided for @registrationRoleStepTitleNewMuslim.
  ///
  /// In en, this message translates to:
  /// **'Welcome Journey'**
  String get registrationRoleStepTitleNewMuslim;

  /// No description provided for @registrationRoleStepTitleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student Profile'**
  String get registrationRoleStepTitleStudent;

  /// No description provided for @registrationRoleStepTitleCommunityOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer Details'**
  String get registrationRoleStepTitleCommunityOrganizer;

  /// No description provided for @registrationRoleStepTitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Additional Details'**
  String get registrationRoleStepTitleDefault;

  /// No description provided for @registrationRoleStepSubtitleOrganization.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your organization'**
  String get registrationRoleStepSubtitleOrganization;

  /// No description provided for @registrationRoleStepSubtitleSheikh.
  ///
  /// In en, this message translates to:
  /// **'Share your scholarly background'**
  String get registrationRoleStepSubtitleSheikh;

  /// No description provided for @registrationRoleStepSubtitleNewMuslim.
  ///
  /// In en, this message translates to:
  /// **'Help us personalize your experience'**
  String get registrationRoleStepSubtitleNewMuslim;

  /// No description provided for @registrationRoleStepSubtitleStudent.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your learning journey'**
  String get registrationRoleStepSubtitleStudent;

  /// No description provided for @registrationRoleStepSubtitleCommunityOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your community work'**
  String get registrationRoleStepSubtitleCommunityOrganizer;

  /// No description provided for @registrationRoleStepSubtitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Provide additional information'**
  String get registrationRoleStepSubtitleDefault;

  /// No description provided for @registrationReviewCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Review & Complete'**
  String get registrationReviewCompleteTitle;

  /// No description provided for @registrationReviewCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Make sure everything looks good before submitting'**
  String get registrationReviewCompleteSubtitle;

  /// No description provided for @registrationReviewName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get registrationReviewName;

  /// No description provided for @registrationVerificationEmailWillBeSent.
  ///
  /// In en, this message translates to:
  /// **'A verification email will be sent to {email}'**
  String registrationVerificationEmailWillBeSent(String email);

  /// No description provided for @registrationCompleteRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get registrationCompleteRegistration;

  /// No description provided for @registrationVerifyEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get registrationVerifyEmailTitle;

  /// No description provided for @registrationSentSixDigitCodeTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to'**
  String get registrationSentSixDigitCodeTo;

  /// No description provided for @registrationCodeExpiresInTenMinutes.
  ///
  /// In en, this message translates to:
  /// **'Code expires in 10 minutes'**
  String get registrationCodeExpiresInTenMinutes;

  /// No description provided for @registrationVerifyEmailButton.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get registrationVerifyEmailButton;

  /// No description provided for @registrationDidNotReceiveCode.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive the code? '**
  String get registrationDidNotReceiveCode;

  /// No description provided for @registrationResendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend'**
  String get registrationResendCode;

  /// No description provided for @registrationCheckSpamFolder.
  ///
  /// In en, this message translates to:
  /// **'Check your spam folder if you don\'t see the email'**
  String get registrationCheckSpamFolder;

  /// No description provided for @registrationWelcomeArabic.
  ///
  /// In en, this message translates to:
  /// **'أهلاً وسهلاً'**
  String get registrationWelcomeArabic;

  /// No description provided for @registrationCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration Complete!'**
  String get registrationCompleteTitle;

  /// No description provided for @registrationGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get registrationGetStarted;

  /// No description provided for @registrationCompleteYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get registrationCompleteYourProfile;

  /// No description provided for @registrationVerificationCodeResent.
  ///
  /// In en, this message translates to:
  /// **'Verification code has been resent'**
  String get registrationVerificationCodeResent;

  /// No description provided for @registrationUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred'**
  String get registrationUnexpectedError;

  /// No description provided for @registrationRoleOrganization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get registrationRoleOrganization;

  /// No description provided for @registrationRoleSheikh.
  ///
  /// In en, this message translates to:
  /// **'Sheikh / Teacher'**
  String get registrationRoleSheikh;

  /// No description provided for @registrationRoleNewMuslim.
  ///
  /// In en, this message translates to:
  /// **'New Muslim'**
  String get registrationRoleNewMuslim;

  /// No description provided for @registrationRoleStudent.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get registrationRoleStudent;

  /// No description provided for @registrationRoleCommunityOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Community Organizer'**
  String get registrationRoleCommunityOrganizer;

  /// No description provided for @registrationRoleDescOrganization.
  ///
  /// In en, this message translates to:
  /// **'Quran center, mosque, or community group'**
  String get registrationRoleDescOrganization;

  /// No description provided for @registrationRoleDescSheikh.
  ///
  /// In en, this message translates to:
  /// **'Scholar, teacher, or Islamic educator'**
  String get registrationRoleDescSheikh;

  /// No description provided for @registrationRoleDescNewMuslim.
  ///
  /// In en, this message translates to:
  /// **'Recently embraced Islam, seeking guidance'**
  String get registrationRoleDescNewMuslim;

  /// No description provided for @registrationRoleDescStudent.
  ///
  /// In en, this message translates to:
  /// **'Seeking knowledge of Quran, Arabic, or Fiqh'**
  String get registrationRoleDescStudent;

  /// No description provided for @registrationRoleDescCommunityOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Building and leading Muslim community groups'**
  String get registrationRoleDescCommunityOrganizer;

  /// No description provided for @registrationProgressRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get registrationProgressRole;

  /// No description provided for @registrationProgressAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get registrationProgressAccount;

  /// No description provided for @registrationProgressProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get registrationProgressProfile;

  /// No description provided for @registrationProgressDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get registrationProgressDetails;

  /// No description provided for @registrationProgressReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get registrationProgressReview;

  /// No description provided for @registrationProgressVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get registrationProgressVerify;

  /// No description provided for @registrationProgressDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get registrationProgressDone;

  /// No description provided for @spiritualQuoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Spiritual Reflection'**
  String get spiritualQuoteTitle;

  /// No description provided for @spiritualQuoteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'A spiritual reminder is not available right now.'**
  String get spiritualQuoteUnavailable;

  /// No description provided for @spiritualQuoteTypeQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get spiritualQuoteTypeQuran;

  /// No description provided for @spiritualQuoteTypeHadith.
  ///
  /// In en, this message translates to:
  /// **'Hadith'**
  String get spiritualQuoteTypeHadith;

  /// No description provided for @spiritualQuoteDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get spiritualQuoteDismiss;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
