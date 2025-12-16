import 'package:flutter_test/flutter_test.dart';
import 'package:shabbos_app/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ShabbosApp());
    
    // Verify the app title is displayed
    expect(find.text('Shabbos!!'), findsOneWidget);
  });
}
