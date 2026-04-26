import 'package:flutter_test/flutter_test.dart';
import 'package:smart_invest/main.dart';

void main() {
  testWidgets('App starts correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartInvestApp());
    expect(find.text('Smart Invest'), findsAny);
  });
}
