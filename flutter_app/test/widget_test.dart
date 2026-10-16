import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartHomeSecurityApp());
    expect(find.byType(SmartHomeSecurityApp), findsOneWidget);
  });
}
