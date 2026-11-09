import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('QuantaKeys Test'),
        ),
      ),
    );

    expect(find.text('QuantaKeys Test'), findsOneWidget);
  });
}
