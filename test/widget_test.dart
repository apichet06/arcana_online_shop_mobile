import 'package:arcana_online_shop_mobile/app/arcana_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows storefront landing page', (tester) async {
    await tester.pumpWidget(const ArcanaApp());

    expect(find.text('Arcana Premium'), findsWidgets);
    expect(find.text('Deadstock'), findsOneWidget);
  });
}
