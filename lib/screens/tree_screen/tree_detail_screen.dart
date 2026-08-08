import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:traceability_app/screens/tree_screen/tree_detail_controller.dart';
import 'package:traceability_app/screens/tree_screen/tree_monitoring_screen.dart';
import 'package:traceability_app/screens/tree_screen/tree_upsert_screen.dart';
import 'package:traceability_app/screens/tree_screen/widgets/tree_location_map.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
/// Storage base for public files (relative -> absolute)
const String _kStorageBaseUrl =
    'https://app.nbsvworldwide.com';

String? _resolvePhotoUrl(String? v) {
  if (v == null) return null;

  String s = v.trim();

  if (s.isEmpty) return null;

  // Jika sudah full URL
  if (s.startsWith('http://') || s.startsWith('https://')) {
    final u = Uri.tryParse(s);

    if (u == null) return s;

    // Replace localhost ke domain production
    if (u.host == 'localhost' || u.host == '127.0.0.1') {
      return Uri(
        scheme: 'https',
        host: 'app.nbsvworldwide.com',
        path: u.path,
      ).toString();
    }

    return s;
  }

  // Hapus slash depan kalau ada
  s = s.replaceFirst(RegExp(r'^/+'), '');

  // Kalau belum ada storage/, tambahkan otomatis
  if (!s.startsWith('storage/')) {
    s = 'storage/$s';
  }

  return '$_kStorageBaseUrl/$s';
}

class TreeDetailScreen extends StatelessWidget {
  final int treeId;
  const TreeDetailScreen({super.key, required this.treeId});

