import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/password_validator.dart';
import 'room_list_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? initialName;

  const RegisterScreen({super.key, this.initialName});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _commentController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  PasswordValidationResult? _passwordValidation;
  String? _usernameError;
  final _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _nameFocusNode.addListener(() {
      if (!_nameFocusNode.hasFocus && _nameController.text.trim().isNotEmpty) {
        _checkUsername();
      }
    });
    // Vul initiële naam in als meegegeven
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  Future<void> _checkUsername() async {
    final exists = await context.read<AuthProvider>().isUsernameRegistered(_nameController.text.trim());
    if (mounted) {
      setState(() {
        _usernameError = exists ? 'Gebruiker bestaat al, kies een andere naam' : null;
      });
    }
  }

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _commentController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordValidation = PasswordValidator.validate(_passwordController.text);
    });
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();

      // Check of gebruikersnaam al bestaat
      final exists = await authProvider.isUsernameRegistered(_nameController.text.trim());
      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gebruiker bestaat al, kies een andere naam'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      await authProvider.register(
            name: _nameController.text,
            email: _emailController.text,
            phoneNumber: _phoneController.text,
            address: _addressController.text,
            postalCode: _postalCodeController.text,
            city: _cityController.text,
            comment: _commentController.text.isEmpty ? null : _commentController.text,
            password: _passwordController.text,
          );

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RoomListScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registreren'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Naam
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Naam',
                    hintText: 'Je volledige naam',
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                    errorText: _usernameError,
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Voer je naam in';
                    }
                    if (_usernameError != null) return _usernameError;
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'E-mailadres',
                    hintText: 'naam@voorbeeld.nl',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Voer je e-mailadres in';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Voer een geldig e-mailadres in';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Telefoonnummer (verplicht)
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Telefoonnummer *',
                    hintText: '06-12345678',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Voer je telefoonnummer in';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // NAW gegevens sectie (verplicht)
                Text(
                  'Adresgegevens *',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 12),

                // Adres (verplicht)
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Adres *',
                    hintText: 'Straatnaam en huisnummer',
                    prefixIcon: Icon(Icons.home),
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Voer je adres in';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Postcode en Plaats op één rij (verplicht)
                Row(
                  children: [
                    // Postcode (verplicht)
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _postalCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Postcode *',
                          hintText: '1234 AB',
                          prefixIcon: Icon(Icons.markunread_mailbox),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Voer postcode in';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Plaats (verplicht)
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'Plaats *',
                          hintText: 'Amsterdam',
                          prefixIcon: Icon(Icons.location_city),
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Voer plaats in';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Commentaar sectie
                Text(
                  'Extra informatie (optioneel)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 12),

                // Commentaar
                TextFormField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    labelText: 'Commentaar',
                    hintText: 'Bijv. afdeling, functie, bijzonderheden...',
                    prefixIcon: Icon(Icons.comment),
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 24),

                // Wachtwoord sectie
                Text(
                  'Beveiliging',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 12),

                // Wachtwoord
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Wachtwoord',
                    hintText: 'Kies een sterk wachtwoord',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Voer een wachtwoord in';
                    }
                    final validation = PasswordValidator.validate(value);
                    if (!validation.isValid) {
                      return validation.errors.first;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

                // Wachtwoord requirements indicator
                if (_passwordController.text.isNotEmpty && _passwordValidation != null)
                  _PasswordRequirements(validation: _passwordValidation!),
                const SizedBox(height: 16),

                // Bevestig wachtwoord
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Bevestig wachtwoord',
                    hintText: 'Herhaal je wachtwoord',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Bevestig je wachtwoord';
                    }
                    if (value != _passwordController.text) {
                      return 'Wachtwoorden komen niet overeen';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _register(),
                ),
                const SizedBox(height: 24),

                // Registreer knop
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Registreren'),
                ),
                const SizedBox(height: 16),

                // Terug naar login
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Al een account? Log in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  final PasswordValidationResult validation;

  const _PasswordRequirements({required this.validation});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wachtwoord eisen:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          _RequirementRow(
            text: 'Minimaal 12 karakters',
            isMet: validation.length >= 12,
            current: '${validation.length}/12',
          ),
          _RequirementRow(
            text: 'Minimaal 1 hoofdletter',
            isMet: validation.uppercaseCount >= 1,
            current: '${validation.uppercaseCount}/1',
          ),
          _RequirementRow(
            text: 'Minimaal 2 speciale tekens',
            isMet: validation.specialCharCount >= 2,
            current: '${validation.specialCharCount}/2',
          ),
        ],
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String text;
  final bool isMet;
  final String current;

  const _RequirementRow({
    required this.text,
    required this.isMet,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: isMet ? Colors.green[700] : Colors.grey[600],
              ),
            ),
          ),
          Text(
            current,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMet ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
