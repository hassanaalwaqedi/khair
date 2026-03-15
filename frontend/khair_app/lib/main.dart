import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/crash/crash_reporter.dart';
import 'core/di/injection.dart';
import 'core/locale/locale_bloc.dart';
import 'core/network/connectivity_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme_builder.dart';
import 'core/theme/theme_bloc.dart';
import 'core/widgets/offline_indicator.dart';
import 'features/location/presentation/bloc/location_bloc.dart';
import 'features/ai/presentation/bloc/ai_bloc.dart';
import 'features/spiritual_quotes/presentation/widgets/spiritual_quote_startup_modal.dart';
import 'core/push/push_notification_service.dart';
import 'l10n/generated/app_localizations.dart';

void main() {
  CrashReporter.init(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp();

    await configureDependencies();
    ConnectivityService.instance.initialize();

    // Initialize push notifications (requests permission + registers token)
    await PushNotificationService.instance.initialize();

    runApp(const KhairApp());
  });
}

class KhairApp extends StatelessWidget {
  const KhairApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => LocaleBloc()..add(const LoadSavedLocale()),
        ),
        BlocProvider(
          create: (_) => getIt<LocationBloc>()..add(ResolveLocationEvent()),
        ),
        BlocProvider(
          create: (_) => ThemeBloc(),
        ),
        BlocProvider(
          create: (_) => getIt<AiBloc>(),
        ),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return BlocBuilder<LocaleBloc, LocaleState>(
            builder: (context, localeState) {
              final textDirection = localeState.locale.languageCode == 'ar'
                  ? TextDirection.rtl
                  : TextDirection.ltr;

              return MaterialApp.router(
                title: 'Khair',
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
                  if (locale == null) return const Locale('en');
                  for (final supported in supportedLocales) {
                    if (supported.languageCode == locale.languageCode) {
                      return supported;
                    }
                  }
                  return const Locale('en');
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
                    child: SpiritualQuoteStartupModal(
                      child: OfflineIndicator(
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
