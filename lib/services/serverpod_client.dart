import 'package:rooster_client/rooster_client.dart';
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple authentication key manager using SharedPreferences
class SimpleAuthKeyManager extends AuthenticationKeyManager {
  String? _authKey;

  @override
  Future<String?> get() async {
    if (_authKey != null) return _authKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      _authKey = prefs.getString('serverpod_auth_key');
    } catch (e) {
      // SharedPreferences not available
    }
    return _authKey;
  }

  @override
  Future<void> put(String key) async {
    _authKey = key;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('serverpod_auth_key', key);
    } catch (e) {
      // SharedPreferences not available
    }
  }

  @override
  Future<void> remove() async {
    _authKey = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('serverpod_auth_key');
    } catch (e) {
      // SharedPreferences not available
    }
  }
}

/// Singleton service voor Serverpod client verbinding
class ServerpodClientService {
  static ServerpodClientService? _instance;
  static Client? _client;

  ServerpodClientService._();

  static ServerpodClientService get instance {
    _instance ??= ServerpodClientService._();
    return _instance!;
  }

  /// Initialiseer de client met de server URL
  Future<void> initialize({
    String host = 'localhost',
    int port = 8080,
    bool useHttps = false,
  }) async {
    final protocol = useHttps ? 'https' : 'http';
    // Laat standaard poorten (80 voor HTTP, 443 voor HTTPS) weg uit de URL
    final isDefaultPort = (useHttps && port == 443) || (!useHttps && port == 80);
    final url = isDefaultPort ? '$protocol://$host/' : '$protocol://$host:$port/';

    _client = Client(
      url,
      authenticationKeyManager: SimpleAuthKeyManager(),
    )..connectivityMonitor = FlutterConnectivityMonitor();

    // Test de verbinding
    try {
      // We kunnen een simpele test doen door rooms op te halen
      await _client!.room.getRooms();
    } catch (e) {
      // Server niet bereikbaar, maar we gaan door
      // De client kan later opnieuw proberen
    }
  }

  /// Haal de client op
  Client get client {
    if (_client == null) {
      throw Exception('ServerpodClientService niet geïnitialiseerd. Roep initialize() aan.');
    }
    return _client!;
  }

  /// Check of client is geïnitialiseerd
  bool get isInitialized => _client != null;

  /// Sluit de verbinding
  void dispose() {
    _client?.close();
    _client = null;
  }
}

/// Shortcut om de client te krijgen
Client get serverpodClient => ServerpodClientService.instance.client;
