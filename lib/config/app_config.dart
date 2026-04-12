/// Applicatie configuratie
///
/// Selecteer omgeving bij build via --dart-define=ENV=staging of ENV=production
/// Standaard (geen dart-define): productie
class AppConfig {
  // Prevent instantiation
  AppConfig._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'production');

  // ==========================================================================
  // SERVER CONFIGURATIE (automatisch op basis van ENV)
  // ==========================================================================

  static String get serverHost {
    if (_env == 'staging') return staging.host;
    if (_env == 'local') return localDev.host;
    return production.host;
  }

  static int get serverPort {
    if (_env == 'staging') return staging.port;
    if (_env == 'local') return localDev.port;
    return production.port;
  }

  static bool get useHttps {
    if (_env == 'staging') return staging.useHttps;
    if (_env == 'local') return localDev.useHttps;
    return production.useHttps;
  }

  static String get environment => _env;

  // ==========================================================================
  // APP INFORMATIE
  // ==========================================================================

  /// App naam zoals getoond in de UI
  static const String appName = 'Roosterapp';

  /// App versie
  static const String appVersion = '1.0.0';

  // ==========================================================================
  // CONTACT INFORMATIE
  // ==========================================================================

  /// Telefoonnummer voor support (wachtwoord vergeten, etc.)
  static const String supportPhoneNumber = '+31 6 4246 5338';

  /// Telefoonnummer zonder spaties (voor tel: links)
  static const String supportPhoneNumberRaw = '+31642465338';

  // ==========================================================================
  // OMGEVING PRESETS
  // ==========================================================================

  /// Lokale development
  static const ServerConfig localDev = ServerConfig(
    host: 'localhost',
    port: 8080,
    useHttps: false,
  );

  /// Staging server
  static const ServerConfig staging = ServerConfig(
    host: 'staging.4ub2b.com',
    port: 443,
    useHttps: true,
  );

  /// Productie
  static const ServerConfig production = ServerConfig(
    host: 'rooster.4ub2b.com',
    port: 443,
    useHttps: true,
  );
}

/// Helper class voor server configuraties
class ServerConfig {
  final String host;
  final int port;
  final bool useHttps;

  const ServerConfig({
    required this.host,
    required this.port,
    required this.useHttps,
  });
}
