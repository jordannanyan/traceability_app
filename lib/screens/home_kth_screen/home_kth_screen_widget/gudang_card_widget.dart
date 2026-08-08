import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:traceability_app/models/get_warehouse_by_kth_id.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';
import 'package:traceability_app/themes/app_tokens.dart';

class GudangCardRowWithData extends StatelessWidget {
  final GetWarehouseByKthId gudangData;

  /// Language dikirim dari parent agar tidak perlu Obx/GetX di widget ini
  final String language;

  /// Opsional: set true bila aplikasi sedang offline
  final bool isOffline;

  /// Opsional: waktu cache terakhir
  final DateTime? lastCacheTime;

  const GudangCardRowWithData({
    super.key,
    required this.gudangData,
    required this.language,
    this.isOffline = false,
    this.lastCacheTime,
  });

  @override
  Widget build(BuildContext context) {
    final items = gudangData.data ?? const [];

    if (items.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            language == 'id'
                ? 'Tidak ada gudang'
                : 'No warehouses',
            style: ThemeTextStyle.textStyleForthBold.copyWith(
              color: Colors.grey,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 230,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final w = items[index];

          return _GudangCard(
            language: language,
            name: w.warehouseName ?? '-',
            address: w.address ??
                (language == 'id'
                    ? 'Tidak diketahui'
                    : 'Unknown'),
            isOffline: isOffline,
            lastCacheTime: lastCacheTime,
          );
        },
      ),
    );
  }
}

class _GudangCard extends StatelessWidget {
  final String language;
  final String name;
  final String address;

  final bool isOffline;
  final DateTime? lastCacheTime;

  const _GudangCard({
    required this.language,
    required this.name,
    required this.address,
    this.isOffline = false,
    this.lastCacheTime,
  });

  String _formatLastSync(DateTime dt) {
    final locale =
        language == 'id' ? 'id_ID' : 'en_US';

    final d = DateFormat(
      'dd MMM yyyy',
      locale,
    ).format(dt);

    final t = DateFormat('HH:mm').format(dt);

    return '$d • $t';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          SizedBox(
            height: 120,
            width: double.infinity,
            child: Stack(
              children: [
                // Gradient Banner
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ThemeColor.darkestGreen,
                        ThemeColor.darkestGreen.withValues(
                          alpha: 0.78,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.warehouse_rounded,
                      size: 48,
                      color: Colors.white.withValues(
                        alpha: 0.9,
                      ),
                    ),
                  ),
                ),

                // Title Chip
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.9,
                      ),
                      borderRadius:
                          BorderRadius.circular(Radii.xl),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_rounded,
                          size: 14,
                          color: ThemeColor.darkestGreen,
                        ),

                        const SizedBox(width: 6),

                        Text(
                          language == 'id'
                              ? 'Gudang'
                              : 'Warehouse',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: ThemeColor.darkestGreen,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Offline Badge
                if (isOffline)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(
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
                        children: [
                          const Icon(
                            Icons.wifi_off,
                            size: 12,
                            color: Colors.brown,
                          ),

                          const SizedBox(width: 4),

                          Text(
                            'Offline',
                            style:
                                const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ThemeTextStyle
                      .textStyleForthBold
                      .copyWith(
                    fontSize: 16,
                    color: ThemeColor.darkestGreen,
                  ),
                ),

                const SizedBox(height: 8),

                _infoRow(
                  icon: Icons.location_on_outlined,
                  label:
                      language == 'id'
                          ? 'Alamat'
                          : 'Address',
                  value: address,
                ),

                if (lastCacheTime != null) ...[
                  const SizedBox(height: 8),

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
                              _formatLastSync(
                                lastCacheTime!,
                              ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                          overflow:
                              TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '$label:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}