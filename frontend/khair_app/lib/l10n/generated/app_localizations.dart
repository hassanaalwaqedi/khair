import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

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
    Locale('en'),
    Locale('tr')
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

  /// No description provided for @welcomeToKhair.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Khair'**
  String get welcomeToKhair;

  /// No description provided for @signInToManage.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your profile and events'**
  String get signInToManage;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountType;

  /// No description provided for @roleOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Organizer'**
  String get roleOrganizer;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusBasic.
  ///
  /// In en, this message translates to:
  /// **'Basic'**
  String get statusBasic;

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

  /// No description provided for @mapTab.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get mapTab;

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

  /// No description provided for @useDeviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get useDeviceLanguage;

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

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

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

  /// No description provided for @registrationContactPersonName.
  ///
  /// In en, this message translates to:
  /// **'Contact Person Name'**
  String get registrationContactPersonName;

  /// No description provided for @registrationAccountDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Your Account'**
  String get registrationAccountDetailsTitle;

  /// No description provided for @registrationRoleSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'How Will You Use Khair?'**
  String get registrationRoleSelectionTitle;

  /// No description provided for @registrationRoleSelectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the role that best describes you'**
  String get registrationRoleSelectionSubtitle;

  /// No description provided for @roleDescSheikh.
  ///
  /// In en, this message translates to:
  /// **'Share Islamic knowledge and lead educational events'**
  String get roleDescSheikh;

  /// No description provided for @roleDescMosque.
  ///
  /// In en, this message translates to:
  /// **'Manage mosque activities and community prayers'**
  String get roleDescMosque;

  /// No description provided for @roleDescQuranCenter.
  ///
  /// In en, this message translates to:
  /// **'Organize Quran study circles and hifz programs'**
  String get roleDescQuranCenter;

  /// No description provided for @roleDescOrganization.
  ///
  /// In en, this message translates to:
  /// **'Run an Islamic charity, school, or institution'**
  String get roleDescOrganization;

  /// No description provided for @roleDescCommunityOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Plan social gatherings and community events'**
  String get roleDescCommunityOrganizer;

  /// No description provided for @roleDescStudent.
  ///
  /// In en, this message translates to:
  /// **'Discover and attend Islamic learning events'**
  String get roleDescStudent;

  /// No description provided for @roleDescNewMuslim.
  ///
  /// In en, this message translates to:
  /// **'Find welcoming communities and beginner resources'**
  String get roleDescNewMuslim;

  /// No description provided for @roleDescVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Help organize events and support the community'**
  String get roleDescVolunteer;

  /// No description provided for @roleDescMember.
  ///
  /// In en, this message translates to:
  /// **'Browse and attend events in your area'**
  String get roleDescMember;

  /// No description provided for @registrationAccountSubtitleSheikh.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your teaching background'**
  String get registrationAccountSubtitleSheikh;

  /// No description provided for @registrationAccountSubtitleOrg.
  ///
  /// In en, this message translates to:
  /// **'Set up your organization\'s account'**
  String get registrationAccountSubtitleOrg;

  /// No description provided for @registrationAccountSubtitleCommunity.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your community work'**
  String get registrationAccountSubtitleCommunity;

  /// No description provided for @registrationAccountSubtitleDefault.
  ///
  /// In en, this message translates to:
  /// **'Just the basics to get you started'**
  String get registrationAccountSubtitleDefault;

  /// No description provided for @registrationYearsExperience.
  ///
  /// In en, this message translates to:
  /// **'Years of Experience'**
  String get registrationYearsExperience;

  /// No description provided for @registrationSocialMediaOptional.
  ///
  /// In en, this message translates to:
  /// **'Social Media (optional)'**
  String get registrationSocialMediaOptional;

  /// No description provided for @registrationOrganizationName.
  ///
  /// In en, this message translates to:
  /// **'Organization Name'**
  String get registrationOrganizationName;

  /// No description provided for @registrationMosqueName.
  ///
  /// In en, this message translates to:
  /// **'Mosque Name'**
  String get registrationMosqueName;

  /// No description provided for @registrationCenterName.
  ///
  /// In en, this message translates to:
  /// **'Center Name'**
  String get registrationCenterName;

  /// No description provided for @registrationCommunityGroupName.
  ///
  /// In en, this message translates to:
  /// **'Community / Group Name'**
  String get registrationCommunityGroupName;

  /// No description provided for @registrationPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get registrationPhoneOptional;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @registrationEnterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name'**
  String get registrationEnterFullName;

  /// No description provided for @registrationGoalsTitle.
  ///
  /// In en, this message translates to:
  /// **'What Are You Hoping\nto Achieve?'**
  String get registrationGoalsTitle;

  /// No description provided for @registrationGoalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply — this helps us personalize your experience'**
  String get registrationGoalsSubtitle;

  /// No description provided for @registrationStepOptional.
  ///
  /// In en, this message translates to:
  /// **'This step is optional — you can skip it'**
  String get registrationStepOptional;

  /// No description provided for @goalPublishEvents.
  ///
  /// In en, this message translates to:
  /// **'Publish Events'**
  String get goalPublishEvents;

  /// No description provided for @goalGrowCommunity.
  ///
  /// In en, this message translates to:
  /// **'Grow Community'**
  String get goalGrowCommunity;

  /// No description provided for @goalTeachKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Teach Knowledge'**
  String get goalTeachKnowledge;

  /// No description provided for @goalDiscoverEvents.
  ///
  /// In en, this message translates to:
  /// **'Discover Local Gatherings'**
  String get goalDiscoverEvents;

  /// No description provided for @goalVolunteer.
  ///
  /// In en, this message translates to:
  /// **'Volunteer'**
  String get goalVolunteer;

  /// No description provided for @goalBuildNetwork.
  ///
  /// In en, this message translates to:
  /// **'Build Islamic Network'**
  String get goalBuildNetwork;

  /// No description provided for @registrationReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review Your Profile'**
  String get registrationReviewTitle;

  /// No description provided for @registrationReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please confirm everything looks correct'**
  String get registrationReviewSubtitle;

  /// No description provided for @registrationReviewAccountInfo.
  ///
  /// In en, this message translates to:
  /// **'Account Information'**
  String get registrationReviewAccountInfo;

  /// No description provided for @registrationReviewRoleDetails.
  ///
  /// In en, this message translates to:
  /// **'Role Details'**
  String get registrationReviewRoleDetails;

  /// No description provided for @registrationReviewGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get registrationReviewGoals;

  /// No description provided for @registrationReviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registrationReviewSubmit;

  /// No description provided for @registrationReviewTerms.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms & Privacy Policy'**
  String get registrationReviewTerms;

  /// No description provided for @mediaSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose Photo Source'**
  String get mediaSourceTitle;

  /// No description provided for @mediaSourceCamera.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get mediaSourceCamera;

  /// No description provided for @mediaSourceGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get mediaSourceGallery;

  /// No description provided for @mediaSourceRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove Photo'**
  String get mediaSourceRemove;

  /// No description provided for @mediaUploadTitle.
  ///
  /// In en, this message translates to:
  /// **'Upload Your Photo'**
  String get mediaUploadTitle;

  /// No description provided for @mediaUploadSubtitleOrg.
  ///
  /// In en, this message translates to:
  /// **'Add a logo or profile photo for your organization. This helps build trust with your community.'**
  String get mediaUploadSubtitleOrg;

  /// No description provided for @mediaUploadTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload'**
  String get mediaUploadTap;

  /// No description provided for @mediaUploadChange.
  ///
  /// In en, this message translates to:
  /// **'Change Photo'**
  String get mediaUploadChange;

  /// No description provided for @mediaUploadSuccess.
  ///
  /// In en, this message translates to:
  /// **'Uploaded successfully'**
  String get mediaUploadSuccess;

  /// No description provided for @eventDetailsBack.
  ///
  /// In en, this message translates to:
  /// **'Back to Events'**
  String get eventDetailsBack;

  /// No description provided for @eventDetailsShareSoon.
  ///
  /// In en, this message translates to:
  /// **'Share feature coming soon'**
  String get eventDetailsShareSoon;

  /// No description provided for @eventDetailsAttending.
  ///
  /// In en, this message translates to:
  /// **'{count} attending'**
  String eventDetailsAttending(int count);

  /// No description provided for @eventDetailsDateTime.
  ///
  /// In en, this message translates to:
  /// **'Date & Time'**
  String get eventDetailsDateTime;

  /// No description provided for @eventDetailsLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get eventDetailsLocation;

  /// No description provided for @eventDetailsOrganizedBy.
  ///
  /// In en, this message translates to:
  /// **'Organized by'**
  String get eventDetailsOrganizedBy;

  /// No description provided for @eventDetailsAbout.
  ///
  /// In en, this message translates to:
  /// **'About This Event'**
  String get eventDetailsAbout;

  /// No description provided for @eventDetailsSoldOut.
  ///
  /// In en, this message translates to:
  /// **'Sold Out'**
  String get eventDetailsSoldOut;

  /// No description provided for @eventDetailsSeatsLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} seats left'**
  String eventDetailsSeatsLeft(int count);

  /// No description provided for @eventDetailsJoin.
  ///
  /// In en, this message translates to:
  /// **'Join Event'**
  String get eventDetailsJoin;

  /// No description provided for @eventDetailsJoining.
  ///
  /// In en, this message translates to:
  /// **'Joining event...'**
  String get eventDetailsJoining;

  /// No description provided for @eventDetailsReservedSuccess.
  ///
  /// In en, this message translates to:
  /// **'You\'re in! Seat reserved successfully.'**
  String get eventDetailsReservedSuccess;

  /// No description provided for @eventDetailsJoinedSeeYou.
  ///
  /// In en, this message translates to:
  /// **'🎉 You\'ve joined \"{title}\"! See you there.'**
  String eventDetailsJoinedSeeYou(String title);

  /// No description provided for @eventDetailsJoinFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to join event'**
  String get eventDetailsJoinFailed;

  /// No description provided for @eventDetailsAlreadyJoined.
  ///
  /// In en, this message translates to:
  /// **'You have already joined this event'**
  String get eventDetailsAlreadyJoined;

  /// No description provided for @eventDetailsEventFull.
  ///
  /// In en, this message translates to:
  /// **'This event is full'**
  String get eventDetailsEventFull;

  /// No description provided for @eventDetailsEventEnded.
  ///
  /// In en, this message translates to:
  /// **'Event Ended'**
  String get eventDetailsEventEnded;

  /// No description provided for @eventDetailsAlreadyJoinedBtn.
  ///
  /// In en, this message translates to:
  /// **'✓ Joined'**
  String get eventDetailsAlreadyJoinedBtn;

  /// No description provided for @eventDetailsReservedHoldInfo.
  ///
  /// In en, this message translates to:
  /// **'Your seat is held for 10 minutes. Verify your email to confirm.'**
  String get eventDetailsReservedHoldInfo;

  /// No description provided for @joinModalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a simple account to reserve your seat.'**
  String get joinModalSubtitle;

  /// No description provided for @joinModalSeatsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} seats remaining'**
  String joinModalSeatsRemaining(int count);

  /// No description provided for @joinModalStep1.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get joinModalStep1;

  /// No description provided for @joinModalStep2.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get joinModalStep2;

  /// No description provided for @joinModalNameEmailTitle.
  ///
  /// In en, this message translates to:
  /// **'Your name & email'**
  String get joinModalNameEmailTitle;

  /// No description provided for @joinModalNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get joinModalNameRequired;

  /// No description provided for @joinModalNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 2 characters'**
  String get joinModalNameMinLength;

  /// No description provided for @joinModalSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get joinModalSignIn;

  /// No description provided for @joinModalAlreadyAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get joinModalAlreadyAccount;

  /// No description provided for @joinModalSecureAccount.
  ///
  /// In en, this message translates to:
  /// **'Secure your account'**
  String get joinModalSecureAccount;

  /// No description provided for @joinModalPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get joinModalPasswordMinLength;

  /// No description provided for @joinModalGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get joinModalGender;

  /// No description provided for @joinModalMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get joinModalMale;

  /// No description provided for @joinModalFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get joinModalFemale;

  /// No description provided for @joinModalGenderRequired.
  ///
  /// In en, this message translates to:
  /// **'Please select your gender'**
  String get joinModalGenderRequired;

  /// No description provided for @joinModalAgeOptional.
  ///
  /// In en, this message translates to:
  /// **'Age (optional)'**
  String get joinModalAgeOptional;

  /// No description provided for @joinModalCreateReserve.
  ///
  /// In en, this message translates to:
  /// **'Create Account & Reserve Seat'**
  String get joinModalCreateReserve;

  /// No description provided for @joinModalAlmostThere.
  ///
  /// In en, this message translates to:
  /// **'You\'re almost there!'**
  String get joinModalAlmostThere;

  /// No description provided for @joinModalVerifyEmailMsg.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email to confirm your seat.'**
  String get joinModalVerifyEmailMsg;

  /// No description provided for @joinModalEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get joinModalEmailRequired;

  /// No description provided for @joinModalSeatHeld.
  ///
  /// In en, this message translates to:
  /// **'Your seat is held for 15 minutes while you verify your email.'**
  String get joinModalSeatHeld;

  /// No description provided for @joinModalGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get joinModalGotIt;

  /// No description provided for @eventCardJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get eventCardJoin;

  /// No description provided for @eventCardLocationSoon.
  ///
  /// In en, this message translates to:
  /// **'Location announced soon'**
  String get eventCardLocationSoon;

  /// No description provided for @eventCardSeatsRatio.
  ///
  /// In en, this message translates to:
  /// **'{reserved} / {capacity} seats'**
  String eventCardSeatsRatio(int reserved, int capacity);

  /// No description provided for @categoryKnowledge.
  ///
  /// In en, this message translates to:
  /// **'Knowledge'**
  String get categoryKnowledge;

  /// No description provided for @categoryQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get categoryQuran;

  /// No description provided for @categoryLectures.
  ///
  /// In en, this message translates to:
  /// **'Lectures'**
  String get categoryLectures;

  /// No description provided for @categoryCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get categoryCommunity;

  /// No description provided for @categoryYouth.
  ///
  /// In en, this message translates to:
  /// **'Youth'**
  String get categoryYouth;

  /// No description provided for @categoryCharity.
  ///
  /// In en, this message translates to:
  /// **'Charity'**
  String get categoryCharity;

  /// No description provided for @categoryFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get categoryFamily;

  /// No description provided for @categoryTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get categoryTrending;

  /// No description provided for @filterEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Events'**
  String get filterEventsTitle;

  /// No description provided for @filterEventsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get filterEventsReset;

  /// No description provided for @filterEventsCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get filterEventsCountry;

  /// No description provided for @filterEventsType.
  ///
  /// In en, this message translates to:
  /// **'Event Type'**
  String get filterEventsType;

  /// No description provided for @eventTypeConference.
  ///
  /// In en, this message translates to:
  /// **'Conference'**
  String get eventTypeConference;

  /// No description provided for @eventTypeWorkshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get eventTypeWorkshop;

  /// No description provided for @eventTypeSeminar.
  ///
  /// In en, this message translates to:
  /// **'Seminar'**
  String get eventTypeSeminar;

  /// No description provided for @eventTypeFestival.
  ///
  /// In en, this message translates to:
  /// **'Festival'**
  String get eventTypeFestival;

  /// No description provided for @eventTypeMeetup.
  ///
  /// In en, this message translates to:
  /// **'Meetup'**
  String get eventTypeMeetup;

  /// No description provided for @eventTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get eventTypeOther;

  /// No description provided for @filterEventsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get filterEventsLanguage;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @langArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get langArabic;

  /// No description provided for @langFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get langFrench;

  /// No description provided for @langSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get langSpanish;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @filterEventsLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating...'**
  String get filterEventsLocating;

  /// No description provided for @filterEventsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get filterEventsToday;

  /// No description provided for @filterEventsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get filterEventsThisWeek;

  /// No description provided for @filterEventsWeekend.
  ///
  /// In en, this message translates to:
  /// **'Weekend'**
  String get filterEventsWeekend;

  /// No description provided for @filterEventsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get filterEventsThisMonth;

  /// No description provided for @filterEventsDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get filterEventsDate;

  /// No description provided for @filterEventsClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get filterEventsClear;

  /// No description provided for @filterEventsByDate.
  ///
  /// In en, this message translates to:
  /// **'Filter by Date'**
  String get filterEventsByDate;

  /// No description provided for @filterEventsClearDateFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Date Filter'**
  String get filterEventsClearDateFilter;

  /// No description provided for @createEventStepBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'Basic Info'**
  String get createEventStepBasicInfo;

  /// No description provided for @createEventStepLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get createEventStepLocation;

  /// No description provided for @createEventStepCompliance.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get createEventStepCompliance;

  /// No description provided for @createEventStepMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get createEventStepMedia;

  /// No description provided for @createEventStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get createEventStepReview;

  /// No description provided for @createEventSuccess.
  ///
  /// In en, this message translates to:
  /// **'Event submitted for review successfully!'**
  String get createEventSuccess;

  /// No description provided for @createEventError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get createEventError;

  /// No description provided for @createEventDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Event saved as draft'**
  String get createEventDraftSaved;

  /// No description provided for @createEventTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get createEventTitle;

  /// No description provided for @createEventStepCount.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String createEventStepCount(int current, int total);

  /// No description provided for @createEventBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get createEventBack;

  /// No description provided for @createEventSaveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save Draft'**
  String get createEventSaveDraft;

  /// No description provided for @createEventSubmitting.
  ///
  /// In en, this message translates to:
  /// **'Submitting...'**
  String get createEventSubmitting;

  /// No description provided for @createEventSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit for Review'**
  String get createEventSubmit;

  /// No description provided for @createEventContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get createEventContinue;

  /// No description provided for @createEventBasicInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get createEventBasicInfoTitle;

  /// No description provided for @createEventTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Event Title'**
  String get createEventTitleLabel;

  /// No description provided for @createEventTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a compelling event title'**
  String get createEventTitleHint;

  /// No description provided for @createEventCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get createEventCategoryLabel;

  /// No description provided for @createEventDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (min 50 characters)'**
  String get createEventDescLabel;

  /// No description provided for @createEventDescHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your event in detail...'**
  String get createEventDescHint;

  /// No description provided for @createEventTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get createEventTagsLabel;

  /// No description provided for @createEventEventTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Event Type'**
  String get createEventEventTypeLabel;

  /// No description provided for @createEventInPerson.
  ///
  /// In en, this message translates to:
  /// **'In-Person'**
  String get createEventInPerson;

  /// No description provided for @createEventOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get createEventOnline;

  /// No description provided for @createEventLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get createEventLanguageLabel;

  /// No description provided for @langTurkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get langTurkish;

  /// No description provided for @createEventStartDateTime.
  ///
  /// In en, this message translates to:
  /// **'Start Date & Time'**
  String get createEventStartDateTime;

  /// No description provided for @createEventEndDateTime.
  ///
  /// In en, this message translates to:
  /// **'End Date & Time (Optional)'**
  String get createEventEndDateTime;

  /// No description provided for @createEventVenueDetails.
  ///
  /// In en, this message translates to:
  /// **'Venue Details'**
  String get createEventVenueDetails;

  /// No description provided for @createEventOnlineSetup.
  ///
  /// In en, this message translates to:
  /// **'Online Setup'**
  String get createEventOnlineSetup;

  /// No description provided for @createEventCountry.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get createEventCountry;

  /// No description provided for @createEventCityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Riyadh'**
  String get createEventCityHint;

  /// No description provided for @createEventAddress.
  ///
  /// In en, this message translates to:
  /// **'Venue Address'**
  String get createEventAddress;

  /// No description provided for @createEventAddressHint.
  ///
  /// In en, this message translates to:
  /// **'Full venue address'**
  String get createEventAddressHint;

  /// No description provided for @createEventPlatform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get createEventPlatform;

  /// No description provided for @createEventMeetingLink.
  ///
  /// In en, this message translates to:
  /// **'Meeting Link'**
  String get createEventMeetingLink;

  /// No description provided for @createEventMeetingLinkHint.
  ///
  /// In en, this message translates to:
  /// **'https://zoom.us/j/...'**
  String get createEventMeetingLinkHint;

  /// No description provided for @createEventPasswordOptional.
  ///
  /// In en, this message translates to:
  /// **'Password (Optional)'**
  String get createEventPasswordOptional;

  /// No description provided for @createEventPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Meeting password'**
  String get createEventPasswordHint;

  /// No description provided for @createEventLinkVisibility.
  ///
  /// In en, this message translates to:
  /// **'Link Visibility'**
  String get createEventLinkVisibility;

  /// No description provided for @createEventLinkVisibilityDesc.
  ///
  /// In en, this message translates to:
  /// **'The meeting link will only be visible to registered attendees 30 minutes before the event.'**
  String get createEventLinkVisibilityDesc;

  /// No description provided for @createEventIslamicCompliance.
  ///
  /// In en, this message translates to:
  /// **'Islamic Compliance'**
  String get createEventIslamicCompliance;

  /// No description provided for @createEventComplianceDesc.
  ///
  /// In en, this message translates to:
  /// **'These settings ensure your event aligns with Islamic guidelines.'**
  String get createEventComplianceDesc;

  /// No description provided for @createEventGenderPolicy.
  ///
  /// In en, this message translates to:
  /// **'Gender Policy'**
  String get createEventGenderPolicy;

  /// No description provided for @createEventGenderMixed.
  ///
  /// In en, this message translates to:
  /// **'Mixed'**
  String get createEventGenderMixed;

  /// No description provided for @createEventGenderMaleOnly.
  ///
  /// In en, this message translates to:
  /// **'Male Only'**
  String get createEventGenderMaleOnly;

  /// No description provided for @createEventGenderFemaleOnly.
  ///
  /// In en, this message translates to:
  /// **'Female Only'**
  String get createEventGenderFemaleOnly;

  /// No description provided for @createEventAttendancePolicy.
  ///
  /// In en, this message translates to:
  /// **'Who can attend?'**
  String get createEventAttendancePolicy;

  /// No description provided for @createEventAttendanceEveryone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get createEventAttendanceEveryone;

  /// No description provided for @createEventAttendanceEveryoneDescription.
  ///
  /// In en, this message translates to:
  /// **'Open to everyone'**
  String get createEventAttendanceEveryoneDescription;

  /// No description provided for @createEventAttendanceMenOnly.
  ///
  /// In en, this message translates to:
  /// **'Men only'**
  String get createEventAttendanceMenOnly;

  /// No description provided for @createEventAttendanceMenOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'For male attendees'**
  String get createEventAttendanceMenOnlyDescription;

  /// No description provided for @createEventAttendanceWomenOnly.
  ///
  /// In en, this message translates to:
  /// **'Women only'**
  String get createEventAttendanceWomenOnly;

  /// No description provided for @createEventAttendanceWomenOnlyDescription.
  ///
  /// In en, this message translates to:
  /// **'For female attendees'**
  String get createEventAttendanceWomenOnlyDescription;

  /// No description provided for @createEventFamilyFriendly.
  ///
  /// In en, this message translates to:
  /// **'Family Friendly'**
  String get createEventFamilyFriendly;

  /// No description provided for @createEventFamilyFriendlyDesc.
  ///
  /// In en, this message translates to:
  /// **'Suitable for families with children'**
  String get createEventFamilyFriendlyDesc;

  /// No description provided for @createEventNoMusic.
  ///
  /// In en, this message translates to:
  /// **'No Music'**
  String get createEventNoMusic;

  /// No description provided for @createEventNoMusicDesc.
  ///
  /// In en, this message translates to:
  /// **'This event does not include music'**
  String get createEventNoMusicDesc;

  /// No description provided for @createEventNoInappropriate.
  ///
  /// In en, this message translates to:
  /// **'No Inappropriate Content'**
  String get createEventNoInappropriate;

  /// No description provided for @createEventNoInappropriateDesc.
  ///
  /// In en, this message translates to:
  /// **'All content is aligned with Islamic values'**
  String get createEventNoInappropriateDesc;

  /// No description provided for @createEventPrayerBreak.
  ///
  /// In en, this message translates to:
  /// **'Prayer Break Required'**
  String get createEventPrayerBreak;

  /// No description provided for @createEventPrayerBreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Include prayer breaks for events > 2 hours'**
  String get createEventPrayerBreakDesc;

  /// No description provided for @createEventComplianceConfirm.
  ///
  /// In en, this message translates to:
  /// **'I confirm this event fully complies with Islamic guidelines and Khair platform standards.'**
  String get createEventComplianceConfirm;

  /// No description provided for @createEventComplianceWarning.
  ///
  /// In en, this message translates to:
  /// **'You must confirm Islamic compliance before submitting.'**
  String get createEventComplianceWarning;

  /// No description provided for @createEventMediaDetails.
  ///
  /// In en, this message translates to:
  /// **'Media & Details'**
  String get createEventMediaDetails;

  /// No description provided for @createEventUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get createEventUploading;

  /// No description provided for @createEventUploadPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload cover image'**
  String get createEventUploadPlaceholder;

  /// No description provided for @createEventUploadLimits.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG • Max 5MB'**
  String get createEventUploadLimits;

  /// No description provided for @createEventMaxAttendees.
  ///
  /// In en, this message translates to:
  /// **'Max Attendees'**
  String get createEventMaxAttendees;

  /// No description provided for @createEventTicketPrice.
  ///
  /// In en, this message translates to:
  /// **'Ticket Price'**
  String get createEventTicketPrice;

  /// No description provided for @createEventTicketPriceHint.
  ///
  /// In en, this message translates to:
  /// **'0 = Free'**
  String get createEventTicketPriceHint;

  /// No description provided for @createEventRegistrationDeadline.
  ///
  /// In en, this message translates to:
  /// **'Registration Deadline'**
  String get createEventRegistrationDeadline;

  /// No description provided for @createEventSelectDeadline.
  ///
  /// In en, this message translates to:
  /// **'Select deadline'**
  String get createEventSelectDeadline;

  /// No description provided for @createEventAutoApproval.
  ///
  /// In en, this message translates to:
  /// **'Auto-Approval'**
  String get createEventAutoApproval;

  /// No description provided for @createEventAutoApprovalDesc.
  ///
  /// In en, this message translates to:
  /// **'Automatically approve registrations'**
  String get createEventAutoApprovalDesc;

  /// No description provided for @createEventReviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Review & Submit'**
  String get createEventReviewSubmit;

  /// No description provided for @createEventEventSummary.
  ///
  /// In en, this message translates to:
  /// **'Event Summary'**
  String get createEventEventSummary;

  /// No description provided for @createEventReviewCompliance.
  ///
  /// In en, this message translates to:
  /// **'Compliance'**
  String get createEventReviewCompliance;

  /// No description provided for @createEventReviewRiskAssessment.
  ///
  /// In en, this message translates to:
  /// **'Risk Assessment'**
  String get createEventReviewRiskAssessment;

  /// No description provided for @createEventReviewTrustImpact.
  ///
  /// In en, this message translates to:
  /// **'Trust Impact'**
  String get createEventReviewTrustImpact;

  /// No description provided for @createEventTrustImpactDesc.
  ///
  /// In en, this message translates to:
  /// **'Successfully hosting this event will increase your trust score. Flagged events may decrease it.'**
  String get createEventTrustImpactDesc;

  /// No description provided for @createEventFinalConfirm.
  ///
  /// In en, this message translates to:
  /// **'I confirm all information is accurate. I understand events are reviewed before publishing.'**
  String get createEventFinalConfirm;

  /// No description provided for @createEventRiskLow.
  ///
  /// In en, this message translates to:
  /// **'Low Risk — Likely auto-approved'**
  String get createEventRiskLow;

  /// No description provided for @createEventRiskMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium Risk — Manual review required'**
  String get createEventRiskMedium;

  /// No description provided for @createEventRiskHigh.
  ///
  /// In en, this message translates to:
  /// **'High Risk — Additional review required'**
  String get createEventRiskHigh;

  /// No description provided for @createEventReviewConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get createEventReviewConfirmed;

  /// No description provided for @createEventReviewIncluded.
  ///
  /// In en, this message translates to:
  /// **'Included'**
  String get createEventReviewIncluded;

  /// No description provided for @createEventReviewYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get createEventReviewYes;

  /// No description provided for @createEventReviewNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get createEventReviewNo;

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

  /// No description provided for @stepUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get stepUpload;

  /// No description provided for @stepGoals.
  ///
  /// In en, this message translates to:
  /// **'Goals'**
  String get stepGoals;

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

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboardTitle;

  /// No description provided for @adminRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get adminRefresh;

  /// No description provided for @adminOrganizersTab.
  ///
  /// In en, this message translates to:
  /// **'Organizers'**
  String get adminOrganizersTab;

  /// No description provided for @adminEventsTab.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get adminEventsTab;

  /// No description provided for @adminReportsTab.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get adminReportsTab;

  /// No description provided for @adminAuditLogsTab.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get adminAuditLogsTab;

  /// No description provided for @adminQuotesTab.
  ///
  /// In en, this message translates to:
  /// **'Quotes'**
  String get adminQuotesTab;

  /// No description provided for @adminUsersTab.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get adminUsersTab;

  /// No description provided for @adminActionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Action completed successfully'**
  String get adminActionSuccess;

  /// No description provided for @adminActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get adminActionFailed;

  /// No description provided for @adminReportsMgmt.
  ///
  /// In en, this message translates to:
  /// **'Reports Management'**
  String get adminReportsMgmt;

  /// No description provided for @adminReviewReportsDesc.
  ///
  /// In en, this message translates to:
  /// **'Review and resolve user reports'**
  String get adminReviewReportsDesc;

  /// No description provided for @adminOpenReports.
  ///
  /// In en, this message translates to:
  /// **'Open Reports'**
  String get adminOpenReports;

  /// No description provided for @adminAuditLogsDesc.
  ///
  /// In en, this message translates to:
  /// **'View all admin and system actions'**
  String get adminAuditLogsDesc;

  /// No description provided for @adminViewLogs.
  ///
  /// In en, this message translates to:
  /// **'View Logs'**
  String get adminViewLogs;

  /// No description provided for @adminFailedLoadOrg.
  ///
  /// In en, this message translates to:
  /// **'Failed to load organizers'**
  String get adminFailedLoadOrg;

  /// No description provided for @adminNoPendingOrg.
  ///
  /// In en, this message translates to:
  /// **'No Pending Organizers'**
  String get adminNoPendingOrg;

  /// No description provided for @adminAllOrgReviewed.
  ///
  /// In en, this message translates to:
  /// **'All organizer applications have been reviewed.'**
  String get adminAllOrgReviewed;

  /// No description provided for @adminPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval ({count})'**
  String adminPendingApproval(int count);

  /// No description provided for @adminType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adminType;

  /// No description provided for @adminLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get adminLocation;

  /// No description provided for @adminAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get adminAbout;

  /// No description provided for @adminSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get adminSubmitted;

  /// No description provided for @adminReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get adminReject;

  /// No description provided for @adminApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get adminApprove;

  /// No description provided for @adminRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject {name}'**
  String adminRejectTitle(String name);

  /// No description provided for @adminRejectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject \"{name}\"?'**
  String adminRejectConfirm(String name);

  /// No description provided for @adminRejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection reason'**
  String get adminRejectionReason;

  /// No description provided for @adminProvideReason.
  ///
  /// In en, this message translates to:
  /// **'Provide a reason...'**
  String get adminProvideReason;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminProvideReasonMsg.
  ///
  /// In en, this message translates to:
  /// **'Please provide a rejection reason'**
  String get adminProvideReasonMsg;

  /// No description provided for @adminFailedLoadEvents.
  ///
  /// In en, this message translates to:
  /// **'Failed to load events'**
  String get adminFailedLoadEvents;

  /// No description provided for @adminNoPendingEvents.
  ///
  /// In en, this message translates to:
  /// **'No Pending Events'**
  String get adminNoPendingEvents;

  /// No description provided for @adminAllEventsReviewed.
  ///
  /// In en, this message translates to:
  /// **'All events have been reviewed.'**
  String get adminAllEventsReviewed;

  /// No description provided for @adminPendingReview.
  ///
  /// In en, this message translates to:
  /// **'Pending Review ({count})'**
  String adminPendingReview(int count);

  /// No description provided for @adminDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get adminDate;

  /// No description provided for @orgBecomeOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Become an Organizer'**
  String get orgBecomeOrganizer;

  /// No description provided for @orgRegisterPrompt.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t registered as an organizer yet.\nRegister to start creating events!'**
  String get orgRegisterPrompt;

  /// No description provided for @orgRegisterBtn.
  ///
  /// In en, this message translates to:
  /// **'Register as Organizer'**
  String get orgRegisterBtn;

  /// No description provided for @orgDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get orgDashboardTitle;

  /// No description provided for @orgOrganizerDashboard.
  ///
  /// In en, this message translates to:
  /// **'Organizer Dashboard'**
  String get orgOrganizerDashboard;

  /// No description provided for @orgNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get orgNotifications;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @unreadNotificationsCount.
  ///
  /// In en, this message translates to:
  /// **'You have {count} unread notifications'**
  String unreadNotificationsCount(Object count);

  /// No description provided for @notificationsAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up!'**
  String get notificationsAllCaughtUp;

  /// No description provided for @pushNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Push notifications on'**
  String get pushNotificationsOn;

  /// No description provided for @pushNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Push notifications off'**
  String get pushNotificationsOff;

  /// No description provided for @orgSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get orgSettings;

  /// No description provided for @orgCheckHomeNotif.
  ///
  /// In en, this message translates to:
  /// **'Check home page for notifications'**
  String get orgCheckHomeNotif;

  /// No description provided for @orgQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get orgQuickActions;

  /// No description provided for @orgAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get orgAnalytics;

  /// No description provided for @orgRecentEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent Events'**
  String get orgRecentEvents;

  /// No description provided for @orgTotalCount.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String orgTotalCount(int count);

  /// No description provided for @orgViewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get orgViewAll;

  /// No description provided for @orgWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get orgWelcomeBack;

  /// No description provided for @orgAccountPending.
  ///
  /// In en, this message translates to:
  /// **'Account Pending Approval'**
  String get orgAccountPending;

  /// No description provided for @orgAccountPendingDesc.
  ///
  /// In en, this message translates to:
  /// **'Your organizer account is awaiting admin approval. Some features are restricted until approved.'**
  String get orgAccountPendingDesc;

  /// No description provided for @orgAccountRejected.
  ///
  /// In en, this message translates to:
  /// **'Account Rejected'**
  String get orgAccountRejected;

  /// No description provided for @orgAccountRejectedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your application was rejected. Please contact support for details.'**
  String get orgAccountRejectedDesc;

  /// No description provided for @orgCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get orgCreateEvent;

  /// No description provided for @orgAddNewEvent.
  ///
  /// In en, this message translates to:
  /// **'Add a new event'**
  String get orgAddNewEvent;

  /// No description provided for @orgApprovalRequired.
  ///
  /// In en, this message translates to:
  /// **'Approval required'**
  String get orgApprovalRequired;

  /// No description provided for @orgMyEvents.
  ///
  /// In en, this message translates to:
  /// **'My Events'**
  String get orgMyEvents;

  /// No description provided for @orgViewAllEvents.
  ///
  /// In en, this message translates to:
  /// **'View all events'**
  String get orgViewAllEvents;

  /// No description provided for @orgEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get orgEditProfile;

  /// No description provided for @orgUpdateInfo.
  ///
  /// In en, this message translates to:
  /// **'Update info'**
  String get orgUpdateInfo;

  /// No description provided for @orgViewStats.
  ///
  /// In en, this message translates to:
  /// **'View stats'**
  String get orgViewStats;

  /// No description provided for @orgTotalEvents.
  ///
  /// In en, this message translates to:
  /// **'Total Events'**
  String get orgTotalEvents;

  /// No description provided for @orgApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get orgApproved;

  /// No description provided for @orgPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get orgPending;

  /// No description provided for @orgRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get orgRejected;

  /// No description provided for @orgNoEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No events yet'**
  String get orgNoEventsYet;

  /// No description provided for @orgCreateFirstEvent.
  ///
  /// In en, this message translates to:
  /// **'Create your first event to get started'**
  String get orgCreateFirstEvent;

  /// No description provided for @orgMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get orgMessages;

  /// No description provided for @orgNoMessages.
  ///
  /// In en, this message translates to:
  /// **'No messages'**
  String get orgNoMessages;

  /// No description provided for @ownerDashboard.
  ///
  /// In en, this message translates to:
  /// **'Owner Dashboard'**
  String get ownerDashboard;

  /// No description provided for @ownerPostSaved.
  ///
  /// In en, this message translates to:
  /// **'Post saved'**
  String get ownerPostSaved;

  /// No description provided for @ownerNoPosts.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get ownerNoPosts;

  /// No description provided for @ownerCreateFirstPost.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create your first community post'**
  String get ownerCreateFirstPost;

  /// No description provided for @ownerNewPost.
  ///
  /// In en, this message translates to:
  /// **'New Post'**
  String get ownerNewPost;

  /// No description provided for @ownerEditPost.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get ownerEditPost;

  /// No description provided for @ownerTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get ownerTitleLabel;

  /// No description provided for @ownerShortDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Short Description *'**
  String get ownerShortDescLabel;

  /// No description provided for @ownerImageUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get ownerImageUrlLabel;

  /// No description provided for @ownerExtLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'External Link'**
  String get ownerExtLinkLabel;

  /// No description provided for @ownerLocationLabel.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get ownerLocationLabel;

  /// No description provided for @ownerPublish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get ownerPublish;

  /// No description provided for @ownerSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get ownerSaveChanges;

  /// No description provided for @ownerRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get ownerRequired;

  /// No description provided for @ownerActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get ownerActive;

  /// No description provided for @ownerInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get ownerInactive;

  /// No description provided for @ownerEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get ownerEdit;

  /// No description provided for @ownerDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get ownerDelete;

  /// No description provided for @ownerDeletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete Post'**
  String get ownerDeletePost;

  /// No description provided for @ownerDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get ownerDeleteConfirm;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum'**
  String get greeting;

  /// No description provided for @featuredEvents.
  ///
  /// In en, this message translates to:
  /// **'Featured Events'**
  String get featuredEvents;

  /// No description provided for @joinNow.
  ///
  /// In en, this message translates to:
  /// **'Join Now'**
  String get joinNow;

  /// No description provided for @byOrganizer.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String byOrganizer(String name);

  /// No description provided for @communityActivity.
  ///
  /// In en, this message translates to:
  /// **'Community Activity'**
  String get communityActivity;

  /// No description provided for @peopleJoinedEvents.
  ///
  /// In en, this message translates to:
  /// **'{count} people have joined events'**
  String peopleJoinedEvents(int count);

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended For You'**
  String get recommendedForYou;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @yourKhairLevel.
  ///
  /// In en, this message translates to:
  /// **'Your Khair Level: '**
  String get yourKhairLevel;

  /// No description provided for @moreEventsToGold.
  ///
  /// In en, this message translates to:
  /// **'{count} more events to unlock Gold'**
  String moreEventsToGold(int count);

  /// No description provided for @viewProgress.
  ///
  /// In en, this message translates to:
  /// **'View Progress'**
  String get viewProgress;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @catTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get catTrending;

  /// No description provided for @catNearYou.
  ///
  /// In en, this message translates to:
  /// **'Near You'**
  String get catNearYou;

  /// No description provided for @catGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get catGlobal;

  /// No description provided for @catMasjid.
  ///
  /// In en, this message translates to:
  /// **'Masjid'**
  String get catMasjid;

  /// No description provided for @becomeOrganizerTitle.
  ///
  /// In en, this message translates to:
  /// **'Become an Organizer'**
  String get becomeOrganizerTitle;

  /// No description provided for @becomeOrganizerDesc.
  ///
  /// In en, this message translates to:
  /// **'Only organizers can access the dashboard.\n\nRegister as an organizer to start creating and managing Islamic events!'**
  String get becomeOrganizerDesc;

  /// No description provided for @mapPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick Location on Map'**
  String get mapPickerTitle;

  /// No description provided for @mapPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a place or address...'**
  String get mapPickerSearchHint;

  /// No description provided for @mapPickerUseCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get mapPickerUseCurrentLocation;

  /// No description provided for @mapPickerTapToSelect.
  ///
  /// In en, this message translates to:
  /// **'Tap on the map to drop a pin'**
  String get mapPickerTapToSelect;

  /// No description provided for @mapPickerSelectedLocation.
  ///
  /// In en, this message translates to:
  /// **'Selected Location'**
  String get mapPickerSelectedLocation;

  /// No description provided for @mapPickerSearching.
  ///
  /// In en, this message translates to:
  /// **'Resolving address...'**
  String get mapPickerSearching;

  /// No description provided for @mapPickerRefineAddress.
  ///
  /// In en, this message translates to:
  /// **'Fine-tune the address details below if needed'**
  String get mapPickerRefineAddress;

  /// No description provided for @eventDetailsGetDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get eventDetailsGetDirections;

  /// No description provided for @eventDetailsOpenInMaps.
  ///
  /// In en, this message translates to:
  /// **'Open in Maps'**
  String get eventDetailsOpenInMaps;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get displayName;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @fullAddress.
  ///
  /// In en, this message translates to:
  /// **'Full Address'**
  String get fullAddress;

  /// No description provided for @preferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred Language'**
  String get preferredLanguage;

  /// No description provided for @tapToChangePhoto.
  ///
  /// In en, this message translates to:
  /// **'Tap to change photo'**
  String get tapToChangePhoto;

  /// No description provided for @checkingImage.
  ///
  /// In en, this message translates to:
  /// **'Checking image...'**
  String get checkingImage;

  /// No description provided for @aiVerifyingPhoto.
  ///
  /// In en, this message translates to:
  /// **'AI is verifying your photo'**
  String get aiVerifyingPhoto;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @tellUsAboutYourself.
  ///
  /// In en, this message translates to:
  /// **'Tell us about yourself...'**
  String get tellUsAboutYourself;

  /// No description provided for @yourLocationOrAddress.
  ///
  /// In en, this message translates to:
  /// **'Your location or address'**
  String get yourLocationOrAddress;

  /// No description provided for @profileUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdatedSuccess;

  /// No description provided for @failedSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile'**
  String get failedSaveProfile;

  /// No description provided for @failedLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile'**
  String get failedLoadProfile;

  /// No description provided for @contentNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'Content Not Allowed'**
  String get contentNotAllowed;

  /// No description provided for @understood.
  ///
  /// In en, this message translates to:
  /// **'Understood'**
  String get understood;

  /// No description provided for @imageApproved.
  ///
  /// In en, this message translates to:
  /// **'Image approved ✓'**
  String get imageApproved;

  /// No description provided for @failedProcessImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to process image'**
  String get failedProcessImage;

  /// No description provided for @imageMustBeUnder5MB.
  ///
  /// In en, this message translates to:
  /// **'Image must be under 5 MB'**
  String get imageMustBeUnder5MB;

  /// No description provided for @aiModerationNotice.
  ///
  /// In en, this message translates to:
  /// **'Your content is reviewed by AI to keep the Khair community safe and respectful.'**
  String get aiModerationNotice;

  /// No description provided for @mapSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search city or event'**
  String get mapSearchHint;

  /// No description provided for @mapFindKhairNearYou.
  ///
  /// In en, this message translates to:
  /// **'Find Khair near you'**
  String get mapFindKhairNearYou;

  /// No description provided for @mapSearchThisArea.
  ///
  /// In en, this message translates to:
  /// **'Search this area'**
  String get mapSearchThisArea;

  /// No description provided for @mapSearchingPlaces.
  ///
  /// In en, this message translates to:
  /// **'Searching places…'**
  String get mapSearchingPlaces;

  /// No description provided for @mapPlacesFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Places found above. Select one to center the map.'**
  String get mapPlacesFoundHint;

  /// No description provided for @mapEventsNearby.
  ///
  /// In en, this message translates to:
  /// **'{count} events nearby'**
  String mapEventsNearby(int count);

  /// No description provided for @mapClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get mapClearFilters;

  /// No description provided for @mapNoEventsFound.
  ///
  /// In en, this message translates to:
  /// **'No events found here yet'**
  String get mapNoEventsFound;

  /// No description provided for @mapBeFirstToCreate.
  ///
  /// In en, this message translates to:
  /// **'Be the first to create one!'**
  String get mapBeFirstToCreate;

  /// No description provided for @mapCreateEvent.
  ///
  /// In en, this message translates to:
  /// **'Create Event'**
  String get mapCreateEvent;

  /// No description provided for @mapApplyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get mapApplyFilters;

  /// No description provided for @mapFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get mapFilters;

  /// No description provided for @mapFilterDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get mapFilterDistance;

  /// No description provided for @mapFilterType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get mapFilterType;

  /// No description provided for @mapFilterCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get mapFilterCategory;

  /// No description provided for @anyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get anyDate;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @mapFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get mapFilterAll;

  /// No description provided for @mapFilterInPerson.
  ///
  /// In en, this message translates to:
  /// **'In-person'**
  String get mapFilterInPerson;

  /// No description provided for @mapFilterOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get mapFilterOnline;

  /// No description provided for @mapFilterQuran.
  ///
  /// In en, this message translates to:
  /// **'Quran'**
  String get mapFilterQuran;

  /// No description provided for @mapFilterLecture.
  ///
  /// In en, this message translates to:
  /// **'Lecture'**
  String get mapFilterLecture;

  /// No description provided for @mapFilterCharity.
  ///
  /// In en, this message translates to:
  /// **'Charity'**
  String get mapFilterCharity;

  /// No description provided for @mapFilterHalaqa.
  ///
  /// In en, this message translates to:
  /// **'Halaqa'**
  String get mapFilterHalaqa;

  /// No description provided for @mapFilterFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get mapFilterFamily;

  /// No description provided for @mapJoin.
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get mapJoin;

  /// No description provided for @sheikhLearnFromScholars.
  ///
  /// In en, this message translates to:
  /// **'Learn from Scholars'**
  String get sheikhLearnFromScholars;

  /// No description provided for @sheikhViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get sheikhViewProfile;

  /// No description provided for @sheikhNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get sheikhNew;

  /// No description provided for @allEvents.
  ///
  /// In en, this message translates to:
  /// **'All Events'**
  String get allEvents;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @khairRecommends.
  ///
  /// In en, this message translates to:
  /// **'Khair Recommends'**
  String get khairRecommends;

  /// No description provided for @verifiedByKhair.
  ///
  /// In en, this message translates to:
  /// **'Verified by Khair'**
  String get verifiedByKhair;

  /// No description provided for @visit.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visit;

  /// No description provided for @seeAllEvents.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAllEvents;

  /// No description provided for @discoverNoEventsNearYou.
  ///
  /// In en, this message translates to:
  /// **'No events found near you'**
  String get discoverNoEventsNearYou;

  /// No description provided for @discoverExploreOtherCities.
  ///
  /// In en, this message translates to:
  /// **'Explore events happening in other cities.'**
  String get discoverExploreOtherCities;

  /// No description provided for @discoverExploreAllEvents.
  ///
  /// In en, this message translates to:
  /// **'Explore All Events'**
  String get discoverExploreAllEvents;

  /// No description provided for @discoverSomethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get discoverSomethingWentWrong;

  /// No description provided for @discoverCouldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load events.'**
  String get discoverCouldNotLoad;

  /// No description provided for @discoverEventsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} events'**
  String discoverEventsCount(int count);

  /// No description provided for @sheikhLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get sheikhLocation;

  /// No description provided for @sheikhExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get sheikhExperience;

  /// No description provided for @sheikhYearsExperience.
  ///
  /// In en, this message translates to:
  /// **'{count} years'**
  String sheikhYearsExperience(int count);

  /// No description provided for @sheikhStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get sheikhStatus;

  /// No description provided for @sheikhVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get sheikhVerified;

  /// No description provided for @sheikhPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get sheikhPending;

  /// No description provided for @sheikhRequestLesson.
  ///
  /// In en, this message translates to:
  /// **'Request a Lesson'**
  String get sheikhRequestLesson;

  /// No description provided for @sheikhContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get sheikhContact;

  /// No description provided for @sheikhContactInfo.
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get sheikhContactInfo;

  /// No description provided for @sheikhAboutMe.
  ///
  /// In en, this message translates to:
  /// **'About me'**
  String get sheikhAboutMe;

  /// No description provided for @sheikhQualifications.
  ///
  /// In en, this message translates to:
  /// **'Qualifications'**
  String get sheikhQualifications;

  /// No description provided for @sheikhStudentReviews.
  ///
  /// In en, this message translates to:
  /// **'Student Reviews'**
  String get sheikhStudentReviews;

  /// No description provided for @sheikhIjazahCredentials.
  ///
  /// In en, this message translates to:
  /// **'Ijazah & Credentials'**
  String get sheikhIjazahCredentials;

  /// No description provided for @sheikhReportProfile.
  ///
  /// In en, this message translates to:
  /// **'Report this profile'**
  String get sheikhReportProfile;

  /// No description provided for @sheikhReportTitle.
  ///
  /// In en, this message translates to:
  /// **'🚨 Report Sheikh'**
  String get sheikhReportTitle;

  /// No description provided for @sheikhReportDesc.
  ///
  /// In en, this message translates to:
  /// **'Please describe the issue. Reports are reviewed by our team.'**
  String get sheikhReportDesc;

  /// No description provided for @sheikhReportHint.
  ///
  /// In en, this message translates to:
  /// **'Describe the issue...'**
  String get sheikhReportHint;

  /// No description provided for @sheikhSubmitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get sheikhSubmitReport;

  /// No description provided for @sheikhReportSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Report submitted. Thank you.'**
  String get sheikhReportSubmitted;

  /// No description provided for @sheikhSendLessonRequest.
  ///
  /// In en, this message translates to:
  /// **'Send a lesson request to {name}'**
  String sheikhSendLessonRequest(String name);

  /// No description provided for @sheikhWhatToLearn.
  ///
  /// In en, this message translates to:
  /// **'What would you like to learn?'**
  String get sheikhWhatToLearn;

  /// No description provided for @sheikhWhatToLearnHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. I want to learn Tafsir...'**
  String get sheikhWhatToLearnHint;

  /// No description provided for @sheikhPreferredTime.
  ///
  /// In en, this message translates to:
  /// **'Preferred time (optional)'**
  String get sheikhPreferredTime;

  /// No description provided for @sheikhDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Sheikh'**
  String get sheikhDefaultName;

  /// No description provided for @sheikhDefaultSpecialization.
  ///
  /// In en, this message translates to:
  /// **'Islamic Studies'**
  String get sheikhDefaultSpecialization;

  /// No description provided for @sheikhRequestMessageRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a message'**
  String get sheikhRequestMessageRequired;

  /// No description provided for @sheikhRequestFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send request'**
  String get sheikhRequestFailed;

  /// No description provided for @sheikhSelectDateTime.
  ///
  /// In en, this message translates to:
  /// **'Select date & time'**
  String get sheikhSelectDateTime;

  /// No description provided for @sheikhSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send Request'**
  String get sheikhSendRequest;

  /// No description provided for @sheikhRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Lesson request sent! The sheikh will review it.'**
  String get sheikhRequestSent;

  /// No description provided for @sheikhNewScholar.
  ///
  /// In en, this message translates to:
  /// **'New scholar'**
  String get sheikhNewScholar;

  /// No description provided for @sheikhBuildingReputation.
  ///
  /// In en, this message translates to:
  /// **'Building reputation'**
  String get sheikhBuildingReputation;

  /// No description provided for @sheikhReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String sheikhReviewsCount(int count);

  /// No description provided for @sheikhNoReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get sheikhNoReviewsYet;

  /// No description provided for @sheikhWriteReview.
  ///
  /// In en, this message translates to:
  /// **'Write a Review'**
  String get sheikhWriteReview;

  /// No description provided for @sheikhYourReview.
  ///
  /// In en, this message translates to:
  /// **'Your Review'**
  String get sheikhYourReview;

  /// No description provided for @sheikhShareExperience.
  ///
  /// In en, this message translates to:
  /// **'Share your experience...'**
  String get sheikhShareExperience;

  /// No description provided for @sheikhSubmitReview.
  ///
  /// In en, this message translates to:
  /// **'Submit Review'**
  String get sheikhSubmitReview;

  /// No description provided for @sheikhReviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted! It will appear after moderation.'**
  String get sheikhReviewSubmitted;

  /// No description provided for @sheikhReportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to submit report'**
  String get sheikhReportFailed;

  /// No description provided for @sheikhProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Scholar Not Found'**
  String get sheikhProfileNotFound;

  /// No description provided for @sheikhProfileUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'This profile may have been removed or the link is incorrect.'**
  String get sheikhProfileUnavailableMessage;

  /// No description provided for @sheikhAllCities.
  ///
  /// In en, this message translates to:
  /// **'All Cities'**
  String get sheikhAllCities;

  /// No description provided for @allCities.
  ///
  /// In en, this message translates to:
  /// **'All Cities'**
  String get allCities;

  /// No description provided for @mapNoEventsFoundHere.
  ///
  /// In en, this message translates to:
  /// **'No events found here yet'**
  String get mapNoEventsFoundHere;

  /// No description provided for @guestHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover meaningful\nevents near you'**
  String get guestHeroTitle;

  /// No description provided for @guestHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join classes, lectures, and community gatherings around you'**
  String get guestHeroSubtitle;

  /// No description provided for @guestBenefitEvents.
  ///
  /// In en, this message translates to:
  /// **'Find events near you'**
  String get guestBenefitEvents;

  /// No description provided for @guestBenefitTeachers.
  ///
  /// In en, this message translates to:
  /// **'Learn from verified teachers'**
  String get guestBenefitTeachers;

  /// No description provided for @guestBenefitCommunity.
  ///
  /// In en, this message translates to:
  /// **'Connect with your community'**
  String get guestBenefitCommunity;

  /// No description provided for @guestGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get guestGetStarted;

  /// No description provided for @guestAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get guestAlreadyHaveAccount;

  /// No description provided for @guestSignUpToExplore.
  ///
  /// In en, this message translates to:
  /// **'Sign up to explore events near you'**
  String get guestSignUpToExplore;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent. All your data, events, and activity will be deleted. This cannot be undone.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountSuccess.
  ///
  /// In en, this message translates to:
  /// **'Your account has been deleted.'**
  String get deleteAccountSuccess;

  /// No description provided for @deleteAccountError.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account. Please try again.'**
  String get deleteAccountError;

  /// No description provided for @createEventSelectCurrency.
  ///
  /// In en, this message translates to:
  /// **'Select Currency'**
  String get createEventSelectCurrency;

  /// No description provided for @eventDetailsPaymentInfo.
  ///
  /// In en, this message translates to:
  /// **'Payment Information'**
  String get eventDetailsPaymentInfo;

  /// No description provided for @eventDetailsTicketPrice.
  ///
  /// In en, this message translates to:
  /// **'TICKET PRICE'**
  String get eventDetailsTicketPrice;

  /// No description provided for @eventDetailsPayAtLocation.
  ///
  /// In en, this message translates to:
  /// **'Payment is collected at the event location in cash. Please bring the exact amount.'**
  String get eventDetailsPayAtLocation;

  /// No description provided for @eventDetailsFree.
  ///
  /// In en, this message translates to:
  /// **'Free Event'**
  String get eventDetailsFree;

  /// No description provided for @myLearning.
  ///
  /// In en, this message translates to:
  /// **'My Learning'**
  String get myLearning;

  /// No description provided for @myLearningGreeting.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum'**
  String get myLearningGreeting;

  /// No description provided for @myLearningSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your learning journey at a glance'**
  String get myLearningSubtitle;

  /// No description provided for @lessonsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get lessonsCompleted;

  /// No description provided for @upcomingCount.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingCount;

  /// No description provided for @pendingCount.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pendingCount;

  /// No description provided for @upcomingTab.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingTab;

  /// No description provided for @requestsTab.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get requestsTab;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @sheikhsTab.
  ///
  /// In en, this message translates to:
  /// **'Sheikhs'**
  String get sheikhsTab;

  /// No description provided for @joinLesson.
  ///
  /// In en, this message translates to:
  /// **'Join Lesson'**
  String get joinLesson;

  /// No description provided for @cancelLesson.
  ///
  /// In en, this message translates to:
  /// **'Cancel Lesson'**
  String get cancelLesson;

  /// No description provided for @cancelLessonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this lesson?'**
  String get cancelLessonConfirm;

  /// No description provided for @rateSheikh.
  ///
  /// In en, this message translates to:
  /// **'Rate Sheikh'**
  String get rateSheikh;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write your review...'**
  String get writeReview;

  /// No description provided for @bookAgain.
  ///
  /// In en, this message translates to:
  /// **'Book Again'**
  String get bookAgain;

  /// No description provided for @sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get sendMessage;

  /// No description provided for @lessonsLabel.
  ///
  /// In en, this message translates to:
  /// **'lessons'**
  String get lessonsLabel;

  /// No description provided for @noUpcomingLessons.
  ///
  /// In en, this message translates to:
  /// **'No upcoming lessons'**
  String get noUpcomingLessons;

  /// No description provided for @noRequests.
  ///
  /// In en, this message translates to:
  /// **'No lesson requests yet'**
  String get noRequests;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No past lessons yet'**
  String get noHistory;

  /// No description provided for @noSheikhs.
  ///
  /// In en, this message translates to:
  /// **'No sheikhs yet'**
  String get noSheikhs;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get statusAccepted;

  /// No description provided for @statusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get statusScheduled;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @shareEventIntro.
  ///
  /// In en, this message translates to:
  /// **'Join me at {eventTitle} on Khair 👋'**
  String shareEventIntro(String eventTitle);

  /// No description provided for @shareEventOnlineLocation.
  ///
  /// In en, this message translates to:
  /// **'💻 Online'**
  String get shareEventOnlineLocation;

  /// No description provided for @shareEventPhysicalLocation.
  ///
  /// In en, this message translates to:
  /// **'📍 {location}'**
  String shareEventPhysicalLocation(String location);

  /// No description provided for @shareEventOrganizer.
  ///
  /// In en, this message translates to:
  /// **'🎤 Hosted by {name}'**
  String shareEventOrganizer(String name);

  /// No description provided for @chooseYourArea.
  ///
  /// In en, this message translates to:
  /// **'Choose your area'**
  String get chooseYourArea;

  /// No description provided for @discoverEventsNearYou.
  ///
  /// In en, this message translates to:
  /// **'Discover events near you.'**
  String get discoverEventsNearYou;

  /// No description provided for @useYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Use your location or search a city.'**
  String get useYourLocation;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use current location. Khair only asks when you choose this.'**
  String get useCurrentLocation;

  /// No description provided for @showEvents.
  ///
  /// In en, this message translates to:
  /// **'Show events'**
  String get showEvents;

  /// No description provided for @findSomethingToDo.
  ///
  /// In en, this message translates to:
  /// **'Find something to do'**
  String get findSomethingToDo;

  /// No description provided for @searchEventsOrCities.
  ///
  /// In en, this message translates to:
  /// **'Search events, topics, or cities'**
  String get searchEventsOrCities;

  /// No description provided for @howCanWeHelpYou.
  ///
  /// In en, this message translates to:
  /// **'How can we help you?'**
  String get howCanWeHelpYou;

  /// No description provided for @askKhairAi.
  ///
  /// In en, this message translates to:
  /// **'Ask Khair AI or connect with our support team.'**
  String get askKhairAi;

  /// No description provided for @supportCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get supportCategory;

  /// No description provided for @supportCategoryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Payment, Account, General'**
  String get supportCategoryHint;

  /// No description provided for @howCanWeHelp.
  ///
  /// In en, this message translates to:
  /// **'How can we help?'**
  String get howCanWeHelp;

  /// No description provided for @startChat.
  ///
  /// In en, this message translates to:
  /// **'Start Chat'**
  String get startChat;

  /// No description provided for @talkToHuman.
  ///
  /// In en, this message translates to:
  /// **'Talk to Human'**
  String get talkToHuman;

  /// No description provided for @resolveTicket.
  ///
  /// In en, this message translates to:
  /// **'Resolve'**
  String get resolveTicket;

  /// No description provided for @waitingForSupportAgent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an available support agent...'**
  String get waitingForSupportAgent;

  /// No description provided for @greetingGoodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingGoodMorning;

  /// No description provided for @greetingGoodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get greetingGoodAfternoon;

  /// No description provided for @greetingGoodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingGoodEvening;

  /// No description provided for @discoverHeadlinePre.
  ///
  /// In en, this message translates to:
  /// **'Find events that'**
  String get discoverHeadlinePre;

  /// No description provided for @discoverHeadlineHighlight.
  ///
  /// In en, this message translates to:
  /// **'inspire'**
  String get discoverHeadlineHighlight;

  /// No description provided for @discoverHeadlinePost.
  ///
  /// In en, this message translates to:
  /// **' you'**
  String get discoverHeadlinePost;

  /// No description provided for @resultsForQuery.
  ///
  /// In en, this message translates to:
  /// **'Results for \"{query}\"'**
  String resultsForQuery(String query);

  /// No description provided for @matchingEvents.
  ///
  /// In en, this message translates to:
  /// **'Matching events'**
  String get matchingEvents;

  /// No description provided for @exploreMap.
  ///
  /// In en, this message translates to:
  /// **'Explore map'**
  String get exploreMap;

  /// No description provided for @featuredNearYou.
  ///
  /// In en, this message translates to:
  /// **'Featured near you'**
  String get featuredNearYou;

  /// No description provided for @eventsWorthTimeFor.
  ///
  /// In en, this message translates to:
  /// **'Events worth making time for'**
  String get eventsWorthTimeFor;

  /// No description provided for @happeningThisWeekend.
  ///
  /// In en, this message translates to:
  /// **'Happening this weekend'**
  String get happeningThisWeekend;

  /// No description provided for @planSomethingMeaningful.
  ///
  /// In en, this message translates to:
  /// **'Plan something meaningful'**
  String get planSomethingMeaningful;

  /// No description provided for @thisWeekend.
  ///
  /// In en, this message translates to:
  /// **'This weekend'**
  String get thisWeekend;

  /// No description provided for @nearMe.
  ///
  /// In en, this message translates to:
  /// **'Near me'**
  String get nearMe;

  /// No description provided for @freeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeLabel;

  /// No description provided for @chooseArea.
  ///
  /// In en, this message translates to:
  /// **'Choose area'**
  String get chooseArea;

  /// No description provided for @locationUpdateError.
  ///
  /// In en, this message translates to:
  /// **'We could not update your location.'**
  String get locationUpdateError;

  /// No description provided for @filtersComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Filters coming soon'**
  String get filtersComingSoon;

  /// No description provided for @adjustFiltersHint.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your filters or area.'**
  String get adjustFiltersHint;

  /// No description provided for @loadEventsError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load events right now.'**
  String get loadEventsError;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @savedEventsUpdateError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t update your saved events.'**
  String get savedEventsUpdateError;

  /// No description provided for @discoverFreeEvents.
  ///
  /// In en, this message translates to:
  /// **'Discover free events'**
  String get discoverFreeEvents;

  /// No description provided for @freePromoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore gatherings that don\'t cost a thing'**
  String get freePromoSubtitle;

  /// No description provided for @useCurrentLocationShort.
  ///
  /// In en, this message translates to:
  /// **'Use current location'**
  String get useCurrentLocationShort;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @profileTooltip.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTooltip;

  /// No description provided for @termsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Terms & Privacy'**
  String get termsPrivacy;

  /// No description provided for @pleaseReviewAndAcceptOurTermsT.
  ///
  /// In en, this message translates to:
  /// **'Please review and accept our terms to continue.'**
  String get pleaseReviewAndAcceptOurTermsT;

  /// No description provided for @iAcceptThe.
  ///
  /// In en, this message translates to:
  /// **'I accept the '**
  String get iAcceptThe;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// No description provided for @acceptContinue.
  ///
  /// In en, this message translates to:
  /// **'Accept & Continue'**
  String get acceptContinue;

  /// No description provided for @organizerAgreement.
  ///
  /// In en, this message translates to:
  /// **'Organizer Agreement'**
  String get organizerAgreement;

  /// No description provided for @asAnEventOrganizerYouMustAgree.
  ///
  /// In en, this message translates to:
  /// **'As an event organizer, you must agree to additional terms.'**
  String get asAnEventOrganizerYouMustAgree;

  /// No description provided for @iAgreeToTheOrganizerAgreement.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Organizer Agreement'**
  String get iAgreeToTheOrganizerAgreement;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @discoverEvents.
  ///
  /// In en, this message translates to:
  /// **'Discover events'**
  String get discoverEvents;

  /// No description provided for @weCouldn.
  ///
  /// In en, this message translates to:
  /// **'We couldn\\'**
  String get weCouldn;

  /// No description provided for @linkCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard!'**
  String get linkCopiedToClipboard;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get discardChanges;

  /// No description provided for @yourUnsavedEditsWillBeLost.
  ///
  /// In en, this message translates to:
  /// **'Your unsaved edits will be lost.'**
  String get yourUnsavedEditsWillBeLost;

  /// No description provided for @keepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get keepEditing;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @noEventsFound1.
  ///
  /// In en, this message translates to:
  /// **'No Events Found'**
  String get noEventsFound1;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No Results'**
  String get noResults;

  /// No description provided for @noReports.
  ///
  /// In en, this message translates to:
  /// **'No Reports'**
  String get noReports;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No Notifications'**
  String get noNotifications;

  /// No description provided for @noOrganizers.
  ///
  /// In en, this message translates to:
  /// **'No Organizers'**
  String get noOrganizers;

  /// No description provided for @noAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'No Audit Logs'**
  String get noAuditLogs;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location Unavailable'**
  String get locationUnavailable;

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection Error'**
  String get connectionError;

  /// No description provided for @tryAgain1.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgain1;

  /// No description provided for @myEvents.
  ///
  /// In en, this message translates to:
  /// **'My events'**
  String get myEvents;

  /// No description provided for @signIn1.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn1;

  /// No description provided for @signInOrRegisterToCreateAnEven.
  ///
  /// In en, this message translates to:
  /// **'Sign in or register to create an event.'**
  String get signInOrRegisterToCreateAnEven;

  /// No description provided for @createEvent1.
  ///
  /// In en, this message translates to:
  /// **'Create event'**
  String get createEvent1;

  /// No description provided for @organizerApplicationReviewQueu.
  ///
  /// In en, this message translates to:
  /// **'Organizer application review queue'**
  String get organizerApplicationReviewQueu;

  /// No description provided for @supportInbox.
  ///
  /// In en, this message translates to:
  /// **'Support Inbox'**
  String get supportInbox;

  /// No description provided for @supportInboxLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load the support inbox.'**
  String get supportInboxLoadFailed;

  /// No description provided for @supportInboxEmpty.
  ///
  /// In en, this message translates to:
  /// **'No support conversations are waiting.'**
  String get supportInboxEmpty;

  /// No description provided for @verification.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get verification;

  /// No description provided for @areYouSureYouWantToReject.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject '**
  String get areYouSureYouWantToReject;

  /// No description provided for @noUsers.
  ///
  /// In en, this message translates to:
  /// **'No Users'**
  String get noUsers;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found.'**
  String get noUsersFound;

  /// No description provided for @verified.
  ///
  /// In en, this message translates to:
  /// **'VERIFIED'**
  String get verified;

  /// No description provided for @verifyUser.
  ///
  /// In en, this message translates to:
  /// **'Verify User'**
  String get verifyUser;

  /// No description provided for @promoteToOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Promote to Organizer'**
  String get promoteToOrganizer;

  /// No description provided for @promoteToAdmin.
  ///
  /// In en, this message translates to:
  /// **'Promote to Admin'**
  String get promoteToAdmin;

  /// No description provided for @suspend.
  ///
  /// In en, this message translates to:
  /// **'Suspend'**
  String get suspend;

  /// No description provided for @ban.
  ///
  /// In en, this message translates to:
  /// **'Ban'**
  String get ban;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @reasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get reasonOptional;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @deleteQuote.
  ///
  /// In en, this message translates to:
  /// **'Delete Quote'**
  String get deleteQuote;

  /// No description provided for @areYouSureYouWantToDeleteThisQ.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this quote?'**
  String get areYouSureYouWantToDeleteThisQ;

  /// No description provided for @quoteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Quote deleted'**
  String get quoteDeleted;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete'**
  String get failedToDelete;

  /// No description provided for @arabicText.
  ///
  /// In en, this message translates to:
  /// **'Arabic Text'**
  String get arabicText;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @reference.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get reference;

  /// No description provided for @showOnHome.
  ///
  /// In en, this message translates to:
  /// **'Show on Home'**
  String get showOnHome;

  /// No description provided for @showOnDashboard.
  ///
  /// In en, this message translates to:
  /// **'Show on Dashboard'**
  String get showOnDashboard;

  /// No description provided for @showOnLogin.
  ///
  /// In en, this message translates to:
  /// **'Show on Login'**
  String get showOnLogin;

  /// No description provided for @failedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save'**
  String get failedToSave;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @noQuotesYet.
  ///
  /// In en, this message translates to:
  /// **'No quotes yet'**
  String get noQuotesYet;

  /// No description provided for @titleAndMessageAreRequired.
  ///
  /// In en, this message translates to:
  /// **'Title and message are required'**
  String get titleAndMessageAreRequired;

  /// No description provided for @pleaseSelectAUser.
  ///
  /// In en, this message translates to:
  /// **'Please select a user'**
  String get pleaseSelectAUser;

  /// No description provided for @sendNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Notification'**
  String get sendNotification;

  /// No description provided for @sendPushNotificationsToYourUse.
  ///
  /// In en, this message translates to:
  /// **'Send push notifications to your users'**
  String get sendPushNotificationsToYourUse;

  /// No description provided for @allUsers.
  ///
  /// In en, this message translates to:
  /// **'All Users'**
  String get allUsers;

  /// No description provided for @individual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get individual;

  /// No description provided for @searchUserByNameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search user by name or email...'**
  String get searchUserByNameOrEmail;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification title...'**
  String get notificationTitle;

  /// No description provided for @writeYourNotificationMessage.
  ///
  /// In en, this message translates to:
  /// **'Write your notification message...'**
  String get writeYourNotificationMessage;

  /// No description provided for @noPendingVerificationRequests.
  ///
  /// In en, this message translates to:
  /// **'No Pending Verification Requests'**
  String get noPendingVerificationRequests;

  /// No description provided for @allVerificationRequestsHaveBee.
  ///
  /// In en, this message translates to:
  /// **'All verification requests have been reviewed'**
  String get allVerificationRequestsHaveBee;

  /// No description provided for @userNotes.
  ///
  /// In en, this message translates to:
  /// **'User Notes:'**
  String get userNotes;

  /// No description provided for @viewCertificate.
  ///
  /// In en, this message translates to:
  /// **'View Certificate'**
  String get viewCertificate;

  /// No description provided for @viewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View Photo'**
  String get viewPhoto;

  /// No description provided for @changes.
  ///
  /// In en, this message translates to:
  /// **'Changes'**
  String get changes;

  /// No description provided for @adminReviewNotes.
  ///
  /// In en, this message translates to:
  /// **'Admin Review Notes:'**
  String get adminReviewNotes;

  /// No description provided for @failedToLoadImage.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get failedToLoadImage;

  /// No description provided for @pleaseProvideAReason.
  ///
  /// In en, this message translates to:
  /// **'Please provide a reason'**
  String get pleaseProvideAReason;

  /// No description provided for @reviewEvent.
  ///
  /// In en, this message translates to:
  /// **'Review Event'**
  String get reviewEvent;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @capacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get capacity;

  /// No description provided for @ticketAssigned.
  ///
  /// In en, this message translates to:
  /// **'Ticket assigned'**
  String get ticketAssigned;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @waitingForSupport.
  ///
  /// In en, this message translates to:
  /// **'Waiting for Support'**
  String get waitingForSupport;

  /// No description provided for @inProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get inProgress;

  /// No description provided for @resolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get resolved;

  /// No description provided for @assignToMe.
  ///
  /// In en, this message translates to:
  /// **'Assign to me'**
  String get assignToMe;

  /// No description provided for @typeReply.
  ///
  /// In en, this message translates to:
  /// **'Type reply...'**
  String get typeReply;

  /// No description provided for @replyToUser.
  ///
  /// In en, this message translates to:
  /// **'Reply to User'**
  String get replyToUser;

  /// No description provided for @internalNote.
  ///
  /// In en, this message translates to:
  /// **'Internal Note'**
  String get internalNote;

  /// No description provided for @noAuditLogsFound.
  ///
  /// In en, this message translates to:
  /// **'No audit logs found'**
  String get noAuditLogsFound;

  /// No description provided for @filterLogs.
  ///
  /// In en, this message translates to:
  /// **'Filter Logs'**
  String get filterLogs;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @organizerApplications.
  ///
  /// In en, this message translates to:
  /// **'Organizer applications'**
  String get organizerApplications;

  /// No description provided for @refreshQueue.
  ///
  /// In en, this message translates to:
  /// **'Refresh queue'**
  String get refreshQueue;

  /// No description provided for @needsChanges.
  ///
  /// In en, this message translates to:
  /// **'Needs changes'**
  String get needsChanges;

  /// No description provided for @noApplicationsInThisQueue.
  ///
  /// In en, this message translates to:
  /// **'No applications in this queue'**
  String get noApplicationsInThisQueue;

  /// No description provided for @newSubmissionsWillAppearHere.
  ///
  /// In en, this message translates to:
  /// **'New submissions will appear here.'**
  String get newSubmissionsWillAppearHere;

  /// No description provided for @theOrganizerQueueCouldNotBeLoa.
  ///
  /// In en, this message translates to:
  /// **'The organizer queue could not be loaded.'**
  String get theOrganizerQueueCouldNotBeLoa;

  /// No description provided for @organizerApplication.
  ///
  /// In en, this message translates to:
  /// **'Organizer application'**
  String get organizerApplication;

  /// No description provided for @refreshDossier.
  ///
  /// In en, this message translates to:
  /// **'Refresh dossier'**
  String get refreshDossier;

  /// No description provided for @organizationDescription.
  ///
  /// In en, this message translates to:
  /// **'Organization description'**
  String get organizationDescription;

  /// No description provided for @eventPlan.
  ///
  /// In en, this message translates to:
  /// **'Event plan'**
  String get eventPlan;

  /// No description provided for @applicantMessage.
  ///
  /// In en, this message translates to:
  /// **'Applicant message'**
  String get applicantMessage;

  /// No description provided for @internalReviewNote.
  ///
  /// In en, this message translates to:
  /// **'Internal review note'**
  String get internalReviewNote;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// No description provided for @viewPublicImage.
  ///
  /// In en, this message translates to:
  /// **'View public image'**
  String get viewPublicImage;

  /// No description provided for @viewRepresentativePhoto.
  ///
  /// In en, this message translates to:
  /// **'View representative photo'**
  String get viewRepresentativePhoto;

  /// No description provided for @officialPublicLinks.
  ///
  /// In en, this message translates to:
  /// **'Official public links'**
  String get officialPublicLinks;

  /// No description provided for @noOfficialLinksProvided.
  ///
  /// In en, this message translates to:
  /// **'No official links provided'**
  String get noOfficialLinksProvided;

  /// No description provided for @evidenceEntries.
  ///
  /// In en, this message translates to:
  /// **'Evidence entries'**
  String get evidenceEntries;

  /// No description provided for @noAdditionalEvidenceProvided.
  ///
  /// In en, this message translates to:
  /// **'No additional evidence provided'**
  String get noAdditionalEvidenceProvided;

  /// No description provided for @privateVerificationDocuments.
  ///
  /// In en, this message translates to:
  /// **'Private verification documents'**
  String get privateVerificationDocuments;

  /// No description provided for @noPrivateDocumentsUploaded.
  ///
  /// In en, this message translates to:
  /// **'No private documents uploaded'**
  String get noPrivateDocumentsUploaded;

  /// No description provided for @view.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// No description provided for @requestChanges.
  ///
  /// In en, this message translates to:
  /// **'Request changes'**
  String get requestChanges;

  /// No description provided for @approveOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Approve organizer'**
  String get approveOrganizer;

  /// No description provided for @reasonCode.
  ///
  /// In en, this message translates to:
  /// **'Reason code'**
  String get reasonCode;

  /// No description provided for @egIdentityunverified.
  ///
  /// In en, this message translates to:
  /// **'e.g. identity_unverified'**
  String get egIdentityunverified;

  /// No description provided for @internalNoteNotShownToApplican.
  ///
  /// In en, this message translates to:
  /// **'Internal note (not shown to applicant)'**
  String get internalNoteNotShownToApplican;

  /// No description provided for @theSecureImageCouldNotBeDispla.
  ///
  /// In en, this message translates to:
  /// **'The secure image could not be displayed.'**
  String get theSecureImageCouldNotBeDispla;

  /// No description provided for @organizerTrustProfile.
  ///
  /// In en, this message translates to:
  /// **'Organizer Trust Profile'**
  String get organizerTrustProfile;

  /// No description provided for @trustActions.
  ///
  /// In en, this message translates to:
  /// **'Trust Actions'**
  String get trustActions;

  /// No description provided for @trustScore.
  ///
  /// In en, this message translates to:
  /// **'Trust Score'**
  String get trustScore;

  /// No description provided for @reasonRequired.
  ///
  /// In en, this message translates to:
  /// **'Reason (required)'**
  String get reasonRequired;

  /// No description provided for @reportDismissed.
  ///
  /// In en, this message translates to:
  /// **'Report dismissed'**
  String get reportDismissed;

  /// No description provided for @resolveReport.
  ///
  /// In en, this message translates to:
  /// **'Resolve Report'**
  String get resolveReport;

  /// No description provided for @approveNoAction.
  ///
  /// In en, this message translates to:
  /// **'Approve (No Action)'**
  String get approveNoAction;

  /// No description provided for @issueWarning.
  ///
  /// In en, this message translates to:
  /// **'Issue Warning'**
  String get issueWarning;

  /// No description provided for @removeContent.
  ///
  /// In en, this message translates to:
  /// **'Remove Content'**
  String get removeContent;

  /// No description provided for @recommendedForYou1.
  ///
  /// In en, this message translates to:
  /// **'Recommended for You'**
  String get recommendedForYou1;

  /// No description provided for @ai.
  ///
  /// In en, this message translates to:
  /// **'✨ AI'**
  String get ai;

  /// No description provided for @viewEvent.
  ///
  /// In en, this message translates to:
  /// **'View event →'**
  String get viewEvent;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @verificationCode.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// No description provided for @verifyEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify email'**
  String get verifyEmail;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @backToEventDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Back to event discovery'**
  String get backToEventDiscovery;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get signingIn;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @createOne.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get createOne;

  /// No description provided for @signInToContinueCreatingYourEv.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue creating your event.'**
  String get signInToContinueCreatingYourEv;

  /// No description provided for @createYourKhairAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your Khair account'**
  String get createYourKhairAccount;

  /// No description provided for @discoverEventsJoinCommunitiesB.
  ///
  /// In en, this message translates to:
  /// **'Discover events. Join communities. Be part of something meaningful.'**
  String get discoverEventsJoinCommunitiesB;

  /// No description provided for @orContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'or continue with email'**
  String get orContinueWithEmail;

  /// No description provided for @creatingYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Creating your account…'**
  String get creatingYourAccount;

  /// No description provided for @createAccount1.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount1;

  /// No description provided for @alreadyHaveAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAnAccount;

  /// No description provided for @use8OrMoreCharacters.
  ///
  /// In en, this message translates to:
  /// **'Use 8 or more characters.'**
  String get use8OrMoreCharacters;

  /// No description provided for @g.
  ///
  /// In en, this message translates to:
  /// **'G'**
  String get g;

  /// No description provided for @khairEvents.
  ///
  /// In en, this message translates to:
  /// **'Khair events'**
  String get khairEvents;

  /// No description provided for @selectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select country'**
  String get selectCountry;

  /// No description provided for @shareEvent.
  ///
  /// In en, this message translates to:
  /// **'Share event'**
  String get shareEvent;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @addToGoogleCalendar.
  ///
  /// In en, this message translates to:
  /// **'Add to Google Calendar'**
  String get addToGoogleCalendar;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on map'**
  String get viewOnMap;

  /// No description provided for @mapPreviewIsUnavailableForThis.
  ///
  /// In en, this message translates to:
  /// **'Map preview is unavailable for this event.'**
  String get mapPreviewIsUnavailableForThis;

  /// No description provided for @onlineEvent.
  ///
  /// In en, this message translates to:
  /// **'Online event'**
  String get onlineEvent;

  /// No description provided for @joinProviderMeeting.
  ///
  /// In en, this message translates to:
  /// **'Join {provider} meeting'**
  String joinProviderMeeting(Object provider);

  /// No description provided for @verificationCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the six-digit code we sent to {email}.'**
  String verificationCodeSentTo(Object email);

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @noAttentionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs your attention right now.'**
  String get noAttentionNeeded;

  /// No description provided for @organizerActivityWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your organizer activity will appear here.'**
  String get organizerActivityWillAppear;

  /// No description provided for @noConfirmedAttendees.
  ///
  /// In en, this message translates to:
  /// **'No confirmed attendees yet.'**
  String get noConfirmedAttendees;

  /// No description provided for @loadingAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Loading analytics...'**
  String get loadingAnalytics;

  /// No description provided for @loadingProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading profile...'**
  String get loadingProfile;

  /// No description provided for @theOrganizerHasNotAddedADescri.
  ///
  /// In en, this message translates to:
  /// **'The organizer has not added a description yet.'**
  String get theOrganizerHasNotAddedADescri;

  /// No description provided for @verifiedOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Verified organizer'**
  String get verifiedOrganizer;

  /// No description provided for @eventOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Event organizer'**
  String get eventOrganizer;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @attendees.
  ///
  /// In en, this message translates to:
  /// **'Attendees'**
  String get attendees;

  /// No description provided for @weCouldntLoadThisEvent.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load this event.'**
  String get weCouldntLoadThisEvent;

  /// No description provided for @theEventMayHaveBeenRemovedOrIs.
  ///
  /// In en, this message translates to:
  /// **'The event may have been removed or is temporarily unavailable.'**
  String get theEventMayHaveBeenRemovedOrIs;

  /// No description provided for @leaveEvent.
  ///
  /// In en, this message translates to:
  /// **'Leave event?'**
  String get leaveEvent;

  /// No description provided for @yourReservationWillBeReleased.
  ///
  /// In en, this message translates to:
  /// **'Your reservation will be released.'**
  String get yourReservationWillBeReleased;

  /// No description provided for @keepReservation.
  ///
  /// In en, this message translates to:
  /// **'Keep reservation'**
  String get keepReservation;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @noJoinedEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No joined events yet'**
  String get noJoinedEventsYet;

  /// No description provided for @youAreRegistered.
  ///
  /// In en, this message translates to:
  /// **'You are registered!'**
  String get youAreRegistered;

  /// No description provided for @mayThisGatheringBenefitYounyou.
  ///
  /// In en, this message translates to:
  /// **'May this gathering benefit you.\\nYour seat has been confirmed.'**
  String get mayThisGatheringBenefitYounyou;

  /// No description provided for @thisIsAPaidEventPleaseRemember.
  ///
  /// In en, this message translates to:
  /// **'This is a paid event. Please remember to bring payment to the venue.'**
  String get thisIsAPaidEventPleaseRemember;

  /// No description provided for @viewMyEvents.
  ///
  /// In en, this message translates to:
  /// **'View My Events'**
  String get viewMyEvents;

  /// No description provided for @savedEvents.
  ///
  /// In en, this message translates to:
  /// **'Saved events'**
  String get savedEvents;

  /// No description provided for @noSavedEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No saved events yet'**
  String get noSavedEventsYet;

  /// No description provided for @saveEventsYouWantToRevisit.
  ///
  /// In en, this message translates to:
  /// **'Save events you want to revisit.'**
  String get saveEventsYouWantToRevisit;

  /// No description provided for @exploreEvents.
  ///
  /// In en, this message translates to:
  /// **'Explore events'**
  String get exploreEvents;

  /// No description provided for @communityImpact.
  ///
  /// In en, this message translates to:
  /// **'COMMUNITY IMPACT'**
  String get communityImpact;

  /// No description provided for @joinTheMovement.
  ///
  /// In en, this message translates to:
  /// **'JOIN THE MOVEMENT'**
  String get joinTheMovement;

  /// No description provided for @noFeaturedEventsRightNow.
  ///
  /// In en, this message translates to:
  /// **'No featured events right now.'**
  String get noFeaturedEventsRightNow;

  /// No description provided for @searchForHalalEventsWorkshopsO.
  ///
  /// In en, this message translates to:
  /// **'Search for Halal events, workshops, or circles...'**
  String get searchForHalalEventsWorkshopsO;

  /// No description provided for @toUnlockOrganizerMode.
  ///
  /// In en, this message translates to:
  /// **'to unlock organizer mode'**
  String get toUnlockOrganizerMode;

  /// No description provided for @viewDashboard.
  ///
  /// In en, this message translates to:
  /// **'VIEW DASHBOARD'**
  String get viewDashboard;

  /// No description provided for @upcomingForYou.
  ///
  /// In en, this message translates to:
  /// **'Upcoming for You'**
  String get upcomingForYou;

  /// No description provided for @noUpcomingEventsFound.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events found.'**
  String get noUpcomingEventsFound;

  /// No description provided for @attendees1.
  ///
  /// In en, this message translates to:
  /// **'attendees'**
  String get attendees1;

  /// No description provided for @weCouldntUpdateYourSavedEvents.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t update your saved events.'**
  String get weCouldntUpdateYourSavedEvents;

  /// No description provided for @recommendedForYou2.
  ///
  /// In en, this message translates to:
  /// **'Recommended for you'**
  String get recommendedForYou2;

  /// No description provided for @searchEventsOrPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search events or places'**
  String get searchEventsOrPlaces;

  /// No description provided for @exploreWhatsHappeningNearby.
  ///
  /// In en, this message translates to:
  /// **'Explore what’s happening nearby'**
  String get exploreWhatsHappeningNearby;

  /// No description provided for @saveEvent.
  ///
  /// In en, this message translates to:
  /// **'Save event'**
  String get saveEvent;

  /// No description provided for @nothingHappeningHereYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing happening here yet'**
  String get nothingHappeningHereYet;

  /// No description provided for @moveTheMapOrExploreAWiderArea.
  ///
  /// In en, this message translates to:
  /// **'Move the map or explore a wider area.'**
  String get moveTheMapOrExploreAWiderArea;

  /// No description provided for @exploreOnlineEvents.
  ///
  /// In en, this message translates to:
  /// **'Explore online events'**
  String get exploreOnlineEvents;

  /// No description provided for @when.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get when;

  /// No description provided for @freeOnly.
  ///
  /// In en, this message translates to:
  /// **'Free only'**
  String get freeOnly;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @signInToSaveEventsAndKeepThemI.
  ///
  /// In en, this message translates to:
  /// **'Sign in to save events and keep them in sync.'**
  String get signInToSaveEventsAndKeepThemI;

  /// No description provided for @readAll.
  ///
  /// In en, this message translates to:
  /// **'Read all'**
  String get readAll;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotificationsYet;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You\\'**
  String get you;

  /// No description provided for @failedToLoadNotifications.
  ///
  /// In en, this message translates to:
  /// **'Failed to load notifications'**
  String get failedToLoadNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @notificationEventJoinTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re registered 🎉'**
  String get notificationEventJoinTitle;

  /// No description provided for @notificationEventJoinBody.
  ///
  /// In en, this message translates to:
  /// **'You\'ve successfully joined\n{eventTitle}'**
  String notificationEventJoinBody(Object eventTitle);

  /// No description provided for @notificationEventParticipantJoinedTitle.
  ///
  /// In en, this message translates to:
  /// **'New participant joined'**
  String get notificationEventParticipantJoinedTitle;

  /// No description provided for @notificationEventParticipantJoinedBody.
  ///
  /// In en, this message translates to:
  /// **'A new participant joined your event:\n{eventTitle}'**
  String notificationEventParticipantJoinedBody(Object eventTitle);

  /// No description provided for @notificationViewEvent.
  ///
  /// In en, this message translates to:
  /// **'View event details'**
  String get notificationViewEvent;

  /// No description provided for @notificationOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get notificationOnline;

  /// No description provided for @notificationLocation.
  ///
  /// In en, this message translates to:
  /// **'{location}'**
  String notificationLocation(Object location);

  /// No description provided for @notificationFree.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get notificationFree;

  /// No description provided for @notificationPayAtVenue.
  ///
  /// In en, this message translates to:
  /// **'{price} · Pay at venue'**
  String notificationPayAtVenue(Object price);

  /// No description provided for @notificationWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Khair 🎉'**
  String get notificationWelcomeTitle;

  /// No description provided for @notificationWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum {firstName},\nWe\'re glad you\'re here. Start discovering events and communities that interest you.'**
  String notificationWelcomeBody(Object firstName);

  /// No description provided for @notificationWelcomeUnderReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Khair – Account under review'**
  String get notificationWelcomeUnderReviewTitle;

  /// No description provided for @notificationWelcomeUnderReviewBody.
  ///
  /// In en, this message translates to:
  /// **'Assalamu Alaikum {firstName},\\nYour account is under review by the Khair team. We will notify you when the review is complete.'**
  String notificationWelcomeUnderReviewBody(Object firstName);

  /// No description provided for @notificationReceivedAt.
  ///
  /// In en, this message translates to:
  /// **'Received {time}'**
  String notificationReceivedAt(Object time);

  /// No description provided for @notificationEventReminderTitle.
  ///
  /// In en, this message translates to:
  /// **'Event reminder'**
  String get notificationEventReminderTitle;

  /// No description provided for @notificationEventReminderBody.
  ///
  /// In en, this message translates to:
  /// **'{eventTitle} starts in {reminderLabel}.'**
  String notificationEventReminderBody(Object eventTitle, Object reminderLabel);

  /// No description provided for @notificationUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread notification'**
  String get notificationUnread;

  /// No description provided for @notificationClose.
  ///
  /// In en, this message translates to:
  /// **'Close notification'**
  String get notificationClose;

  /// No description provided for @createAnEvent.
  ///
  /// In en, this message translates to:
  /// **'Create an event'**
  String get createAnEvent;

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get saveDraft;

  /// No description provided for @letsStartWithTheBasics.
  ///
  /// In en, this message translates to:
  /// **'Let’s start with the basics'**
  String get letsStartWithTheBasics;

  /// No description provided for @tellPeopleWhatYourEventIsAbout.
  ///
  /// In en, this message translates to:
  /// **'Tell people what your event is about.'**
  String get tellPeopleWhatYourEventIsAbout;

  /// No description provided for @eventTitle1.
  ///
  /// In en, this message translates to:
  /// **'Event title'**
  String get eventTitle1;

  /// No description provided for @suggestCategoryWithAi.
  ///
  /// In en, this message translates to:
  /// **'Suggest category with AI'**
  String get suggestCategoryWithAi;

  /// No description provided for @whenAndWhereIsItHappening.
  ///
  /// In en, this message translates to:
  /// **'When and where is it happening?'**
  String get whenAndWhereIsItHappening;

  /// No description provided for @giveAttendeesTheDetailsTheyNee.
  ///
  /// In en, this message translates to:
  /// **'Give attendees the details they need to plan ahead.'**
  String get giveAttendeesTheDetailsTheyNee;

  /// No description provided for @timezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get timezone;

  /// No description provided for @venueName.
  ///
  /// In en, this message translates to:
  /// **'Venue name'**
  String get venueName;

  /// No description provided for @streetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get streetAddress;

  /// No description provided for @pinpointTheLocation.
  ///
  /// In en, this message translates to:
  /// **'Pinpoint the location'**
  String get pinpointTheLocation;

  /// No description provided for @meetingUrl.
  ///
  /// In en, this message translates to:
  /// **'Meeting URL'**
  String get meetingUrl;

  /// No description provided for @instructionsOptional.
  ///
  /// In en, this message translates to:
  /// **'Instructions (optional)'**
  String get instructionsOptional;

  /// No description provided for @whoIsThisEventFor.
  ///
  /// In en, this message translates to:
  /// **'Who is this event for?'**
  String get whoIsThisEventFor;

  /// No description provided for @setAttendanceAndAccessPreferen.
  ///
  /// In en, this message translates to:
  /// **'Set attendance and access preferences.'**
  String get setAttendanceAndAccessPreferen;

  /// No description provided for @profileGender.
  ///
  /// In en, this message translates to:
  /// **'Gender eligibility'**
  String get profileGender;

  /// No description provided for @profileGenderNotSet.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get profileGenderNotSet;

  /// No description provided for @profileGenderMan.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get profileGenderMan;

  /// No description provided for @profileGenderWoman.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get profileGenderWoman;

  /// No description provided for @profileGenderPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Used only to determine eligibility for restricted events. It is never shown publicly.'**
  String get profileGenderPrivacy;

  /// No description provided for @profileGenderChangeWarning.
  ///
  /// In en, this message translates to:
  /// **'Changing this may affect your upcoming registrations for restricted events. Existing registrations will be kept and flagged for review.'**
  String get profileGenderChangeWarning;

  /// No description provided for @profileGenderChangeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get profileGenderChangeConfirm;

  /// No description provided for @eventEligibilityWomenOnly.
  ///
  /// In en, this message translates to:
  /// **'Women-only event'**
  String get eventEligibilityWomenOnly;

  /// No description provided for @eventEligibilityMenOnly.
  ///
  /// In en, this message translates to:
  /// **'Men-only event'**
  String get eventEligibilityMenOnly;

  /// No description provided for @eventEligibilityRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get eventEligibilityRequiredTitle;

  /// No description provided for @eventEligibilityRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'This event has an attendance restriction. Choose your eligibility detail in your private profile before joining.'**
  String get eventEligibilityRequiredMessage;

  /// No description provided for @eventEligibilityCompleteProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete profile'**
  String get eventEligibilityCompleteProfile;

  /// No description provided for @eventEligibilityCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get eventEligibilityCancel;

  /// No description provided for @eventEligibilityNotEligible.
  ///
  /// In en, this message translates to:
  /// **'Your profile does not meet this event\'s attendance eligibility.'**
  String get eventEligibilityNotEligible;

  /// No description provided for @eventJoinError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t join this event right now. Please try again.'**
  String get eventJoinError;

  /// No description provided for @unlimited.
  ///
  /// In en, this message translates to:
  /// **'Unlimited'**
  String get unlimited;

  /// No description provided for @limited.
  ///
  /// In en, this message translates to:
  /// **'Limited'**
  String get limited;

  /// No description provided for @paidOnlineEventsAreNotSupporte.
  ///
  /// In en, this message translates to:
  /// **'Paid online events are not supported yet.'**
  String get paidOnlineEventsAreNotSupporte;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @anythingAttendeesShouldKnowOpt.
  ///
  /// In en, this message translates to:
  /// **'Anything attendees should know? (optional)'**
  String get anythingAttendeesShouldKnowOpt;

  /// No description provided for @makeYourEventStandOut.
  ///
  /// In en, this message translates to:
  /// **'Make your event stand out'**
  String get makeYourEventStandOut;

  /// No description provided for @addAStrongCoverImageSoPeopleIn.
  ///
  /// In en, this message translates to:
  /// **'Add a strong cover image so people instantly understand your event.'**
  String get addAStrongCoverImageSoPeopleIn;

  /// No description provided for @replaceCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Replace cover image'**
  String get replaceCoverImage;

  /// No description provided for @jpgPngOrWebpUpTo10Mb169Recomme.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG or WebP · up to 5 MB · 16:9 recommended'**
  String get jpgPngOrWebpUpTo10Mb169Recomme;

  /// No description provided for @reviewYourEvent.
  ///
  /// In en, this message translates to:
  /// **'Review your event'**
  String get reviewYourEvent;

  /// No description provided for @makeSureEverythingLooksRightBe.
  ///
  /// In en, this message translates to:
  /// **'Make sure everything looks right before sending it to Khair moderation.'**
  String get makeSureEverythingLooksRightBe;

  /// No description provided for @readyToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Ready to submit'**
  String get readyToSubmit;

  /// No description provided for @submission.
  ///
  /// In en, this message translates to:
  /// **'Submission'**
  String get submission;

  /// No description provided for @yourEventWillBeSavedAsPendingR.
  ///
  /// In en, this message translates to:
  /// **'Your event will be saved as pending review. It becomes discoverable only after admin approval.'**
  String get yourEventWillBeSavedAsPendingR;

  /// No description provided for @iConfirmTheseEventDetailsAreAc.
  ///
  /// In en, this message translates to:
  /// **'I confirm these event details are accurate.'**
  String get iConfirmTheseEventDetailsAreAc;

  /// No description provided for @aiSuggestion.
  ///
  /// In en, this message translates to:
  /// **'AI suggestion'**
  String get aiSuggestion;

  /// No description provided for @yourEventIsUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Your event is under review'**
  String get yourEventIsUnderReview;

  /// No description provided for @yourEventHasBeenSubmittedForRe.
  ///
  /// In en, this message translates to:
  /// **'Your event has been submitted for review. We will notify you when moderation is complete.'**
  String get yourEventHasBeenSubmittedForRe;

  /// No description provided for @backToOrganizerHub.
  ///
  /// In en, this message translates to:
  /// **'Back to Organizer Hub'**
  String get backToOrganizerHub;

  /// No description provided for @chooseACoverImage.
  ///
  /// In en, this message translates to:
  /// **'Choose a cover image'**
  String get chooseACoverImage;

  /// No description provided for @dragAndDropOrTapToBrowse.
  ///
  /// In en, this message translates to:
  /// **'Drag and drop or tap to browse'**
  String get dragAndDropOrTapToBrowse;

  /// No description provided for @livePreview.
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get livePreview;

  /// No description provided for @whatDoesThisDocumentVerify.
  ///
  /// In en, this message translates to:
  /// **'What does this document verify?'**
  String get whatDoesThisDocumentVerify;

  /// No description provided for @closeOrganizerApplication.
  ///
  /// In en, this message translates to:
  /// **'Close organizer application'**
  String get closeOrganizerApplication;

  /// No description provided for @becomeAnOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Become an organizer'**
  String get becomeAnOrganizer;

  /// No description provided for @countryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get countryCode;

  /// No description provided for @tr.
  ///
  /// In en, this message translates to:
  /// **'TR'**
  String get tr;

  /// No description provided for @publicLogoOrProfileImage.
  ///
  /// In en, this message translates to:
  /// **'Public logo or profile image'**
  String get publicLogoOrProfileImage;

  /// No description provided for @jpgPngOrWebpUpTo5MbPrivateUnti.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG, or WebP · up to 5 MB. Private until approved.'**
  String get jpgPngOrWebpUpTo5MbPrivateUnti;

  /// No description provided for @publicRepresentativePhoto.
  ///
  /// In en, this message translates to:
  /// **'Public representative photo'**
  String get publicRepresentativePhoto;

  /// No description provided for @requiredForIndividualOrganizer.
  ///
  /// In en, this message translates to:
  /// **'Required for individual organizers. Visible only after approval.'**
  String get requiredForIndividualOrganizer;

  /// No description provided for @officialLinks.
  ///
  /// In en, this message translates to:
  /// **'Official links'**
  String get officialLinks;

  /// No description provided for @optionalButUsefulForAFasterRev.
  ///
  /// In en, this message translates to:
  /// **'Optional, but useful for a faster review. Only add official public links.'**
  String get optionalButUsefulForAFasterRev;

  /// No description provided for @verificationEvidence.
  ///
  /// In en, this message translates to:
  /// **'Verification evidence'**
  String get verificationEvidence;

  /// No description provided for @documentsAreEncryptedInPrivate.
  ///
  /// In en, this message translates to:
  /// **'Documents are encrypted in private storage and are accessible only to authorized Khair reviewers.'**
  String get documentsAreEncryptedInPrivate;

  /// No description provided for @uploadVerificationDocument.
  ///
  /// In en, this message translates to:
  /// **'Upload verification document'**
  String get uploadVerificationDocument;

  /// No description provided for @plannedEventCategories.
  ///
  /// In en, this message translates to:
  /// **'Planned event categories'**
  String get plannedEventCategories;

  /// No description provided for @typicalAudience.
  ///
  /// In en, this message translates to:
  /// **'Typical audience'**
  String get typicalAudience;

  /// No description provided for @iAcceptTheKhairOrganizerStanda.
  ///
  /// In en, this message translates to:
  /// **'I accept the Khair Organizer Standards'**
  String get iAcceptTheKhairOrganizerStanda;

  /// No description provided for @iWillKeepEventsSafeRespectfulA.
  ///
  /// In en, this message translates to:
  /// **'I will keep events safe, respectful, accurate, and inclusive. Version 2026-08.'**
  String get iWillKeepEventsSafeRespectfulA;

  /// No description provided for @readOrganizerStandardsV202608.
  ///
  /// In en, this message translates to:
  /// **'Read Organizer Standards · v2026-08'**
  String get readOrganizerStandardsV202608;

  /// No description provided for @khairOrganizerStandards.
  ///
  /// In en, this message translates to:
  /// **'Khair Organizer Standards'**
  String get khairOrganizerStandards;

  /// No description provided for @version202608.
  ///
  /// In en, this message translates to:
  /// **'Version 2026-08'**
  String get version202608;

  /// No description provided for @iUnderstand.
  ///
  /// In en, this message translates to:
  /// **'I understand'**
  String get iUnderstand;

  /// No description provided for @evidenceType.
  ///
  /// In en, this message translates to:
  /// **'Evidence type'**
  String get evidenceType;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @timeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timeline;

  /// No description provided for @past.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get past;

  /// No description provided for @eventsByType.
  ///
  /// In en, this message translates to:
  /// **'Events by Type'**
  String get eventsByType;

  /// No description provided for @noEventDataToDisplay.
  ///
  /// In en, this message translates to:
  /// **'No event data to display'**
  String get noEventDataToDisplay;

  /// No description provided for @notifyAttendees.
  ///
  /// In en, this message translates to:
  /// **'Notify Attendees'**
  String get notifyAttendees;

  /// No description provided for @sendMessageToAttendees.
  ///
  /// In en, this message translates to:
  /// **'Send Message to Attendees'**
  String get sendMessageToAttendees;

  /// No description provided for @messageWillBeSentAsPushNotific.
  ///
  /// In en, this message translates to:
  /// **'Message will be sent as push notification and in-app notification to all confirmed attendees of '**
  String get messageWillBeSentAsPushNotific;

  /// No description provided for @typeYourMessageToAttendees.
  ///
  /// In en, this message translates to:
  /// **'Type your message to attendees...'**
  String get typeYourMessageToAttendees;

  /// No description provided for @includeEventLinkInNotification.
  ///
  /// In en, this message translates to:
  /// **'Include event link in notification'**
  String get includeEventLinkInNotification;

  /// No description provided for @messageSentToAllAttendees.
  ///
  /// In en, this message translates to:
  /// **'Message sent to all attendees!'**
  String get messageSentToAllAttendees;

  /// No description provided for @eventStatus.
  ///
  /// In en, this message translates to:
  /// **'Event status'**
  String get eventStatus;

  /// No description provided for @backToMyEvents.
  ///
  /// In en, this message translates to:
  /// **'Back to My Events'**
  String get backToMyEvents;

  /// No description provided for @organizerHub.
  ///
  /// In en, this message translates to:
  /// **'Organizer Hub'**
  String get organizerHub;

  /// No description provided for @draftEvents.
  ///
  /// In en, this message translates to:
  /// **'Drafts'**
  String get draftEvents;

  /// No description provided for @noDraftEvents.
  ///
  /// In en, this message translates to:
  /// **'No draft events.'**
  String get noDraftEvents;

  /// No description provided for @noPastEvents.
  ///
  /// In en, this message translates to:
  /// **'No past events.'**
  String get noPastEvents;

  /// No description provided for @organizerRangeLast7Days.
  ///
  /// In en, this message translates to:
  /// **'in the last 7 days'**
  String get organizerRangeLast7Days;

  /// No description provided for @organizerRangeThisMonth.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get organizerRangeThisMonth;

  /// No description provided for @organizerRangeLastMonth.
  ///
  /// In en, this message translates to:
  /// **'last month'**
  String get organizerRangeLastMonth;

  /// No description provided for @organizerRangeSelected.
  ///
  /// In en, this message translates to:
  /// **'in your selected range'**
  String get organizerRangeSelected;

  /// No description provided for @organizerRangeLast30Days.
  ///
  /// In en, this message translates to:
  /// **'in the last 30 days'**
  String get organizerRangeLast30Days;

  /// No description provided for @organizerSummaryNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have an upcoming event yet. You have {attendees} confirmed attendees {range}.'**
  String organizerSummaryNoUpcoming(Object attendees, Object range);

  /// No description provided for @organizerSummaryUpcoming.
  ///
  /// In en, this message translates to:
  /// **'You have {upcoming} upcoming {eventsLabel} and {attendees} confirmed attendees {range}.'**
  String organizerSummaryUpcoming(
      Object attendees, Object eventsLabel, Object range, Object upcoming);

  /// No description provided for @organizerEvent.
  ///
  /// In en, this message translates to:
  /// **'event'**
  String get organizerEvent;

  /// No description provided for @organizerEvents.
  ///
  /// In en, this message translates to:
  /// **'events'**
  String get organizerEvents;

  /// No description provided for @performanceViewsRange.
  ///
  /// In en, this message translates to:
  /// **'Unique event-detail viewers in the selected range'**
  String get performanceViewsRange;

  /// No description provided for @performanceJoinsRange.
  ///
  /// In en, this message translates to:
  /// **'Confirmed unique joins in the selected range'**
  String get performanceJoinsRange;

  /// No description provided for @yourNextEvent.
  ///
  /// In en, this message translates to:
  /// **'Your next event'**
  String get yourNextEvent;

  /// No description provided for @upcomingEvents.
  ///
  /// In en, this message translates to:
  /// **'Upcoming events'**
  String get upcomingEvents;

  /// No description provided for @confirmedAttendees.
  ///
  /// In en, this message translates to:
  /// **'Confirmed attendees'**
  String get confirmedAttendees;

  /// No description provided for @eventViews.
  ///
  /// In en, this message translates to:
  /// **'Event views'**
  String get eventViews;

  /// No description provided for @joinRate.
  ///
  /// In en, this message translates to:
  /// **'Join rate'**
  String get joinRate;

  /// No description provided for @manageEvent.
  ///
  /// In en, this message translates to:
  /// **'Manage event'**
  String get manageEvent;

  /// No description provided for @sendUpdate.
  ///
  /// In en, this message translates to:
  /// **'Send update'**
  String get sendUpdate;

  /// No description provided for @readyToHostYourNextEvent.
  ///
  /// In en, this message translates to:
  /// **'Ready to host your next event?'**
  String get readyToHostYourNextEvent;

  /// No description provided for @createAnEventAndStartBuildingY.
  ///
  /// In en, this message translates to:
  /// **'Create an event and start building your community.'**
  String get createAnEventAndStartBuildingY;

  /// No description provided for @yourEvents.
  ///
  /// In en, this message translates to:
  /// **'Your events'**
  String get yourEvents;

  /// No description provided for @eventActions.
  ///
  /// In en, this message translates to:
  /// **'Event actions'**
  String get eventActions;

  /// No description provided for @viewAttendees.
  ///
  /// In en, this message translates to:
  /// **'View attendees'**
  String get viewAttendees;

  /// No description provided for @needsYourAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs your attention'**
  String get needsYourAttention;

  /// No description provided for @performance.
  ///
  /// In en, this message translates to:
  /// **'Performance'**
  String get performance;

  /// No description provided for @views.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get views;

  /// No description provided for @joins.
  ///
  /// In en, this message translates to:
  /// **'Joins'**
  String get joins;

  /// No description provided for @noPerformanceDataYet.
  ///
  /// In en, this message translates to:
  /// **'No performance data yet.'**
  String get noPerformanceDataYet;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @noAttendeesYetTheyWillAppearHe.
  ///
  /// In en, this message translates to:
  /// **'No attendees yet. They will appear here.'**
  String get noAttendeesYetTheyWillAppearHe;

  /// No description provided for @weCouldntLoadYourOrganizerHub.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load your Organizer Hub.'**
  String get weCouldntLoadYourOrganizerHub;

  /// No description provided for @sendAnEventUpdate.
  ///
  /// In en, this message translates to:
  /// **'Send an event update'**
  String get sendAnEventUpdate;

  /// No description provided for @aShortUpdateTitle.
  ///
  /// In en, this message translates to:
  /// **'A short update title'**
  String get aShortUpdateTitle;

  /// No description provided for @updateType.
  ///
  /// In en, this message translates to:
  /// **'Update type'**
  String get updateType;

  /// No description provided for @generalUpdate.
  ///
  /// In en, this message translates to:
  /// **'General update'**
  String get generalUpdate;

  /// No description provided for @scheduleUpdate.
  ///
  /// In en, this message translates to:
  /// **'Schedule update'**
  String get scheduleUpdate;

  /// No description provided for @reminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminder;

  /// No description provided for @importantUpdate.
  ///
  /// In en, this message translates to:
  /// **'Important update'**
  String get importantUpdate;

  /// No description provided for @writeTheUpdateForAttendees.
  ///
  /// In en, this message translates to:
  /// **'Write the update for attendees'**
  String get writeTheUpdateForAttendees;

  /// No description provided for @failedToUploadImagePleaseTryAg.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image. Please try again.'**
  String get failedToUploadImagePleaseTryAg;

  /// No description provided for @profileUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully'**
  String get profileUpdatedSuccessfully;

  /// No description provided for @organizerProfile1.
  ///
  /// In en, this message translates to:
  /// **'Organizer profile'**
  String get organizerProfile1;

  /// No description provided for @organizerProfileNotFound.
  ///
  /// In en, this message translates to:
  /// **'Organizer profile not found.'**
  String get organizerProfileNotFound;

  /// No description provided for @editProfile1.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile1;

  /// No description provided for @yourEventProfile.
  ///
  /// In en, this message translates to:
  /// **'Your event profile'**
  String get yourEventProfile;

  /// No description provided for @keepTheseDetailsCurrentSoKhair.
  ///
  /// In en, this message translates to:
  /// **'Keep these details current so Khair can personalize your event experience.'**
  String get keepTheseDetailsCurrentSoKhair;

  /// No description provided for @displayName1.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName1;

  /// No description provided for @loadingYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Loading your profile…'**
  String get loadingYourProfile;

  /// No description provided for @accountInformation1.
  ///
  /// In en, this message translates to:
  /// **'Account information'**
  String get accountInformation1;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @emailUpdates.
  ///
  /// In en, this message translates to:
  /// **'Email updates'**
  String get emailUpdates;

  /// No description provided for @emailNotificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Email notifications on'**
  String get emailNotificationsOn;

  /// No description provided for @emailNotificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Email notifications off'**
  String get emailNotificationsOff;

  /// No description provided for @couldNotUpdateYourPreferencePl.
  ///
  /// In en, this message translates to:
  /// **'Could not update your preference. Please try again.'**
  String get couldNotUpdateYourPreferencePl;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @noUpcomingEventsYet.
  ///
  /// In en, this message translates to:
  /// **'No upcoming events yet'**
  String get noUpcomingEventsYet;

  /// No description provided for @discoverSomethingWorthShowingU.
  ///
  /// In en, this message translates to:
  /// **'Discover something worth showing up for.'**
  String get discoverSomethingWorthShowingU;

  /// No description provided for @signOut1.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut1;

  /// No description provided for @weCouldntLoadYourProfile.
  ///
  /// In en, this message translates to:
  /// **'We couldn’t load your profile.'**
  String get weCouldntLoadYourProfile;

  /// No description provided for @checkYourConnectionAndTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get checkYourConnectionAndTryAgain;

  /// No description provided for @lastUpdatedAugust2026.
  ///
  /// In en, this message translates to:
  /// **'Last updated: August 2026'**
  String get lastUpdatedAugust2026;

  /// No description provided for @khairSupport.
  ///
  /// In en, this message translates to:
  /// **'Khair Support'**
  String get khairSupport;

  /// No description provided for @youAreChattingWithKhairAi.
  ///
  /// In en, this message translates to:
  /// **'You are chatting with Khair AI'**
  String get youAreChattingWithKhairAi;

  /// No description provided for @thisTicketHasBeenResolved.
  ///
  /// In en, this message translates to:
  /// **'This ticket has been resolved.'**
  String get thisTicketHasBeenResolved;

  /// No description provided for @applyForOfficialnorganizerStat.
  ///
  /// In en, this message translates to:
  /// **'Apply for Official\\nOrganizer Status'**
  String get applyForOfficialnorganizerStat;

  /// No description provided for @uploadYourDocumentsSoOurTeamCa.
  ///
  /// In en, this message translates to:
  /// **'Upload your documents so our team can verify your identity'**
  String get uploadYourDocumentsSoOurTeamCa;

  /// No description provided for @officialProfileImage.
  ///
  /// In en, this message translates to:
  /// **'Official Profile Image'**
  String get officialProfileImage;

  /// No description provided for @qualificationDocument.
  ///
  /// In en, this message translates to:
  /// **'Qualification Document'**
  String get qualificationDocument;

  /// No description provided for @iConfirmThatAllProvidedDocumen.
  ///
  /// In en, this message translates to:
  /// **'I confirm that all provided documents are authentic and I am authorized to represent this organization.'**
  String get iConfirmThatAllProvidedDocumen;

  /// No description provided for @skipForNowI.
  ///
  /// In en, this message translates to:
  /// **'Skip for now — I\\'**
  String get skipForNowI;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted!'**
  String get submitted;

  /// No description provided for @yourVerificationRequestHasBeen.
  ///
  /// In en, this message translates to:
  /// **'Your verification request has been submitted. Our team will review it within 24–48 hours. You\\'**
  String get yourVerificationRequestHasBeen;

  /// No description provided for @startExploring.
  ///
  /// In en, this message translates to:
  /// **'Start Exploring'**
  String get startExploring;

  /// No description provided for @revisionCount.
  ///
  /// In en, this message translates to:
  /// **'{count} revisions'**
  String revisionCount(int count);

  /// No description provided for @supportTicketSummary.
  ///
  /// In en, this message translates to:
  /// **'{name} ({email})\\nStatus: {status} | Priority: {priority}'**
  String supportTicketSummary(
      Object name, Object email, Object status, Object priority);

  /// No description provided for @assignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned: {name}'**
  String assignedTo(Object name);

  /// No description provided for @aiSummary.
  ///
  /// In en, this message translates to:
  /// **'AI summary: {summary}'**
  String aiSummary(Object summary);

  /// No description provided for @privateDocumentType.
  ///
  /// In en, this message translates to:
  /// **'{type} · private'**
  String privateDocumentType(Object type);

  /// No description provided for @countryDisplayName.
  ///
  /// In en, this message translates to:
  /// **'{flag} {name}'**
  String countryDisplayName(Object flag, Object name);

  /// No description provided for @eventsInArea.
  ///
  /// In en, this message translates to:
  /// **'{count} events in this area'**
  String eventsInArea(int count);

  /// No description provided for @eventDateTime.
  ///
  /// In en, this message translates to:
  /// **'{date} · {time}'**
  String eventDateTime(Object date, Object time);

  /// No description provided for @createEventStep.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of 5'**
  String createEventStep(int step);

  /// No description provided for @createEventStepLabel.
  ///
  /// In en, this message translates to:
  /// **' · {label}'**
  String createEventStepLabel(Object label);

  /// No description provided for @progressPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String progressPercent(int percent);

  /// No description provided for @organizerApplicationStep.
  ///
  /// In en, this message translates to:
  /// **'Organizer application step {step} of 4'**
  String organizerApplicationStep(int step);

  /// No description provided for @stepNumber.
  ///
  /// In en, this message translates to:
  /// **'{number}'**
  String stepNumber(int number);

  /// No description provided for @submittedOn.
  ///
  /// In en, this message translates to:
  /// **'Submitted {date}'**
  String submittedOn(Object date);

  /// No description provided for @documentType.
  ///
  /// In en, this message translates to:
  /// **'Doc: {type}'**
  String documentType(Object type);

  /// No description provided for @reportsManagement.
  ///
  /// In en, this message translates to:
  /// **'Reports Management'**
  String get reportsManagement;

  /// No description provided for @filterLabelCount.
  ///
  /// In en, this message translates to:
  /// **'{label} ({count})'**
  String filterLabelCount(Object label, int count);

  /// No description provided for @organizerAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Your account does not have access to the organizer application.'**
  String get organizerAccessDenied;

  /// No description provided for @organizerApplicationLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not load your organizer application. Try again.'**
  String get organizerApplicationLoadFailed;

  /// No description provided for @draftSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not save your draft.'**
  String get draftSaveFailed;

  /// No description provided for @enterPublicOrganizerName.
  ///
  /// In en, this message translates to:
  /// **'Enter your public organizer name.'**
  String get enterPublicOrganizerName;

  /// No description provided for @enterResponsibleRepresentative.
  ///
  /// In en, this message translates to:
  /// **'Enter the responsible representative.'**
  String get enterResponsibleRepresentative;

  /// No description provided for @enterVerifiedAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your verified account email.'**
  String get enterVerifiedAccountEmail;

  /// No description provided for @enterCity.
  ///
  /// In en, this message translates to:
  /// **'Enter your city.'**
  String get enterCity;

  /// No description provided for @organizationDescriptionMinLength.
  ///
  /// In en, this message translates to:
  /// **'Add at least 50 characters about your organization.'**
  String get organizationDescriptionMinLength;

  /// No description provided for @uploadLogoRequired.
  ///
  /// In en, this message translates to:
  /// **'Upload a public logo or profile image.'**
  String get uploadLogoRequired;

  /// No description provided for @uploadRepresentativePhotoRequired.
  ///
  /// In en, this message translates to:
  /// **'Upload your public profile photo.'**
  String get uploadRepresentativePhotoRequired;

  /// No description provided for @eventPlanMinLength.
  ///
  /// In en, this message translates to:
  /// **'Describe your event plan in at least 50 characters.'**
  String get eventPlanMinLength;

  /// No description provided for @chooseEventCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one planned event category.'**
  String get chooseEventCategory;

  /// No description provided for @acceptOrganizerStandards.
  ///
  /// In en, this message translates to:
  /// **'Accept the Khair Organizer Standards to continue.'**
  String get acceptOrganizerStandards;

  /// No description provided for @organizerApplicationSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not submit your application.'**
  String get organizerApplicationSubmitFailed;

  /// No description provided for @imageUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Upload complete. Your image remains private until approval.'**
  String get imageUploadComplete;

  /// No description provided for @imageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed.'**
  String get imageUploadFailed;

  /// No description provided for @documentUploadComplete.
  ///
  /// In en, this message translates to:
  /// **'Verification document uploaded securely.'**
  String get documentUploadComplete;

  /// No description provided for @documentUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Document upload failed.'**
  String get documentUploadFailed;

  /// No description provided for @documentTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This document is larger than 10 MB.'**
  String get documentTooLarge;

  /// No description provided for @documentUploadFailedSafe.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t upload this document. Your application is safe.'**
  String get documentUploadFailedSafe;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get sessionExpired;

  /// No description provided for @organizationRegistration.
  ///
  /// In en, this message translates to:
  /// **'Organization registration'**
  String get organizationRegistration;

  /// No description provided for @charityRegistration.
  ///
  /// In en, this message translates to:
  /// **'Charity registration'**
  String get charityRegistration;

  /// No description provided for @communityDocument.
  ///
  /// In en, this message translates to:
  /// **'Community document'**
  String get communityDocument;

  /// No description provided for @schoolCompanyDocument.
  ///
  /// In en, this message translates to:
  /// **'School or company document'**
  String get schoolCompanyDocument;

  /// No description provided for @otherSupportingDocument.
  ///
  /// In en, this message translates to:
  /// **'Other supporting document'**
  String get otherSupportingDocument;

  /// No description provided for @addHttpsLink.
  ///
  /// In en, this message translates to:
  /// **'Add a complete https:// link.'**
  String get addHttpsLink;

  /// No description provided for @addEvidenceUrlOrNote.
  ///
  /// In en, this message translates to:
  /// **'Add a URL or a short note for this evidence.'**
  String get addEvidenceUrlOrNote;

  /// No description provided for @addHttpsEvidenceUrl.
  ///
  /// In en, this message translates to:
  /// **'Add a complete https:// evidence URL.'**
  String get addHttpsEvidenceUrl;

  /// No description provided for @savingDraft.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get savingDraft;

  /// No description provided for @draftSavedSecurely.
  ///
  /// In en, this message translates to:
  /// **'Draft saved securely'**
  String get draftSavedSecurely;

  /// No description provided for @submitForReview.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get submitForReview;

  /// No description provided for @tellUsAboutYou.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you'**
  String get tellUsAboutYou;

  /// No description provided for @buildTrust.
  ///
  /// In en, this message translates to:
  /// **'Build trust'**
  String get buildTrust;

  /// No description provided for @reviewYourApplication.
  ///
  /// In en, this message translates to:
  /// **'Review your application'**
  String get reviewYourApplication;

  /// No description provided for @tellUsAboutYouDescription.
  ///
  /// In en, this message translates to:
  /// **'Set up the public identity people will see on Khair.'**
  String get tellUsAboutYouDescription;

  /// No description provided for @buildTrustDescription.
  ///
  /// In en, this message translates to:
  /// **'Add the image and optional evidence that help us verify your application.'**
  String get buildTrustDescription;

  /// No description provided for @yourEventsDescription.
  ///
  /// In en, this message translates to:
  /// **'Show the kinds of safe, meaningful events you plan to host.'**
  String get yourEventsDescription;

  /// No description provided for @reviewYourApplicationDescription.
  ///
  /// In en, this message translates to:
  /// **'Confirm the details before sending your application to the Khair review team.'**
  String get reviewYourApplicationDescription;

  /// No description provided for @organizerType.
  ///
  /// In en, this message translates to:
  /// **'Organizer type'**
  String get organizerType;

  /// No description provided for @company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get company;

  /// No description provided for @school.
  ///
  /// In en, this message translates to:
  /// **'School'**
  String get school;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @publicOrganizerName.
  ///
  /// In en, this message translates to:
  /// **'Public organizer name'**
  String get publicOrganizerName;

  /// No description provided for @responsibleRepresentative.
  ///
  /// In en, this message translates to:
  /// **'Responsible representative'**
  String get responsibleRepresentative;

  /// No description provided for @verifiedAccountEmail.
  ///
  /// In en, this message translates to:
  /// **'Verified account email'**
  String get verifiedAccountEmail;

  /// No description provided for @phoneInternationalOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional, international format)'**
  String get phoneInternationalOptional;

  /// No description provided for @aboutYourOrganization.
  ///
  /// In en, this message translates to:
  /// **'About your organization'**
  String get aboutYourOrganization;

  /// No description provided for @aboutYourOrganizationHint.
  ///
  /// In en, this message translates to:
  /// **'Who are you, what is your purpose, and why should the Khair community trust your events?'**
  String get aboutYourOrganizationHint;

  /// No description provided for @eventPlanDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe your event ideas, frequency, safety plan, and the value for your community.'**
  String get eventPlanDescriptionHint;

  /// No description provided for @lecture.
  ///
  /// In en, this message translates to:
  /// **'Lecture'**
  String get lecture;

  /// No description provided for @workshop.
  ///
  /// In en, this message translates to:
  /// **'Workshop'**
  String get workshop;

  /// No description provided for @conference.
  ///
  /// In en, this message translates to:
  /// **'Conference'**
  String get conference;

  /// No description provided for @technology.
  ///
  /// In en, this message translates to:
  /// **'Technology'**
  String get technology;

  /// No description provided for @education.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get education;

  /// No description provided for @socialGathering.
  ///
  /// In en, this message translates to:
  /// **'Social gathering'**
  String get socialGathering;

  /// No description provided for @everyone.
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get everyone;

  /// No description provided for @families.
  ///
  /// In en, this message translates to:
  /// **'Families'**
  String get families;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get students;

  /// No description provided for @professionals.
  ///
  /// In en, this message translates to:
  /// **'Professionals'**
  String get professionals;

  /// No description provided for @men.
  ///
  /// In en, this message translates to:
  /// **'Men'**
  String get men;

  /// No description provided for @women.
  ///
  /// In en, this message translates to:
  /// **'Women'**
  String get women;

  /// No description provided for @secureDocument.
  ///
  /// In en, this message translates to:
  /// **'Secure document'**
  String get secureDocument;

  /// No description provided for @organizerRuleAccurate.
  ///
  /// In en, this message translates to:
  /// **'Publish accurate, complete event information and update attendees promptly when plans change.'**
  String get organizerRuleAccurate;

  /// No description provided for @organizerRuleSafe.
  ///
  /// In en, this message translates to:
  /// **'Create safe, respectful gatherings. Do not discriminate, harass, mislead, or facilitate harmful activity.'**
  String get organizerRuleSafe;

  /// No description provided for @organizerRuleRights.
  ///
  /// In en, this message translates to:
  /// **'Use only images, names, documents, and links you are entitled to share.'**
  String get organizerRuleRights;

  /// No description provided for @organizerRulePrivacy.
  ///
  /// In en, this message translates to:
  /// **'Protect attendee privacy and never use Khair data for unsolicited contact or unrelated marketing.'**
  String get organizerRulePrivacy;

  /// No description provided for @organizerRuleLaw.
  ///
  /// In en, this message translates to:
  /// **'Follow local law, venue requirements, and Khair content and community policies.'**
  String get organizerRuleLaw;

  /// No description provided for @organizerRuleReview.
  ///
  /// In en, this message translates to:
  /// **'Cooperate with review requests and keep your organizer profile and verification material current.'**
  String get organizerRuleReview;

  /// No description provided for @publicProfile.
  ///
  /// In en, this message translates to:
  /// **'Public profile'**
  String get publicProfile;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @representative.
  ///
  /// In en, this message translates to:
  /// **'Representative'**
  String get representative;

  /// No description provided for @contactEmail.
  ///
  /// In en, this message translates to:
  /// **'Contact email'**
  String get contactEmail;

  /// No description provided for @trustMaterial.
  ///
  /// In en, this message translates to:
  /// **'Trust material'**
  String get trustMaterial;

  /// No description provided for @publicImage.
  ///
  /// In en, this message translates to:
  /// **'Public image'**
  String get publicImage;

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missing;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'added'**
  String get added;

  /// No description provided for @evidence.
  ///
  /// In en, this message translates to:
  /// **'Evidence'**
  String get evidence;

  /// No description provided for @privateDocuments.
  ///
  /// In en, this message translates to:
  /// **'Private documents'**
  String get privateDocuments;

  /// No description provided for @itemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} {label}'**
  String itemsCount(int count, String label);

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @audience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get audience;

  /// No description provided for @standards.
  ///
  /// In en, this message translates to:
  /// **'Standards'**
  String get standards;

  /// No description provided for @accepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get accepted;

  /// No description provided for @notAccepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted'**
  String get notAccepted;

  /// No description provided for @reviewNotice.
  ///
  /// In en, this message translates to:
  /// **'A Khair admin will review this application. You will receive an in-app notification, push notification when available, and an email after a decision.'**
  String get reviewNotice;

  /// No description provided for @organizerApproved.
  ///
  /// In en, this message translates to:
  /// **'You are approved to organize'**
  String get organizerApproved;

  /// No description provided for @applicationNeedsChanges.
  ///
  /// In en, this message translates to:
  /// **'Your application needs changes'**
  String get applicationNeedsChanges;

  /// No description provided for @applicationNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Your application was not approved'**
  String get applicationNotApproved;

  /// No description provided for @organizerAccountSuspended.
  ///
  /// In en, this message translates to:
  /// **'Your organizer account is suspended'**
  String get organizerAccountSuspended;

  /// No description provided for @applicationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Your application is incomplete'**
  String get applicationIncomplete;

  /// No description provided for @applicationUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Your application is under review'**
  String get applicationUnderReview;

  /// No description provided for @organizerToolsAvailable.
  ///
  /// In en, this message translates to:
  /// **'Organizer tools are now available on your account.'**
  String get organizerToolsAvailable;

  /// No description provided for @reviewFeedbackAndResubmit.
  ///
  /// In en, this message translates to:
  /// **'Review the feedback, update your draft, and submit again when ready.'**
  String get reviewFeedbackAndResubmit;

  /// No description provided for @applicationClosedContactSupport.
  ///
  /// In en, this message translates to:
  /// **'This application is closed. Contact Khair support if you need help with the decision.'**
  String get applicationClosedContactSupport;

  /// No description provided for @contactSupportForMoreInformation.
  ///
  /// In en, this message translates to:
  /// **'Contact Khair support for more information.'**
  String get contactSupportForMoreInformation;

  /// No description provided for @completeApplicationToOrganize.
  ///
  /// In en, this message translates to:
  /// **'Complete and submit your application to start organizing events.'**
  String get completeApplicationToOrganize;

  /// No description provided for @applicationWithReviewTeam.
  ///
  /// In en, this message translates to:
  /// **'Your details, evidence, and event plan are securely with the Khair review team.'**
  String get applicationWithReviewTeam;

  /// No description provided for @reasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason:'**
  String get reasonLabel;

  /// No description provided for @openOrganizerHub.
  ///
  /// In en, this message translates to:
  /// **'Open organizer hub'**
  String get openOrganizerHub;

  /// No description provided for @updateApplication.
  ///
  /// In en, this message translates to:
  /// **'Update application'**
  String get updateApplication;

  /// No description provided for @backToDiscover.
  ///
  /// In en, this message translates to:
  /// **'Back to discover'**
  String get backToDiscover;

  /// No description provided for @refreshStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh status'**
  String get refreshStatus;

  /// No description provided for @uploadedSecurelyTapToReplace.
  ///
  /// In en, this message translates to:
  /// **'Uploaded securely. Tap to replace.'**
  String get uploadedSecurelyTapToReplace;

  /// No description provided for @replaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get replaceImage;

  /// No description provided for @chooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose image'**
  String get chooseImage;

  /// No description provided for @httpsLinkHint.
  ///
  /// In en, this message translates to:
  /// **'https://?'**
  String get httpsLinkHint;

  /// No description provided for @evidenceUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Evidence URL (optional)'**
  String get evidenceUrlOptional;

  /// No description provided for @shortNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Short note (optional)'**
  String get shortNoteOptional;

  /// No description provided for @instagram.
  ///
  /// In en, this message translates to:
  /// **'Instagram'**
  String get instagram;

  /// No description provided for @facebook.
  ///
  /// In en, this message translates to:
  /// **'Facebook'**
  String get facebook;

  /// No description provided for @linkedin.
  ///
  /// In en, this message translates to:
  /// **'LinkedIn'**
  String get linkedin;

  /// No description provided for @officialWebsite.
  ///
  /// In en, this message translates to:
  /// **'Official website'**
  String get officialWebsite;

  /// No description provided for @verifiedSocial.
  ///
  /// In en, this message translates to:
  /// **'Verified social account'**
  String get verifiedSocial;

  /// No description provided for @notProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get notProvided;

  /// No description provided for @optionalButUsefulForFasterReview.
  ///
  /// In en, this message translates to:
  /// **'Optional, but useful for a faster review. Only add official public links.'**
  String get optionalButUsefulForFasterReview;

  /// No description provided for @whatEventsWillYouHost.
  ///
  /// In en, this message translates to:
  /// **'What events will you host?'**
  String get whatEventsWillYouHost;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @passwordWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordWeak;

  /// No description provided for @passwordGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordGood;

  /// No description provided for @passwordStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrong;

  /// No description provided for @postEvent.
  ///
  /// In en, this message translates to:
  /// **'Post event'**
  String get postEvent;

  /// No description provided for @postingEvent.
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get postingEvent;

  /// No description provided for @joined.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get joined;

  /// No description provided for @eventFallback.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventFallback;

  /// No description provided for @dateToBeAnnounced.
  ///
  /// In en, this message translates to:
  /// **'Date to be announced'**
  String get dateToBeAnnounced;

  /// No description provided for @locationToBeAnnounced.
  ///
  /// In en, this message translates to:
  /// **'Location to be announced'**
  String get locationToBeAnnounced;

  /// No description provided for @notificationSentTo.
  ///
  /// In en, this message translates to:
  /// **'Notification sent to {count} user(s)'**
  String notificationSentTo(int count);

  /// No description provided for @failedToSendNotification.
  ///
  /// In en, this message translates to:
  /// **'Failed to send notification'**
  String get failedToSendNotification;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @editQuote.
  ///
  /// In en, this message translates to:
  /// **'Edit Quote'**
  String get editQuote;

  /// No description provided for @addQuote.
  ///
  /// In en, this message translates to:
  /// **'Add Quote'**
  String get addQuote;

  /// No description provided for @quoteUpdated.
  ///
  /// In en, this message translates to:
  /// **'Quote updated'**
  String get quoteUpdated;

  /// No description provided for @quoteAdded.
  ///
  /// In en, this message translates to:
  /// **'Quote added'**
  String get quoteAdded;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @joinedEventsLabel.
  ///
  /// In en, this message translates to:
  /// **'Joined events'**
  String get joinedEventsLabel;

  /// No description provided for @personalDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get personalDetails;

  /// No description provided for @communityEvent.
  ///
  /// In en, this message translates to:
  /// **'Community event'**
  String get communityEvent;

  /// No description provided for @paidEvent.
  ///
  /// In en, this message translates to:
  /// **'Paid Event'**
  String get paidEvent;

  /// No description provided for @noCostToAttend.
  ///
  /// In en, this message translates to:
  /// **'No cost to attend'**
  String get noCostToAttend;

  /// No description provided for @removeFromSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove from saved'**
  String get removeFromSaved;

  /// No description provided for @registrationClosed.
  ///
  /// In en, this message translates to:
  /// **'Registration closed'**
  String get registrationClosed;

  /// No description provided for @registrationCloses.
  ///
  /// In en, this message translates to:
  /// **'Registration closes {date}'**
  String registrationCloses(Object date);

  /// No description provided for @youMayAlsoLike.
  ///
  /// In en, this message translates to:
  /// **'You may also like'**
  String get youMayAlsoLike;

  /// No description provided for @memberSinceDate.
  ///
  /// In en, this message translates to:
  /// **'{label} {date}'**
  String memberSinceDate(Object label, Object date);

  /// No description provided for @beFirstToJoin.
  ///
  /// In en, this message translates to:
  /// **'Be the first to join'**
  String get beFirstToJoin;

  /// No description provided for @meetingAccessAfterJoining.
  ///
  /// In en, this message translates to:
  /// **'Meeting access after joining'**
  String get meetingAccessAfterJoining;

  /// No description provided for @savedLabel.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedLabel;

  /// No description provided for @imageEmpty.
  ///
  /// In en, this message translates to:
  /// **'The selected image is empty. Choose another image.'**
  String get imageEmpty;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This image is larger than 5 MB.'**
  String get imageTooLarge;

  /// No description provided for @imageFormatUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This image format isn\'t supported. Use JPG, PNG, or WebP.'**
  String get imageFormatUnsupported;

  /// No description provided for @imageInvalid.
  ///
  /// In en, this message translates to:
  /// **'This image could not be read. Choose another image.'**
  String get imageInvalid;

  /// No description provided for @imageUploadOfflineSafe.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Your image is safe — tap Retry.'**
  String get imageUploadOfflineSafe;

  /// No description provided for @imageUploadTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The upload took too long. Tap Retry.'**
  String get imageUploadTimedOut;

  /// No description provided for @imageUploadFailedSafe.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t upload this image. Your other information is safe.'**
  String get imageUploadFailedSafe;

  /// No description provided for @draftSaveOfflineSafe.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t sync your changes. They\'re saved on this device.'**
  String get draftSaveOfflineSafe;

  /// No description provided for @draftSaveFailedSafe.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t save your latest changes. They\'re saved on this device.'**
  String get draftSaveFailedSafe;

  /// No description provided for @draftChangesNotSaved.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get draftChangesNotSaved;

  /// No description provided for @uploadInProgress.
  ///
  /// In en, this message translates to:
  /// **'Please wait while the image finishes uploading.'**
  String get uploadInProgress;

  /// No description provided for @imagePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing image…'**
  String get imagePreparing;

  /// No description provided for @imageUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading securely…'**
  String get imageUploading;

  /// No description provided for @imageUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get imageUploaded;

  /// No description provided for @registrationRequirementsTitle.
  ///
  /// In en, this message translates to:
  /// **'Registration & Requirements'**
  String get registrationRequirementsTitle;

  /// No description provided for @noRegistrationRequired.
  ///
  /// In en, this message translates to:
  /// **'No registration required'**
  String get noRegistrationRequired;

  /// No description provided for @khairRegistrationRequired.
  ///
  /// In en, this message translates to:
  /// **'Registration required on Khair'**
  String get khairRegistrationRequired;

  /// No description provided for @externalRegistrationRequired.
  ///
  /// In en, this message translates to:
  /// **'Registration required on an external platform'**
  String get externalRegistrationRequired;

  /// No description provided for @bothRegistrationsRequired.
  ///
  /// In en, this message translates to:
  /// **'Registration required both on Khair and an external platform'**
  String get bothRegistrationsRequired;

  /// No description provided for @externalPlatformName.
  ///
  /// In en, this message translates to:
  /// **'External platform name'**
  String get externalPlatformName;

  /// No description provided for @externalRegistrationUrl.
  ///
  /// In en, this message translates to:
  /// **'External registration URL'**
  String get externalRegistrationUrl;

  /// No description provided for @externalRegistrationInstructions.
  ///
  /// In en, this message translates to:
  /// **'Registration instructions (optional)'**
  String get externalRegistrationInstructions;

  /// No description provided for @testLink.
  ///
  /// In en, this message translates to:
  /// **'Test link'**
  String get testLink;

  /// No description provided for @completeRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete Registration'**
  String get completeRegistration;

  /// No description provided for @externalRegistrationWarning.
  ///
  /// In en, this message translates to:
  /// **'Registration must be completed on an external platform.'**
  String get externalRegistrationWarning;

  /// No description provided for @leaveKhairRegistration.
  ///
  /// In en, this message translates to:
  /// **'You are leaving Khair to complete registration on an external platform.'**
  String get leaveKhairRegistration;

  /// No description provided for @continueToRegistration.
  ///
  /// In en, this message translates to:
  /// **'Continue to registration'**
  String get continueToRegistration;

  /// No description provided for @khairDoesNotManageExternalRegistration.
  ///
  /// In en, this message translates to:
  /// **'Khair does not verify or manage this external registration process.'**
  String get khairDoesNotManageExternalRegistration;
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
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

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
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
