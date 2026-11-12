import 'dart:async';

/// flutter_map mencetak pemberitahuan kebijakan tile OSM (mode debug) setiap
/// kali TileLayer dengan URL tile.openstreetmap.org dibuat. Di test itu hanya
/// derau; jalankan [body] dengan `print` yang membuang pesan tersebut.
Future<T> withoutOsmTileNotice<T>(Future<T> Function() body) => runZoned(
      body,
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (line.contains('[flutter_map]')) return;
          parent.print(zone, line);
        },
      ),
    );
