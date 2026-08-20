import 'dart:async';

import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/crash/crash_reporter.dart';
import 'core/di/injection.dart';
import 'core/locale/locale_bloc.dart';
import 'core/network/connectivity_service.dart';
import 'core/push/local_notification_service_web.dart'
    if (dart.library.io) 'core/push/local_notification_service.dart';
import 'core/push/push_notification_service_platform.dart';
import 'core/router/app_router.dart';
import 'core/services/websocket_service.dart';
import 'core/theme/app_theme_builder.dart';
import 'core/theme/theme_bloc.dart';
import 'core/widgets/offline_indicator.dart';
import 'features/location/presentation/bloc/location_bloc.dart';
import 'features/ai/presentation/bloc/ai_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/notifications/presentation/bloc/notification_bloc.dart';
import 'l10n/generated/app_localizations.dart';

void main() {
  // Platform channels used by Firebase Messaging require Flutter bindings.
  // Register the background handler before the app starts, but only after the
  // binding exists; otherwise Android release builds remain on the splash
  // screen after an unhandled platform-channel exception.
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }
  CrashReporter.init(
    sentryDsn: const String.fromEnvironment('SENTRY_DSN'),
    appRunner: () async {
      await initializeDateFormatting();

      // Firebase & push notifications are only configured for mobile
      if (!kIsWeb) {
        await Firebase.initializeApp();
      }

      await configureDependencies();
      ConnectivityService.instance.initialize();

      // Push notifications only on mobile (uses dart:io + Firebase which aren't configured for web)
      if (!kIsWeb) {
        // Init native channels and keep taps queued until auth + GoRouter are
        // ready. Permission/token registration happens only after sign-in.
        await LocalNotificationService.instance.init();
        LocalNotificationService.instance.setOnNotificationTap((data) {
          PushNotificationService.instance.handleLocalNotificationTap(data);
        });
        await PushNotificationService.instance.initialize();
      }

      runApp(KhairApp());
    },
  );
}

class KhairApp extends StatelessWidget {
  const KhairApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(
          value: getIt<AuthBloc>()..add(CheckAuthStatus()),
        ),
        BlocProvider(
          create: (_) => LocaleBloc()..add(LoadSavedLocale()),
        ),
        BlocProvider(
          // Location is useful, but it must not ask for GPS permission every
          // time Khair opens. The discovery header offers an explicit action.
          create: (_) => getIt<LocationBloc>()..add(LoadCachedLocationEvent()),
        ),
        BlocProvider(
          create: (_) => ThemeBloc(),
        ),
        BlocProvider(
          create: (_) => getIt<AiBloc>(),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, authState) {
          if (authState.isAuthenticated) {
            WebSocketService.instance.connect();
            getIt<NotificationBloc>().add(
              const NotificationSessionChanged(true),
            );
          } else {
            WebSocketService.instance.disconnect();
            getIt<NotificationBloc>().add(
              const NotificationSessionChanged(false),
            );
          }
          if (!kIsWeb) {
            unawaited(
              PushNotificationService.instance
                  .onAuthenticationStateChanged(authState.isAuthenticated),
            );
          }
        },
        child: BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            return BlocBuilder<LocaleBloc, LocaleState>(
              builder: (context, localeState) {
                final textDirection = localeState.locale.languageCode == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr;

                return MaterialApp.router(
                  onGenerateTitle: (context) => context.l10n.appTitle,
                  debugShowCheckedModeBanner: false,
                  theme: buildAppTheme(
                    locale: localeState.locale,
                    brightness: Brightness.light,
                  ),
                  darkTheme: buildAppTheme(
                    locale: localeState.locale,
                    brightness: Brightness.dark,
                  ),
                  themeMode: themeState.themeMode,
                  routerConfig: appRouter,
                  locale: localeState.locale,
                  localeResolutionCallback: (locale, supportedLocales) {
                    if (locale == null) return Locale('en');
                    for (final supported in supportedLocales) {
                      if (supported.languageCode == locale.languageCode) {
                        return supported;
                      }
                    }
                    return Locale('en');
                  },
                  supportedLocales: AppLocalizations.supportedLocales,
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  builder: (context, child) {
                    return Directionality(
                      textDirection: textDirection,
                      child: OfflineIndicator(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
