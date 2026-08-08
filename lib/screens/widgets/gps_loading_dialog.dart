import 'package:flutter/material.dart';

import 'package:traceability_app/services/gps_sampler.dart';

/// Modal dialog that runs `session` to completion while showing live progress.
/// Returns the same `GpsSampleResult` the session would have produced.
/// The dialog cannot be dismissed by tapping outside or back button — user
/// must tap "Pakai sekarang" or "Batal".
Future<GpsSampleResult> showGpsLoadingDialog(
  BuildContext context, {
  required GpsSamplingSession session,
  String title = 'Mengambil koordinat GPS',
}) async {
  GpsSampleResult? result;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) {
      return PopScope(
        canPop: false,
        child: _GpsLoadingDialog(
          session: session,
          title: title,
          onDone: (r) {
            result = r;
            if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
          },
        ),
      );
    },
  );

  if (result != null) return result!;
  return await session.result;
}

class _GpsLoadingDialog extends StatefulWidget {
  final GpsSamplingSession session;
  final String title;
  final void Function(GpsSampleResult) onDone;

  const _GpsLoadingDialog({
    required this.session,
    required this.title,
    required this.onDone,
  });

  @override
  State<_GpsLoadingDialog> createState() => _GpsLoadingDialogState();
}

class _GpsLoadingDialogState extends State<_GpsLoadingDialog> {
  GpsProgress? _last;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    widget.session.progress.listen(
      (p) {
        if (mounted) setState(() => _last = p);
      },
      onError: (_) {},
    );
    widget.session.result.then((r) {
      if (_completed) return;
      _completed = true;
      widget.onDone(r);
    });
  }

  String _fmtDur(Duration d) {
    final s = d.inSeconds;
    return '${s}s';
  }

  Color _statusColor(BuildContext context) {
    final eff = _last?.effectiveAccuracy;
    if (eff == null) return Colors.grey.shade600;
    if (eff <= 5) return Colors.green.shade700;
    if (eff <= 10) return Colors.orange.shade800;
    return Colors.red.shade700;
  }

  @override
  Widget build(BuildContext context) {
    final p = _last;
    final samples = p?.sampleCount ?? 0;
    final bestRaw = p?.bestRawAccuracy;
    final eff = p?.effectiveAccuracy;
    final remaining = p?.remaining ?? Duration.zero;
    final elapsed = p?.elapsed ?? Duration.zero;
    final meets = p?.meetsTarget ?? false;
    final canAcceptNow = samples > 0 && !_completed;

    return AlertDialog(
      title: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(widget.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            samples == 0
                ? 'Menunggu sinyal GPS pertama…'
                : 'Mengumpulkan dan merata-ratakan sinyal GPS.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 14),
          _row('Jumlah sampel', '$samples'),
          _row(
            'Akurasi mentah terbaik',
            bestRaw == null ? '—' : '±${bestRaw.toStringAsFixed(1)} m',
          ),
          _row(
            'Akurasi efektif (rata-rata)',
            eff == null ? '—' : '±${eff.toStringAsFixed(1)} m',
            color: _statusColor(context),
            bold: true,
          ),
          _row(
            'Waktu',
            '${_fmtDur(elapsed)} / sisa ${_fmtDur(remaining)}',
          ),
          const SizedBox(height: 10),
          if (eff != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: meets
                    ? Colors.green.withValues(alpha: 0.10)
                    : (eff <= 15
                        ? Colors.orange.withValues(alpha: 0.10)
                        : Colors.red.withValues(alpha: 0.10)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                meets
                    ? 'Target tercapai (≤5 m). Akan disimpan otomatis.'
                    : (eff <= 15
                        ? 'Cukup baik. Lanjut sampling untuk akurasi lebih baik.'
                        : 'Akurasi masih rendah. Tetap di tempat terbuka.'),
                style: TextStyle(
                  fontSize: 12,
                  color: meets
                      ? Colors.green.shade800
                      : (eff <= 15
                          ? Colors.orange.shade900
                          : Colors.red.shade800),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _completed
              ? null
              : () {
                  widget.session.cancel();
                },
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: canAcceptNow ? () => widget.session.acceptNow() : null,
          child: const Text('Pakai sekarang'),
        ),
      ],
    );
  }

  Widget _row(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience: convert a `GpsSampleResult` into a user-facing snackbar
/// message describing what happened. Returns null if user-facing text isn't
/// useful (i.e. position met target cleanly).
String? gpsResultMessage(GpsSampleResult r) {
  switch (r.failureReason) {
    case GpsFailureReason.serviceDisabled:
      return 'GPS belum aktif. Aktifkan layanan lokasi lalu coba lagi.';
    case GpsFailureReason.permissionDenied:
      return 'Izin lokasi ditolak. Tidak bisa mengambil koordinat.';
    case GpsFailureReason.noSamples:
      return 'Tidak ada sinyal GPS yang bisa diambil. Coba di tempat terbuka.';
    case GpsFailureReason.cancelled:
      if (r.position == null) return 'Pengambilan GPS dibatalkan.';
      return 'Dibatalkan. Memakai sampel terbaik (±${r.effectiveAccuracy?.toStringAsFixed(1) ?? '?'} m).';
    case null:
      break;
  }
  if (r.position == null) {
    return 'Lokasi tidak tersedia.';
  }
  if (!r.meetsTarget && r.effectiveAccuracy != null) {
    return 'Akurasi GPS belum ideal (±${r.effectiveAccuracy!.toStringAsFixed(1)} m, ${r.sampleCount} sampel). Pertimbangkan ulangi di tempat terbuka.';
  }
  return null;
}

