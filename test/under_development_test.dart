import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:traceability_app/screens/widgets/under_development.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('says the menu is being reworked, in Indonesian', (tester) async {
    await tester.pumpWidget(
      _host(const UnderDevelopment(isID: true, featureName: 'pembelian')),
    );

    expect(find.text('Sedang dalam pengembangan'), findsOneWidget);
    expect(find.textContaining('struktur data baru'), findsOneWidget);
  });

  testWidgets('speaks English when the app is in English', (tester) async {
    await tester.pumpWidget(
      _host(const UnderDevelopment(isID: false, featureName: 'purchasing')),
    );

    expect(find.text('Under development'), findsOneWidget);
  });

  testWidgets('a custom note replaces the default explanation', (tester) async {
    await tester.pumpWidget(
      _host(
        const UnderDevelopment(
          isID: true,
          featureName: 'setoran',
          note: 'Hubungi pengurus KTH.',
        ),
      ),
    );

    expect(find.text('Hubungi pengurus KTH.'), findsOneWidget);
    expect(find.textContaining('sistem kantor'), findsNothing);
  });

  testWidgets('the home card fits a narrow phone width', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 320,
          child: UnderDevelopmentCard(isID: true, featureName: 'Penjualan'),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.textContaining('sedang dalam pengembangan'), findsOneWidget);
  });
}
