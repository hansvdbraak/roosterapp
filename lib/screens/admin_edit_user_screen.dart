import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../utils/password_validator.dart';
import '../widgets/app_header.dart';

class AdminEditUserScreen extends StatefulWidget {
  final User user;

  const AdminEditUserScreen({super.key, required this.user});

  @override
  State<AdminEditUserScreen> createState() => _AdminEditUserScreenState();
}

class _AdminEditUserScreenState extends State<AdminEditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _commentController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _changePassword = false;
  PasswordValidationResult? _passwordValidation;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _newPasswordController.addListener(_onPasswordChanged);
  }

  void _loadUserData() {
    _emailController.text = widget.user.email;
    _phoneController.text = widget.user.phoneNumber ?? '';
    _addressController.text = widget.user.address ?? '';
    _postalCodeController.text = widget.user.postalCode ?? '';
    _cityController.text = widget.user.city ?? '';
    _commentController.text = widget.user.comment ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _commentController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordValidation = PasswordValidator.validate(_newPasswordController.text);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().adminUpdateUserProfile(
            userId: widget.user.id,
            email: _emailController.text,
            phoneNumber: _phoneController.text,
            address: _addressController.text,
            postalCode: _postalCodeController.text,
            city: _cityController.text,
            comment: _commentController.text.isEmpty ? null : _commentController.text,
            newPassword: _changePassword && _newPasswordController.text.isNotEmpty
                ? _newPasswordController.text
                : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profiel succesvol bijgewerkt'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
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
        title: Text('Profiel bewerken: ${widget.user.name}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          style: IconButton.styleFrom(
            backgroundColor: Colors.yellow[100],
            foregroundColor: Colors.deepOrange,
            shape: const CircleBorder(),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [
          AppHeaderActions(showDate: true),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Rol info (niet bewerkbaar)
                Card(
                  color: Colors.purple[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.security, color: Colors.purple[700]),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Rol: ${widget.user.role.displayName}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple[700],
                              ),
                            ),
                            Text(
                              'Rolwijziging gaat via het popup menu in gebruikersbeheer',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Naam (niet bewerkbaar)
                TextFormField(
                  initialValue: widget.user.name,
                  decoration: InputDecoration(
                    labelText: 'Gebruikersnaam',
                    prefixIcon: const Icon(Icons.person),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey[100],
                    helperText: 'Gebruikersnaam kan niet worden gewijzigd',
                  ),
                  readOnly: true,
                  enabled: false,
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
                      return 'Voer een e-mailadres in';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                      return 'Voer een geldig e-mailadres in';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Telefoonnummer
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
                      return 'Voer een telefoonnummer in';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // NAW gegevens sectie
                Text(
                  'Adresgegevens *',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 12),

                // Adres
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
                      return 'Voer een adres in';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Postcode en Plaats op één rij
                Row(
                  children: [
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

                // Wachtwoord wijzigen sectie
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock),
                            const SizedBox(width: 8),
                            Text(
                              'Wachtwoord wijzigen',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const Spacer(),
                            Switch(
                              value: _changePassword,
                              onChanged: (value) {
                                setState(() {
                                  _changePassword = value;
                                  if (!value) {
                                    _newPasswordController.clear();
                                    _confirmPasswordController.clear();
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        if (_changePassword) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _newPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Nieuw wachtwoord',
                              hintText: 'Kies een sterk wachtwoord',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () =>
                                    setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            validator: (value) {
                              if (!_changePassword) return null;
                              if (value == null || value.isEmpty) {
                                return 'Voer een nieuw wachtwoord in';
                              }
                              final validation = PasswordValidator.validate(value);
                              if (!validation.isValid) {
                                return validation.errors.first;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          if (_newPasswordController.text.isNotEmpty &&
                              _passwordValidation != null)
                            _PasswordRequirements(validation: _passwordValidation!),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            decoration: InputDecoration(
                              labelText: 'Bevestig nieuw wachtwoord',
                              hintText: 'Herhaal het nieuwe wachtwoord',
                              prefixIcon: const Icon(Icons.lock_outline),
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(_obscureConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off),
                                onPressed: () => setState(
                                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
                              ),
                            ),
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            validator: (value) {
                              if (!_changePassword) return null;
                              if (value == null || value.isEmpty) {
                                return 'Bevestig het nieuwe wachtwoord';
                              }
                              if (value != _newPasswordController.text) {
                                return 'Wachtwoorden komen niet overeen';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Opslaan knop
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Opslaan'),
                ),
                const SizedBox(height: 16),

                // Annuleren knop
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Annuleren'),
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
