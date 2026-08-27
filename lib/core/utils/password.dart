/// At least 8 characters, with a number, an uppercase letter, and a
/// symbol — shown as a live checklist next to the field (see
/// [PasswordRequirement]) so it's never a guessing game.
bool isStrongPassword(String password) {
  return PasswordRequirement.values.every((r) => r.isMet(password));
}

enum PasswordRequirement {
  length('At least 8 characters'),
  number('At least one number'),
  uppercase('At least one capital letter'),
  symbol('At least one symbol');

  const PasswordRequirement(this.label);
  final String label;

  bool isMet(String password) => switch (this) {
        PasswordRequirement.length => password.length >= 8,
        PasswordRequirement.number => RegExp(r'[0-9]').hasMatch(password),
        PasswordRequirement.uppercase => RegExp(r'[A-Z]').hasMatch(password),
        PasswordRequirement.symbol => RegExp(r'[^A-Za-z0-9]').hasMatch(password),
      };
}
