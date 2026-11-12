/// Aturan sandi yang sama dengan backend (daftar & reset sandi).
const String kPasswordRuleMessage =
    'Password 8–72 karakter, minimal 1 huruf dan 1 angka.';

/// Mengembalikan pesan galat bila [password] melanggar aturan, selain itu null.
String? validatePasswordRules(String password) {
  if (password.length < 8 ||
      password.length > 72 ||
      !RegExp(r'[A-Za-z]').hasMatch(password) ||
      !RegExp(r'\d').hasMatch(password)) {
    return kPasswordRuleMessage;
  }
  return null;
}
