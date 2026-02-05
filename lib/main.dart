import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'config/app_config.dart';
import 'providers/auth_provider.dart';
import 'providers/room_provider.dart';
import 'providers/reservation_provider.dart';
import 'screens/welcome_screen.dart';
import 'services/serverpod_client.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('nl', null);

  // Initialiseer Serverpod client met configuratie uit AppConfig
  await ServerpodClientService.instance.initialize(
    host: AppConfig.serverHost,
    port: AppConfig.serverPort,
    useHttps: AppConfig.useHttps,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => ReservationProvider()),
      ],
      child: MaterialApp(
        title: 'Roosterapp',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const WelcomeScreen(),
      ),
    );
  }
}
