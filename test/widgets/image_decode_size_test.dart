import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/widgets/menu_image.dart';
import 'package:kateringkita_pbl/widgets/profile_avatar.dart';

Widget _host(Widget child) => MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2.5),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: child),
      ),
    );

/// Lebar cache dari ResizeImage milik Image pertama di pohon widget.
int? _cacheWidth(WidgetTester t) {
  final provider = t.widget<Image>(find.byType(Image).first).image;
  return provider is ResizeImage ? provider.width : null;
}

void main() {
  testWidgets('MenuImage mendekode selebar width x devicePixelRatio',
      (t) async {
    await t.pumpWidget(_host(const MenuImage('http://x.test/a.jpg', width: 100)));
    expect(_cacheWidth(t), 250);
  });

  testWidgets('MenuImage tanpa width memakai lebar batas induk', (t) async {
    await t.pumpWidget(_host(const SizedBox(
        width: 80, child: MenuImage('http://x.test/a.jpg', height: 40))));
    expect(_cacheWidth(t), 200);
  });

  testWidgets('MenuImage dengan lebar tak terbatas tidak error', (t) async {
    await t.pumpWidget(_host(const SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: MenuImage('http://x.test/a.jpg', height: 40),
    )));
    expect(t.takeException(), isNull);
    expect(_cacheWidth(t), isNull);
  });

  testWidgets('ProfileAvatar mendekode selebar size x devicePixelRatio',
      (t) async {
    await t.pumpWidget(_host(const ProfileAvatar(
        name: 'A', url: 'http://x.test/a.jpg', size: 48)));
    expect(_cacheWidth(t), 120);
  });
}
