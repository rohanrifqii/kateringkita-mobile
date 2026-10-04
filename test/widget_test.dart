import 'package:flutter_test/flutter_test.dart';
import 'package:kateringkita_pbl/main.dart';

void main() {
  testWidgets('KateringKita app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KateringKitaApp());
    expect(find.byType(KateringKitaApp), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 100));
  });
}
