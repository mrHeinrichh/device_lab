import 'package:device_lab_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('demo app renders viewport details', (tester) async {
    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();
    expect(find.text('Viewport'), findsOneWidget);
  });
}
