/// At least 8 characters with a mix of letters and numbers — strong
/// enough to matter without demanding symbols nobody remembers.
bool isStrongPassword(String password) {
  return password.length >= 8 &&
      RegExp(r'[A-Za-z]').hasMatch(password) &&
      RegExp(r'[0-9]').hasMatch(password);
}
