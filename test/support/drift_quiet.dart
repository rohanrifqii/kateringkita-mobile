import 'package:drift/drift.dart';

/// Setiap widget test membangun pohon provider baru dengan `AppDb` baru.
/// Menutupnya lewat dispose tidak bisa selesai di test (close() menunggu
/// pembukaan koneksi native yang tidak pernah selesai di FakeAsync), sehingga
/// drift mencetak "created the database class AppDb multiple times".
/// Peringatan itu tidak relevan di test: tiap test memakai tree sendiri.
void quietDriftMultiDbWarning() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}
