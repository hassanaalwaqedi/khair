/// Environment configuration for Khair app
/// Supports dev, staging, and production environments
library;

enum Environment {
  development,
  staging,
  production,
}

class EnvConfig {
  final Environment environment;
  final String apiBaseUrl;
  final bool enableLogging;
  final bool enableCrashReporting;
  final bool enablePerformanceMonitoring;
  final bool showDebugBanner;
  final int connectionTimeoutMs;
  final int receiveTimeoutMs;

  const EnvConfig._({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableLogging,
    required this.enableCrashReporting,
    required this.enablePerformanceMonitoring,
    required this.showDebugBanner,
    required this.connectionTimeoutMs,
    required this.receiveTimeoutMs,
  });

  /// Development configuration
  /// NOTE for mobile testing:
  /// - Android emulator: use 'http://10.0.2.2:8080/api/v1'
  /// - iOS simulator: 'http://localhost:8080/api/v1' works
  /// - Physical device: use your PC's local IP (e.g., 'http://192.168.1.x:8080/api/v1')
  static const development = EnvConfig._(
    environment: Environment.development,
    apiBaseUrl: 'http://10.0.2.2:8080/api/v1',
    enableLogging: true,
    enableCrashReporting: false,
    enablePerformanceMonitoring: false,
    showDebugBanner: true,
    connectionTimeoutMs: 30000,
    receiveTimeoutMs: 30000,
  );

  /// Staging configuration
  static const staging = EnvConfig._(
    environment: Environment.staging,
    apiBaseUrl: 'https://staging-api.khair.app/api/v1',
    enableLogging: true,
    enableCrashReporting: true,
    enablePerformanceMonitoring: true,
    showDebugBanner: true,
    connectionTimeoutMs: 15000,
    receiveTimeoutMs: 15000,
  );

  /// Production configuration
  static const production = EnvConfig._(
    environment: Environment.production,
    apiBaseUrl: 'https://api.khair.app/api/v1',
    enableLogging: false,
    enableCrashReporting: true,
    enablePerformanceMonitoring: true,
    showDebugBanner: false,
    connectionTimeoutMs: 10000,
    receiveTimeoutMs: 10000,
  );

  /// Get config from environment name
  static EnvConfig fromString(String env) {
    switch (env.toLowerCase()) {
      case 'production':
      case 'prod':
        return production;
      case 'staging':
      case 'stage':
        return staging;
      default:
        return development;
    }
  }

  /// Check if running in production
  bool get isProduction => environment == Environment.production;

  /// Check if running in development
  bool get isDevelopment => environment == Environment.development;

  /// Check if debug features should be enabled
  bool get isDebugMode => environment != Environment.production;
}

/// Current app configuration - set at app startup
class AppConfig {
  static EnvConfig _current = EnvConfig.development;

  /// Initialize with environment
  static void initialize(String environment) {
    _current = EnvConfig.fromString(environment);
  }

  /// Get current configuration
  static EnvConfig get current => _current;

  /// Check if production
  static bool get isProduction => _current.isProduction;

  /// Check if debug mode
  static bool get isDebugMode => _current.isDebugMode;

  /// API base URL
  static String get apiBaseUrl => _current.apiBaseUrl;
}
