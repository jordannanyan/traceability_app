import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:traceability_app/models/api/refresh_outcome.dart';
import 'package:traceability_app/screens/widgets/stale_data_banner.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('stays out of the way when the data is fresh', (tester) async {
    await tester.pumpWidget(
      _host(const StaleDataBanner(outcome: RefreshOutcome.fresh, isID: true)),
    );

    expect(find.byType(Container), findsNothing);
    expect(find.textContaining('Gagal'), findsNothing);
  });

  testWidgets('stays out of the way when merely offline', (tester) async {
    // Offline is expected in the field and already has its own banner —
    // stacking a second warning would be noise.
    await tester.pumpWidget(
      _host(
        const StaleDataBanner(outcome: RefreshOutcome.offlineCache, isID: true),
      ),
    );

    expect(find.textContaining('Gagal'), findsNothing);
  });

  testWidgets('explains a failed refresh and offers a retry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        StaleDataBanner(
          outcome: RefreshOutcome.refreshFailed,
          isID: true,
          onRetry: () => retries++,
        ),
      ),
    );

    expect(find.textContaining('Gagal memuat data terbaru'), findsOneWidget);
    expect(find.textContaining('data tersimpan'), findsOneWidget);

    await tester.tap(find.text('Coba lagi'));
    expect(retries, 1);
  });

  testWidgets('names the session as the cause and hides retry', (tester) async {
    await tester.pumpWidget(
      _host(
        StaleDataBanner(
          outcome: RefreshOutcome.unauthorized,
          isID: true,
          onRetry: () {},
        ),
      ),
    );

    expect(find.textContaining('Sesi Anda sudah berakhir'), findsOneWidget);
    expect(
      find.text('Coba lagi'),
      findsNothing,
      reason: 'retrying cannot help until the user logs in again',
    );
  });

  testWidgets('speaks English when the app is in English', (tester) async {
    await tester.pumpWidget(
      _host(
        const StaleDataBanner(
          outcome: RefreshOutcome.refreshFailed,
          isID: false,
        ),
      ),
    );

    expect(find.textContaining('Could not load the latest data'), findsOneWidget);
  });

  testWidgets('fits a narrow phone width without overflowing', (tester) async {
    await tester.pumpWidget(
      _host(
        const SizedBox(
          width: 320,
          child: StaleDataBanner(
            outcome: RefreshOutcome.unauthorized,
            isID: true,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
