import 'package:flutter_test/flutter_test.dart';
import 'package:pi_hub_app/main.dart';

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const PiHubApp());
    expect(find.text('Pi Mobile'), findsOneWidget);
  });
}
