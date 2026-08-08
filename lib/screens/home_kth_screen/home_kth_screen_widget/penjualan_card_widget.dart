import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traceability_app/models/get_selling_by_kth_id.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/themes/app_tokens.dart';

class PenjualanCardColumn extends StatelessWidget {
  final GetSellingByKthId penjualanData;

  /// Language dikirim dari parent agar tidak perlu Obx di widget ini
  final String language;

  /// Tampilkan badge "Offline" di kartu ketika data berasal dari cache/offline.
  final bool isOffline;

  /// Waktu sinkronisasi terakhir (cache). Ditampilkan kecil di tiap kartu.
  final DateTime? lastCacheTime;

  const PenjualanCardColumn({
    super.key,
    required this.penjualanData,
    required this.language,
    this.isOffline = false,
    this.lastCacheTime,
  });

  @override
  Widget build(BuildContext context) {
    final items = penjualanData.data ?? const <Datum>[];

    if (items.isEmpty) {
      final text = isOffline && lastCacheTime == null
          ? (language == 'id'
              ? 'Tidak ada data penjualan (offline, belum ada cache)'
              : 'No sales data (offline, no cache yet)')
          : (language == 'id'
              ? 'Tidak ada data penjualan tersedia'
              : 'No sales data available');

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final penjualan = items[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: _buildPenjualanCard(penjualan),
        );
      },
    );
  }

  Widget _buildPenjualanCard(Datum? p) {
    final lastSyncText = (lastCacheTime != null)
        ? _formatLastSync(lastCacheTime!)
        : null;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    icon: Icons.person,
                    label: 'Offtaker',
                    value: p?.offTaker?.offtakerName ?? '-',
                  ),

                  const SizedBox(height: 12),

                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label:
                        language == 'id' ? 'Tanggal Jual' : 'Sale Date',
                    value: _formatDate(p?.date),
                  ),

                  const SizedBox(height: 12),

                  _buildInfoRow(
                    icon: Icons.grain,
                    label: language == 'id'
                        ? 'Jenis Komoditas'
                        : 'Coffee Type',
                    value:
                        p?.commodity?.commoditiesName ?? 'Unknown',
                  ),

                  const SizedBox(height: 12),

                  _buildInfoRow(
                    icon: Icons.scale_outlined,
                    label: language == 'id'
                        ? 'Jumlah Penjualan'
                        : 'Sales Quantity',
                    value:
                        '${_safeNum(p?.quantity)?.toStringAsFixed(0) ?? '0'} kg',
                  ),

                  const SizedBox(height: 12),

                  _buildInfoRow(
                    icon: Icons.monetization_on_outlined,
                    label:
                        language == 'id' ? 'Total Harga' : 'Total Price',
                    value: _formatRupiah(
                      _parseNum(p?.totalPrice),
                    ),
                  ),

                  if (lastSyncText != null) ...[
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),

                        const SizedBox(width: 6),

                        Expanded(
                          child: Text(
                            (language == 'id'
                                    ? 'Terakhir sinkron: '
                                    : 'Last sync: ') +
                                lastSyncText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Badge Offline
            if (isOffline)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius:
                        BorderRadius.circular(Radii.md),
                    border: Border.all(
                      color: Colors.amber.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.wifi_off,
                        size: 12,
                        color: Colors.brown,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Offline',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconBadge(icon: icon),

        const SizedBox(width: 10),

        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style:
                      ThemeTextStyle.textStyleForthBold.copyWith(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextSpan(
                  text: value,
                  style:
                      ThemeTextStyle.textStyleForthBold.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Helpers
  // --------------------------------------------------------------------------

  String _formatDate(DateTime? date) {
    if (date == null) {
      return language == 'id'
          ? 'Tidak Diketahui'
          : 'Unknown';
    }

    final locale = language == 'id'
        ? 'id_ID'
        : 'en_US';

    return DateFormat(
      'dd MMM yyyy',
      locale,
    ).format(date);
  }

  String _formatLastSync(DateTime dt) {
    final locale = language == 'id'
        ? 'id_ID'
        : 'en_US';

    final d = DateFormat(
      'dd MMM yyyy',
      locale,
    ).format(dt);

    final t = DateFormat(
      'HH:mm',
      locale,
    ).format(dt);

    return '$d • $t';
  }

  String _formatRupiah(num? n) {
    final v = n ?? 0;

    final f = NumberFormat(
      '#,###',
      'id_ID',
    );

    return 'Rp. ${f.format(v)}';
  }

  num? _parseNum(dynamic v) {
    if (v == null) return null;

    if (v is num) return v;

    final s = v.toString().trim();

    if (s.isEmpty) return null;

    final normalized = s.contains(',')
        ? s.replaceAll('.', '').replaceAll(',', '.')
        : s;

    return num.tryParse(normalized);
  }

  num? _safeNum(num? v) => v;
}

class _IconBadge extends StatelessWidget {
  final IconData icon;

  const _IconBadge({
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade900.withValues(alpha: 0.10),
            Colors.green.shade900.withValues(alpha: 0.06),
          ],
        ),
        border: Border.all(
          color:
              Colors.green.shade900.withValues(alpha: 0.18),
        ),
      ),
      child: Icon(
        icon,
        size: 16,
        color: Colors.green.shade900,
      ),
    );
  }
}