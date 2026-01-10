// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:split_expenses/main.dart';

void main() {
  testWidgets(
    'Shows firebase not configured screen when firebaseReady is false',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp(firebaseReady: false));

      expect(find.text('Firebase not configured'), findsOneWidget);
    },
  );
}
