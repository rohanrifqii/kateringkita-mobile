// Aturan kata sandi di sisi aplikasi, dipakai layar daftar dan reset sandi untuk memeriksa isian
// sebelum dikirim ke backend (backend tetap memeriksa ulang dengan aturan yang sama).

/// Pesan galat aturan sandi; aturannya sama dengan backend (daftar & reset sandi).
const String kPasswordRuleMessage =
    'Password 8–72 karakter, minimal 1 huruf dan 1 angka.';

/// Memeriksa [password]: panjang 8–72 karakter, minimal 1 huruf (A–Z/a–z) dan 1 angka.
/// Mengembalikan [kPasswordRuleMessage] bila melanggar, selain itu null (cocok untuk validator formulir).
String? validatePasswordRules(String password) {
  if (password.length < 8 ||
      password.length > 72 ||
      !RegExp(r'[A-Za-z]').hasMatch(password) ||
      !RegExp(r'\d').hasMatch(password)) {
    return kPasswordRuleMessage;
  }
  return null;
}
