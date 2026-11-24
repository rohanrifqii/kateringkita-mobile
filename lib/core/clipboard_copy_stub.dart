// Versi non-web (Android/iOS/desktop) dari cadangan salin untuk clipboard_copy.dart:
// Clipboard bawaan Flutter selalu tersedia, jadi cadangan tidak pernah dipakai.

/// Selalu `false`: di luar web tidak perlu cadangan.
bool get perluCadangan => false;

/// Tidak dipanggil di luar web (karena [perluCadangan] false); selalu `false`.
bool salin(String text) => false;
