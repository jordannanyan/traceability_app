import 'package:flutter/material.dart';

import 'package:traceability_app/models/get_warehouse_by_kth_id.dart' as wh;
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class GudangDetailSheet extends StatelessWidget {
  final wh.Datum item;
  final bool isID;
  final String createdAt;

  const GudangDetailSheet({
    super.key,
    required this.item,
    required this.isID,
    required this.createdAt,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      isID ? 'Detail Gudang' : 'Warehouse Details',
                      style: ThemeTextStyle.textStyleForthBold.copyWith(
                            fontSize: 24,
                            color: ThemeColor.darkestGreen,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _DetailCard(
                      title: isID ? 'Informasi Gudang' : 'Warehouse Info',
                      children: [
                        _DetailRow(label: 'ID', value: '${item.id ?? '-'}'),
                        _DetailRow(
                          label: isID ? 'Nama' : 'Name',
                          value: item.warehouseName ?? '-',
                        ),
                        _DetailRow(
                          label: isID ? 'Alamat' : 'Address',
                          value: item.address ?? '-',
                        ),
                        _DetailRow(
                          label: isID ? 'Dibuat' : 'Created',
                          value: createdAt,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailCard(
                      title: 'Partner',
                      children: [
                        _DetailRow(
                          label: isID ? 'Nama Partner' : 'Partner Name',
                          value: item.kth?.kthName ?? '-',
                        ),
                        _DetailRow(
                          label: isID ? 'Alamat Partner' : 'Partner Address',
                          value: item.kth?.address ?? '-',
                        ),
                        _DetailRow(
                          label: isID ? 'Kabupaten' : 'Regency',
                          value: item.kth?.regency ?? '-',
                        ),
                        _DetailRow(
                          label: isID ? 'Periode Kemitraan' : 'Partnership Period',
                          value: '${item.kth?.partnershipPeriod ?? '-'}',
                        ),
                        _DetailRow(
                          label: 'Username',
                          value: item.kth?.username ?? '-',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: ThemeColor.darkestGreen,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