  @override
  Widget build(BuildContext context) {
    final c = Get.put(
      TreeDetailController(treeId: treeId),
      tag: 'detail_$treeId',
    );

    return Obx(() {
      final isID = c.language.value == 'id';
      final isOffline = c.isOfflineView.value;
      final isLoading = c.isLoading.value;
      final tree = c.tree.value;
      final errorMsg = c.error.value;

      return Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            isID ? 'Detail Pohon' : 'Tree Detail',
            style: ThemeTextStyle.textStyleFirstBoldWhite,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: () => c.downloadQr(context),
              tooltip: isID ? 'Unduh QR' : 'Download QR',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: c.load,
              tooltip: isID ? 'Segarkan' : 'Refresh',
            ),
          ],
        ),
        body: () {
          if (isLoading) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(Insets.xl),
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (tree == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Insets.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      errorMsg ??
                          (isID
                              ? 'Data tidak ditemukan'
                              : 'Data not found'),
                      style: ThemeTextStyle
                          .textStyleForthBold
                          .copyWith(color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: c.load,
                      child: Text(isID ? 'Coba Lagi' : 'Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Choose image: latestMonitoring.photoPath -> tree.photoPath
          final lm = tree.latestMonitoring;
          final displayUrl = _resolvePhotoUrl(lm?.photoPath) ??
              _resolvePhotoUrl(tree.photoPath);

          Widget media;
          if (displayUrl != null && displayUrl.isNotEmpty) {
            media = Image.network(
              displayUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image, size: 96),
            );
          } else {
            media = const Icon(Icons.nature, size: 96);
          }

          final qrData = (tree.id ?? '').toString();
          final planted = c.fmtDate(tree.plantingDate);

          final circum = lm?.circumferenceCm;
          final health = lm?.healthStatus ?? '-';
          final hdesc = lm?.healthDesc ?? '-';
          final measuredAt = c.fmtDateTime(lm?.measuredAt);

          final lmLat = lm?.latitude;
          final lmLng = lm?.longitude;
          final lmAcc = lm?.accuracyM;

          final tLat = c.toDoubleFlexible(tree.latitude);
          final tLng = c.toDoubleFlexible(tree.longitude);

          final useLm = c.validCoord(lmLat, lmLng);
          final chosenLat = useLm ? lmLat : tLat;
          final chosenLng = useLm ? lmLng : tLng;
          final hasCoords = c.validCoord(chosenLat, chosenLng);

          final coordSource = useLm
              ? (isID ? 'Monitoring terbaru' : 'Latest monitoring')
              : (isID ? 'Data pohon' : 'Tree record');

          final treeAcc = c.toDoubleFlexible(tree.accuracyM);
          final chosenAcc = useLm ? lmAcc : treeAcc;
          final accLabel = (chosenAcc != null)
              ? (isID
                  ? 'Akurasi: ±${chosenAcc.toStringAsFixed(1)} m'
                  : 'Accuracy: ±${chosenAcc.toStringAsFixed(1)} m')
              : null;

          final plotCode = tree.plot?.plotName ?? '-';
          final farmer = tree.farmer?.farmerName ?? '-';

          return RefreshIndicator(
            onRefresh: c.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                  18, 18, 18, 18 + MediaQuery.viewPaddingOf(context).bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isOffline)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5CC),
                        borderRadius: BorderRadius.circular(Radii.sm),
                        border:
                            Border.all(color: const Color(0xFFFFE08A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isID
                                  ? 'Mode offline: menampilkan data terakhir yang tersimpan.'
                                  : 'Offline mode: showing the last saved data.',
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Media
                  Container(
                    width: double.infinity,
                    decoration: _cardDeco(),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(Radii.md),
                        child: Container(
                          color: Colors.green.withValues(alpha: 0.08),
                          child: Center(child: media),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tree.species ?? '-',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${isID ? 'Ditanam' : 'Planted'}: $planted'),

                  const SizedBox(height: 16),

                  // Attributes + latest monitoring
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Insets.lg),
                    decoration: _cardDeco(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isID
                              ? 'Atribut & Monitoring Terakhir'
                              : 'Attributes & Latest Monitoring',
                          style: ThemeTextStyle.textStyleFirstBold,
                        ),
                        const SizedBox(height: 12),
                        _infoRow(Icons.map,
                            isID ? 'Kode Lahan' : 'Plot Code', plotCode),
                        _infoRow(Icons.person,
                            isID ? 'Nama Petani' : 'Farmer Name', farmer),
                        const Divider(height: 20),
                        _infoRow(
                            Icons.event_available,
                            isID ? 'Waktu Ukur' : 'Measured At',
                            measuredAt),
                        _infoRow(
                            Icons.straighten,
                            isID
                                ? 'Keliling (cm)'
                                : 'Circumference (cm)',
                            (circum ?? '-').toString()),
                        _infoRow(
                            Icons.local_hospital,
                            isID ? 'Kesehatan' : 'Health',
                            health),
                        const SizedBox(height: 8),
                        Text(
                          isID
                              ? 'Deskripsi Kesehatan'
                              : 'Health Description',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(hdesc,
                            style: const TextStyle(
                                color: Colors.black87)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Coordinates + Map
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Insets.lg),
                    decoration: _cardDeco(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isID ? 'Lokasi Pohon' : 'Tree Location',
                          style: ThemeTextStyle.textStyleFirstBold,
                        ),
                        const SizedBox(height: 8),
                        _infoRow(
                          Icons.location_on,
                          isID ? 'Koordinat' : 'Coordinates',
                          hasCoords
                              ? 'Lat: ${chosenLat!.toStringAsFixed(6)}, Lng: ${chosenLng!.toStringAsFixed(6)}'
                              : '-',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${isID ? 'Sumber: ' : 'Source: '}$coordSource',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.black54),
                        ),
                        if (accLabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            accLabel,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (hasCoords)
                          TreeLocationMap(
                            lat: chosenLat!,
                            lng: chosenLng!,
                            height: 220,
                            title: isID
                                ? 'Peta Lokasi Pohon'
                                : 'Tree Location Map',
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(Insets.md),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(Radii.sm),
                              border: Border.all(
                                  color: Colors.amber.shade300),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.warning_amber,
                                    color: Colors.amber.shade700),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isID
                                        ? 'Koordinat pohon belum tersedia.'
                                        : 'Tree coordinates are not available.',
                                    style: TextStyle(
                                      color: Colors.amber.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // QR + download button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Insets.lg),
                    decoration: _cardDeco(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isID ? 'QR Pohon' : 'Tree QR',
                          style: ThemeTextStyle.textStyleFirstBold,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: RepaintBoundary(
                            key: c.qrKey,
                            child: Container(
                              padding: const EdgeInsets.all(Insets.md),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(Radii.md),
                                border:
                                    Border.all(color: Colors.black12),
                              ),
                              child: QrImageView(
                                data: qrData,
                                version: QrVersions.auto,
                                size: 220,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Payload: $qrData',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.icon(
                              onPressed: () => c.downloadQr(context),
                              icon: const Icon(Icons.download),
                              label: Text(
                                  isID ? 'Unduh QR' : 'Download QR'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.history),
                          label: Text(
                            isID
                                ? 'Riwayat Monitoring'
                                : 'Monitoring History',
                          ),
                          onPressed: () async {
                            final id = tree.id;
                            if (id == null) return;
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TreeMonitoringScreen(treeId: id),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.edit),
                          label:
                              Text(isID ? 'Ubah Pohon' : 'Edit Tree'),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TreeUpsertScreen(treeId: tree.id),
                              ),
                            );
                            if (context.mounted) c.load();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }(),
      );
    });
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.10),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      );
}

Widget _infoRow(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.black87)),
        ),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: Colors.black54)),
      ],
    ),
  );
}
