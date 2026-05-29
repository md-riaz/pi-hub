import 'package:flutter_test/flutter_test.dart';

import 'package:pi_hub_app/main.dart';

void main() {
  testWidgets('Pi Hub renders connection form', (WidgetTester tester) async {
    await tester.pumpWidget(const PiHubApp());

    expect(find.text('Pi Hub'), findsWidgets);
    expect(find.text('Server URL'), findsOneWidget);
    expect(find.text('Token'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
  });
}
