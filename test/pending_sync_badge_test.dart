import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';

/// Reproduces how list rows place the badge: a title that may be long, next to
/// the badge, inside a width the row cannot grow past. This is the failure mode
/// `flutter analyze` cannot see — a RenderFlex overflow only happens on layout.
///
/// The default width matches a card row on a phone. Note the test font draws
/// every glyph one em wide (roughly twice a real font), so these widths are
/// already a pessimistic stand-in for the real thing.
Widget _row(String title, PendingOpKind kind, {double width = 320}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: width,
        child: Row(
          children: [
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            PendingSyncBadge(kind: kind, isID: true, compact: true),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('labels each queued state in Indonesian', (tester) async {
    for (final (kind, label) in [
      (PendingOpKind.create, 'Offline'),
      (PendingOpKind.update, 'Offline · edit'),
      (PendingOpKind.delete, 'Offline · hapus'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PendingSyncBadge(kind: kind, isID: true)),
        ),
      );
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('labels each queued state in English', (tester) async {
    for (final (kind, label) in [
      (PendingOpKind.create, 'Offline'),
      (PendingOpKind.update, 'Offline · edited'),
      (PendingOpKind.delete, 'Offline · delete'),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PendingSyncBadge(kind: kind, isID: false)),
        ),
      );
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('survives a narrow row next to a long title', (tester) async {
    await tester.pumpWidget(
      _row('Pohon dengan nama yang sangat panjang sekali', PendingOpKind.delete),
    );

    // takeException() returns the overflow error, if layout produced one.
    expect(tester.takeException(), isNull);
    expect(find.text('Offline · hapus'), findsOneWidget);
  });

  testWidgets('stays laid out at the largest text scale the app allows', (
    tester,
  ) async {
    // main.dart clamps text scaling to 0.95, so that is the worst case a real
    // device can produce.
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.95)),
        child: _row('Plot A', PendingOpKind.update, width: 300),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('the locked-row message names the sync action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPendingRowMessage(context, isID: true),
              child: const Text('tap'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tap'));
    await tester.pump();

    expect(find.textContaining('menunggu sinkron'), findsOneWidget);
  });
}
