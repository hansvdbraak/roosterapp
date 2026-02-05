/// Applicatie configuratie
///
/// Wijzig deze waarden om de app te configureren voor development of productie.
class AppConfig {
  // Prevent instantiation
  AppConfig._();

  // ==========================================================================
  // SERVER CONFIGURATIE
  // ==========================================================================

  /// Server hostname of IP-adres
  ///
  /// Voorbeelden:
  /// - Development lokaal: 'localhost' of '127.0.0.1'
  /// - Development netwerk: '192.168.1.100'
  /// - Productie: 'api.4ub2b.com'
  static const String serverHost = 'localhost';

  /// Server poort
  ///
  /// Standaard poorten:
  /// - Development: 8080
  /// - Productie HTTP: 80
  /// - Productie HTTPS: 443
  static const int serverPort = 8080;

  /// Gebruik HTTPS voor verbinding
  ///
  /// - Development: false (tenzij je lokaal SSL hebt)
  /// - Productie: true
  static const bool useHttps = false;

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
  // DEVELOPMENT PRESETS
  // ==========================================================================

  /// Snelle configuratie voor lokale development
  static const ServerConfig localDev = ServerConfig(
    host: 'localhost',
    port: 8080,
    useHttps: false,
  );

  /// Snelle configuratie voor development op netwerk
  static const ServerConfig networkDev = ServerConfig(
    host: '192.168.1.100', // Pas aan naar je server IP
    port: 8080,
    useHttps: false,
  );

  /// Snelle configuratie voor productie
  static const ServerConfig production = ServerConfig(
    host: 'api.4ub2b.com',
    port: 443,
    useHttps: true,
  );
}

/// Helper class voor development configuraties
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
