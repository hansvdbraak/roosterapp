class PasswordValidator {
  static const int minLength = 12;
  static const int minUppercase = 1;
  static const int minSpecialChars = 2;

  static const String specialCharacters = r'!@#$%^&*()_+-=[]{}|;:,.<>?/~`';

  static PasswordValidationResult validate(String password) {
    final errors = <String>[];

    // Check minimum length
    if (password.length < minLength) {
      errors.add('Minimaal $minLength karakters (nu ${password.length})');
    }

    // Count uppercase letters
    final uppercaseCount = password.split('').where((c) => c.toUpperCase() == c && c.toLowerCase() != c).length;
    if (uppercaseCount < minUppercase) {
      errors.add('Minimaal $minUppercase hoofdletter(s) (nu $uppercaseCount)');
    }

    // Count special characters
    final specialCount = password.split('').where((c) => specialCharacters.contains(c)).length;
    if (specialCount < minSpecialChars) {
      errors.add('Minimaal $minSpecialChars speciale tekens (nu $specialCount)');
    }

    return PasswordValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      length: password.length,
      uppercaseCount: uppercaseCount,
      specialCharCount: specialCount,
    );
  }

  static String getRequirementsText() {
    return 'Wachtwoord moet minimaal $minLength karakters bevatten, '
        'waarvan minimaal $minUppercase hoofdletter en $minSpecialChars speciale tekens';
  }
}

class PasswordValidationResult {
  final bool isValid;
  final List<String> errors;
  final int length;
  final int uppercaseCount;
  final int specialCharCount;

  PasswordValidationResult({
    required this.isValid,
    required this.errors,
    required this.length,
    required this.uppercaseCount,
    required this.specialCharCount,
  });
}
