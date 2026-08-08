import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';

/// Builds one outbox row in the envelope every API client persists.
String _row({
  required String id,
  required String method,
  required String endpoint,
  int? entityId,
  Map<String, dynamic> body = const {},
  required int ts,
  String? kind,
}) => jsonEncode({
  'id': id,
  'method': method,
  'endpoint': endpoint,
  'body': body,
  'entity_id': entityId,
  'ts': ts,
  if (kind != null) 'kind': kind,
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingOps.read', () {
    test('classifies create / update / delete from the envelope', () async {
      SharedPreferences.setMockInitialValues({
        'outbox_test': <String>[
          _row(id: '1', method: 'POST', endpoint: '/trees', ts: 1),
          _row(
            id: '2',
            method: 'POST',
            endpoint: '/trees/7',
            entityId: 7,
            ts: 2,
          ),
          _row(
            id: '3',
            method: 'DELETE',
            endpoint: '/trees/9',
            entityId: 9,
            ts: 3,
          ),
        ],
      });

      final ops = await PendingOps.read('outbox_test');

      expect(ops.map((o) => o.kind), [
        PendingOpKind.create,
        PendingOpKind.update,
        PendingOpKind.delete,
      ]);
    });

    test('returns oldest first, matching the push order', () async {
      SharedPreferences.setMockInitialValues({
        'outbox_test': <String>[
          _row(id: 'b', method: 'POST', endpoint: '/trees', ts: 200),
          _row(id: 'a', method: 'POST', endpoint: '/trees', ts: 100),
        ],
      });

      final ops = await PendingOps.read('outbox_test');

      expect(ops.map((o) => o.opId), ['a', 'b']);
    });

    test('skips a malformed row instead of breaking the list', () async {
      SharedPreferences.setMockInitialValues({
        'outbox_test': <String>[
          'not json at all',
          _row(id: '1', method: 'POST', endpoint: '/trees', ts: 1),
        ],
      });

      final ops = await PendingOps.read('outbox_test');

      expect(ops, hasLength(1));
      expect(ops.single.opId, '1');
    });

    test('reads an alternative id field and a forced kind', () async {
      // The purchasing status queue names its record `purchase_id` and is
      // always an update, whatever its HTTP method looks like.
      SharedPreferences.setMockInitialValues({
        'outbox_status': <String>[
          jsonEncode({'id': '1', 'purchase_id': 42, 'status': 'verified', 'ts': 5}),
        ],
      });

      final ops = await PendingOps.read(
        'outbox_status',
        entityIdField: 'purchase_id',
        forceKind: PendingOpKind.update,
      );

      expect(ops.single.entityId, 42);
      expect(ops.single.kind, PendingOpKind.update);
    });

    test('an absent outbox reads as empty, not an error', () async {
      SharedPreferences.setMockInitialValues({});

      expect(await PendingOps.read('outbox_missing'), isEmpty);
    });
  });

  group('PendingIndex', () {
    PendingOp op(
      PendingOpKind kind, {
      int? entityId,
      int ts = 1,
      Map<String, dynamic> body = const {},
    }) => PendingOp(
      opId: '$ts',
      kind: kind,
      endpoint: '/x',
      body: body,
      entityId: entityId,
      ts: ts,
    );

    test('splits creates from changes to existing records', () {
      final idx = PendingIndex.from([
        op(PendingOpKind.create, ts: 1),
        op(PendingOpKind.update, entityId: 5, ts: 2),
      ]);

      expect(idx.creates, hasLength(1));
      expect(idx.byServerId, {5: PendingOpKind.update});
      expect(idx.total, 2);
    });

    test('a queued delete outranks a queued update on the same record', () {
      final deleteThenUpdate = PendingIndex.from([
        op(PendingOpKind.delete, entityId: 5, ts: 1),
        op(PendingOpKind.update, entityId: 5, ts: 2),
      ]);
      final updateThenDelete = PendingIndex.from([
        op(PendingOpKind.update, entityId: 5, ts: 1),
        op(PendingOpKind.delete, entityId: 5, ts: 2),
      ]);

      expect(deleteThenUpdate.byServerId[5], PendingOpKind.delete);
      expect(updateThenDelete.byServerId[5], PendingOpKind.delete);
    });

    test('kindFor resolves both server ids and synthetic local ids', () {
      final create = op(PendingOpKind.create, ts: 1700000000000);
      final idx = PendingIndex.from([
        create,
        op(PendingOpKind.update, entityId: 5, ts: 2),
      ]);

      expect(create.localId, isNegative);
      expect(idx.kindFor(create.localId), PendingOpKind.create);
      expect(idx.kindFor(5), PendingOpKind.update);
      expect(idx.kindFor(999), isNull);
      expect(idx.kindFor(null), isNull);
      expect(idx.kindFor(-1), isNull, reason: 'unknown local id is not pending');
    });

    test('blocksActions locks creates and deletes but not updates', () {
      final create = op(PendingOpKind.create, ts: 10);
      final idx = PendingIndex.from([
        create,
        op(PendingOpKind.update, entityId: 5, ts: 11),
        op(PendingOpKind.delete, entityId: 6, ts: 12),
      ]);

      expect(idx.blocksActions(create.localId), isTrue);
      expect(idx.blocksActions(6), isTrue);
      expect(
        idx.blocksActions(5),
        isFalse,
        reason: 'a queued edit stays editable while still offline',
      );
      expect(idx.blocksActions(404), isFalse);
    });

    test('whereCreate scopes rows to their parent, keeping other changes', () {
      final idx = PendingIndex.from([
        op(PendingOpKind.create, ts: 1, body: {'plot_id': '3'}),
        op(PendingOpKind.create, ts: 2, body: {'plot_id': '9'}),
        op(PendingOpKind.update, entityId: 5, ts: 3),
      ]).whereCreate((o) => pendingBodyInt(o.body, 'plot_id') == 3);

      expect(idx.creates, hasLength(1));
      expect(idx.creates.single.body['plot_id'], '3');
      expect(idx.byServerId, {5: PendingOpKind.update});
    });

    test('empty index reports nothing pending', () {
      expect(PendingIndex.empty.isEmpty, isTrue);
      expect(PendingIndex.empty.kindFor(1), isNull);
      expect(PendingIndex.empty.blocksActions(1), isFalse);
    });
  });

  group('pendingBodyInt', () {
    test('accepts the stringified values multipart bodies store', () {
      expect(pendingBodyInt({'plot_id': '12'}, 'plot_id'), 12);
      expect(pendingBodyInt({'plot_id': 12}, 'plot_id'), 12);
      expect(pendingBodyInt({'plot_id': 12.0}, 'plot_id'), 12);
      expect(pendingBodyInt({'plot_id': ' 12 '}, 'plot_id'), 12);
      expect(pendingBodyInt({'plot_id': 'abc'}, 'plot_id'), isNull);
      expect(pendingBodyInt({}, 'plot_id'), isNull);
    });
  });
}
