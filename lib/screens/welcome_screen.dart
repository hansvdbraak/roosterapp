import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../config/version.dart';
import 'room_list_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadLastUsername();
  }

  Future<void> _loadLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUsername = prefs.getString('last_username');
    if (lastUsername != null && lastUsername.isNotEmpty && mounted) {
      setState(() => _usernameController.text = lastUsername);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.trim().isEmpty) {
      _showError('Voer je gebruikersnaam in');
      return;
    }
    if (_passwordController.text.isEmpty) {
      _showError('Voer je wachtwoord in');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().loginWithUsername(
            username: _usernameController.text,
            password: _passwordController.text,
          );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_username', _usernameController.text.trim());
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoomListScreen()),
        );
      }
    } catch (e) {
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      // Als gebruikersnaam onbekend is, ga naar registreren
      if (errorMsg == 'UNKNOWN_USER') {
        if (mounted) {
          _showUnknownUserDialog();
        }
      } else {
        _showError(errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showUnknownUserDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gebruiker onbekend'),
        content: Text(
          'De gebruikersnaam "${_usernameController.text}" is niet bekend. Wil je een nieuw account aanmaken?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RegisterScreen(
                    initialName: _usernameController.text,
                  ),
                ),
              );
            },
            child: const Text('Registreren'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Geblurrde achtergrond
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Image.network(
              '/assets/images/trefpunt_duurzaam.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.blueGrey[100]),
            ),
          ),
          // Semi-transparante overlay voor leesbaarheid
          Container(color: Colors.white.withValues(alpha: 0.65)),
          // Login inhoud
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 512),
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                // Logo en titel
                Icon(
                  Icons.calendar_month,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Roosterapp',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ruimte Reserveringssysteem',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'V ${AppVersion.version}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 48),

                // Gebruikersnaam veld
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Gebruikersnaam',
                    hintText: 'Je naam',
                    prefixIcon: Icon(Icons.person),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Wachtwoord veld
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Wachtwoord',
                    hintText: 'Je wachtwoord',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 8),

                // Wachtwoord vergeten link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text('Wachtwoord vergeten?', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),

                // Login knop
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Inloggen', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'of',
                        style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                const SizedBox(height: 24),

                // Registreren knop
                ElevatedButton(
                  onPressed: () {
                    final name = _usernameController.text.trim();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(
                          initialName: name.isNotEmpty ? name : null,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  ),
                  child: const Text('Nieuw account aanmaken', style: TextStyle(fontWeight: FontWeight.bold)),
                ),

                  ],
                ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
