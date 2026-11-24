import 'pickup_time.dart';

/// Waktu relatif dalam WIB untuk daftar seperti notifikasi:
/// "Baru saja", "5 menit lalu", "3 jam lalu", "Kemarin · 23:30 WIB",
/// "3 hari lalu", lalu tanggal lengkap ("Min, 1 Nov 2026 · 08:05 WIB").
/// "Kemarin"/hari dihitung dari tanggal kalender WIB.
String relativeTimeWib(DateTime time, {DateTime? now}) {
  final t = time.toUtc();
  final n = (now ?? DateTime.now()).toUtc();
  final diff = n.difference(t);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';

  final tw = toWibWallClock(t);
  final nw = toWibWallClock(n);
  final days = DateTime.utc(nw.year, nw.month, nw.day)
      .difference(DateTime.utc(tw.year, tw.month, tw.day))
      .inDays;
  if (days <= 0) return '${diff.inHours} jam lalu';
  if (days == 1) {
    final hh = tw.hour.toString().padLeft(2, '0');
    final mm = tw.minute.toString().padLeft(2, '0');
    return 'Kemarin · $hh:$mm WIB';
  }
  if (days < 7) return '$days hari lalu';
  return formatWib(t);
}
