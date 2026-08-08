import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// What a queued outbox item will do to the server once it is pushed.
enum PendingOpKind {
  /// A record that does not exist on the server yet (`POST` to a collection).
  create,

  /// A change to an existing record (`PUT`/`POST` with `_method=PUT`, photo
  /// uploads, polygon points, status updates…).
  update,

  /// A `DELETE` that has not reached the server yet.
  delete,
}

/// A single queued outbox item, read back for **display** purposes.
///
/// Every API client in `models/api/` persists its outbox as a `List<String>` of
/// JSON objects sharing the same envelope:
///
/// ```json
/// { "id": "1754...", "method": "POST", "endpoint": "/trees",
///   "body": { ... }, "entity_id": null, "ts": 1754... }
/// ```
///
/// so one reader serves all of them. This type is intentionally read-only: the
/// push loops keep owning their own private item classes and the queue itself.
class PendingOp {
  /// Client-side op id (epoch millis as string) — unique per queued item.
  final String opId;

  final PendingOpKind kind;

  final String endpoint;

  /// The queued payload. Values are usually stringified (they are sent as
  /// multipart form fields), so model `fromJson` parsers must tolerate strings.
  final Map<String, dynamic> body;

  /// Server id of the affected record — `null` for a create.
  final int? entityId;

  /// When the item was queued (epoch millis).
  final int ts;

  /// Sub-type for outboxes that mix several kinds of item, e.g. PlotApi's
  /// `'plot'` / `'polygon_points'` / `'polygon_photo'`.
  final String? group;

  const PendingOp({
    required this.opId,
    required this.kind,
    required this.endpoint,
    required this.body,
    required this.entityId,
    required this.ts,
    this.group,
  });

  /// Synthetic **negative** id for a queued create, so it can be used as a list
  /// key and told apart from a real server id (which is always positive).
  /// Derived from [ts], which the outbox already treats as unique per item.
  int get localId => -ts;

  DateTime get queuedAt => DateTime.fromMillisecondsSinceEpoch(ts);

  static PendingOp? _tryParse(
    String raw, {
    required String entityIdField,
    PendingOpKind? forceKind,
  }) {
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final method = (j['method'] ?? '').toString().toUpperCase();
      final entityId = j[entityIdField] is int
          ? j[entityIdField] as int
          : int.tryParse('${j[entityIdField]}');

      final PendingOpKind kind;
      if (forceKind != null) {
        kind = forceKind;
      } else if (method == 'DELETE') {
        kind = PendingOpKind.delete;
      } else if (entityId == null) {
        kind = PendingOpKind.create;
      } else {
        kind = PendingOpKind.update;
      }

      return PendingOp(
        opId: (j['id'] ?? '').toString(),
        kind: kind,
        endpoint: (j['endpoint'] ?? '').toString(),
        body: (j['body'] as Map? ?? const {}).cast<String, dynamic>(),
        entityId: entityId,
        ts: (j['ts'] is int) ? j['ts'] as int : int.tryParse('${j['ts']}') ?? 0,
        group: j['kind']?.toString(),
      );
    } catch (_) {
      // A malformed row must never break a list screen.
      return null;
    }
  }
}

/// Reads outbox queues back out of `SharedPreferences` so pending work can be
/// shown in the lists it belongs to, instead of only as a queue count.
class PendingOps {
  const PendingOps._();

  /// Reads the outbox stored under [prefsKey], oldest first.
  ///
  /// [entityIdField] is the JSON field holding the affected server id — the
  /// shared envelope uses `entity_id`, but a few purpose-built queues (e.g.
  /// purchasing status) name it differently. [forceKind] overrides the
  /// method/entity-id classification for such queues.
  static Future<List<PendingOp>> read(
    String prefsKey, {
    String entityIdField = 'entity_id',
    PendingOpKind? forceKind,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(prefsKey) ?? const <String>[];
    final ops = <PendingOp>[];
    for (final s in raw) {
      final op = PendingOp._tryParse(
        s,
        entityIdField: entityIdField,
        forceKind: forceKind,
      );
      if (op != null) ops.add(op);
    }
    ops.sort((a, b) => a.ts.compareTo(b.ts)); // FIFO, same order as the push
    return ops;
  }
}

/// Queued ops arranged for a list screen: rows to add, plus a lookup of which
/// existing rows carry a pending change.
class PendingIndex {
  /// Creates that are not on the server yet — render these as extra rows.
  final List<PendingOp> creates;

  /// Server id → the latest queued change for that record.
  final Map<int, PendingOpKind> byServerId;

  const PendingIndex({required this.creates, required this.byServerId});

  static const PendingIndex empty = PendingIndex(
    creates: <PendingOp>[],
    byServerId: <int, PendingOpKind>{},
  );

  /// Groups [ops] (already FIFO-ordered) into creates and per-record changes.
  ///
  /// A queued delete always wins over a queued update for the same record: the
  /// row is on its way out, and that is what the badge should say.
  factory PendingIndex.from(Iterable<PendingOp> ops) {
    final creates = <PendingOp>[];
    final byId = <int, PendingOpKind>{};

    for (final op in ops) {
      if (op.kind == PendingOpKind.create) {
        creates.add(op);
        continue;
      }
      final id = op.entityId;
      if (id == null) continue;
      if (op.kind == PendingOpKind.delete ||
          byId[id] != PendingOpKind.delete) {
        byId[id] = op.kind;
      }
    }

    return PendingIndex(creates: creates, byServerId: byId);
  }

  bool get isEmpty => creates.isEmpty && byServerId.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get total => creates.length + byServerId.length;

  /// The pending state of a row, or `null` when it is fully synced.
  /// Handles both real server ids and the negative [PendingOp.localId] of a
  /// queued create, so a list can ask about any row it renders.
  PendingOpKind? kindFor(int? rowId) {
    if (rowId == null) return null;
    if (rowId < 0) {
      return creates.any((c) => c.localId == rowId)
          ? PendingOpKind.create
          : null;
    }
    return byServerId[rowId];
  }

  /// Whether a row must refuse open/edit/delete because of its queued state.
  ///
  /// A **create** has no server record to act on yet — its id is the synthetic
  /// negative one — and a **delete** is on its way out, so acting on either
  /// would push a request the server can only reject. A pending **update** is
  /// different: the record exists, and editing it again simply replaces the
  /// queued change, which is exactly what a field user needs offline.
  bool blocksActions(int? rowId) {
    final k = kindFor(rowId);
    return k == PendingOpKind.create || k == PendingOpKind.delete;
  }

  /// Keeps only the creates matching [test] — used to show a pending row on the
  /// list it actually belongs to. What identifies the parent differs per
  /// module: usually a body field (`plot_id`), sometimes the endpoint itself
  /// (`/trees/7/monitorings`), so the whole op is passed.
  PendingIndex whereCreate(bool Function(PendingOp op) test) => PendingIndex(
    creates: creates.where(test).toList(),
    byServerId: byServerId,
  );
}

/// Reads `body['field']` as an int regardless of whether the outbox stored it
/// as a number or (more usually) a stringified form field.
int? pendingBodyInt(Map<String, dynamic> body, String field) {
  final v = body[field];
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}
