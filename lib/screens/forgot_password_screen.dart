import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/password_validator.dart';

enum _Step { phoneVerification, newPassword }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _verifyFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  PasswordValidationResult? _passwordValidation;

  _Step _currentStep = _Step.phoneVerification;
  int? _verifiedUserId;

  @override
  void dispose() {
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _verifyPhone() async {
    if (!_verifyFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = await context.read<AuthProvider>().verifyPhoneForPasswordReset(
            _usernameController.text.trim(),
            _phoneController.text.trim(),
          );

      if (mounted) {
        setState(() {
          _verifiedUserId = userId;
          _currentStep = _Step.newPassword;
        });
      }
    } catch (e) {
      final error = e.toString().replaceAll('Exception: ', '');
      if (error == 'PHONE_MISMATCH') {
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Verificatie mislukt'),
              content: const Text(
                'Telefoonnummer is onjuist; neem contact op met de serviceafdeling.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    // Terug naar het inlogscherm (eerste route in de stack)
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Terug naar inlogscherm'),
                ),
              ],
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    if (_verifiedUserId == null) return;

    setState(() => _isLoading = true);

    try {
      await context.read<AuthProvider>().resetPasswordById(
            userId: _verifiedUserId!,
            newPassword: _passwordController.text,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wachtwoord succesvol gewijzigd. Log in met je nieuwe wachtwoord.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
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
        title: const Text('Wachtwoord vergeten'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _currentStep == _Step.phoneVerification
              ? _buildPhoneVerificationForm()
              : _buildNewPasswordForm(),
        ),
      ),
    );
  }

  Widget _buildPhoneVerificationForm() {
    return Form(
      key: _verifyFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Icon(
            Icons.lock_reset,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Wachtwoord vergeten?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Voer je gebruikersnaam en het mobiele telefoonnummer in dat bij je account is geregistreerd.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Gebruikersnaam
          TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Gebruikersnaam',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Voer je gebruikersnaam in';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Telefoonnummer
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Mobiel telefoonnummer',
              hintText: '06-12345678',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Voer je mobiele telefoonnummer in';
              }
              return null;
            },
            onFieldSubmitted: (_) => _verifyPhone(),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _verifyPhone,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Controleren'),
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Terug naar inloggen'),
          ),
        ],
      ),
    );
  }

  Widget _buildNewPasswordForm() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          Text(
            'Identiteit geverifieerd',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Kies een nieuw wachtwoord voor je account.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Nieuw wachtwoord
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Nieuw wachtwoord',
              prefixIcon: const Icon(Icons.lock),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            onChanged: (value) {
              setState(() {
                _passwordValidation = PasswordValidator.validate(value);
              });
            },
            validator: (value) {
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

          if (_passwordController.text.isNotEmpty && _passwordValidation != null)
            _PasswordRequirements(validation: _passwordValidation!),
          const SizedBox(height: 16),

          // Bevestig wachtwoord
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'Bevestig nieuw wachtwoord',
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
                return 'Bevestig je nieuwe wachtwoord';
              }
              if (value != _passwordController.text) {
                return 'Wachtwoorden komen niet overeen';
              }
              return null;
            },
            onFieldSubmitted: (_) => _resetPassword(),
          ),
          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _resetPassword,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Wachtwoord opslaan'),
          ),
        ],
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
