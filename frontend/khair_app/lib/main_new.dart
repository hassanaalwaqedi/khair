import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/theme/khair_theme.dart';
import 'core/navigation/app_navigation.dart';
import 'core/config/env_config.dart';
import 'core/di/injection.dart';

/// Alternative main entry point using new design system
/// To use: flutter run -t lib/main_new.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment
  const environment = String.fromEnvironment('ENV', defaultValue: 'development');
  AppConfig.initialize(environment);

  // Initialize dependency injection
  await configureDependencies();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: KhairColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const KhairAppNew());
}

class KhairAppNew extends StatelessWidget {
  const KhairAppNew({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Khair',
      debugShowCheckedModeBanner: !AppConfig.isProduction,
      theme: KhairTheme.lightTheme,
      routerConfig: AppNavigation.router,
      builder: (context, child) {
        return MediaQuery(
          // Prevent text scaling from breaking layout
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.2),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
