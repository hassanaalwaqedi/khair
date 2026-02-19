import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection.dart';
import 'core/locale/locale_bloc.dart';
import 'core/network/connectivity_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/khair_theme.dart';
import 'core/theme/theme_bloc.dart';
import 'core/widgets/offline_indicator.dart';
import 'features/location/presentation/bloc/location_bloc.dart';
import 'features/ai/presentation/bloc/ai_bloc.dart';
import 'l10n/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await configureDependencies();
  ConnectivityService.instance.initialize();
  
  runApp(const KhairApp());
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
              return MaterialApp.router(
                title: 'Khair',
                debugShowCheckedModeBanner: false,
                theme: KhairTheme.lightTheme,
                darkTheme: KhairTheme.darkTheme,
                themeMode: themeState.themeMode,
                routerConfig: appRouter,
                locale: localeState.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                builder: (context, child) {
                  return OfflineIndicator(child: child ?? const SizedBox.shrink());
                },
              );
            },
          );
        },
      ),
    );
  }
}

