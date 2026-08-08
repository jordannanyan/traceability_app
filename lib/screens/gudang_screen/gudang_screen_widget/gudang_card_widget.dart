import 'package:flutter/material.dart';

import 'package:traceability_app/models/api/pending_outbox.dart';
import 'package:traceability_app/models/get_warehouse_by_kth_id.dart' as wh;
import 'package:traceability_app/screens/widgets/pending_sync_badge.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/themes/theme_text.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class GudangCard extends StatelessWidget {
  final wh.Datum item;
  final bool isID;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  /// Non-null when this warehouse has an edit still sitting in the outbox.
  final PendingOpKind? pendingKind;

  const GudangCard({
    super.key,
    required this.item,
    required this.isID,
    required this.onTap,
    required this.onEdit,
    this.pendingKind,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.lg),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              gradient: LinearGradient(
                colors: [Colors.white, Colors.grey.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.1),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(
                    item: item,
                    isID: isID,
                    pendingKind: pendingKind,
                  ),
                  const SizedBox(height: 16),
                  const _GradientDivider(),
                  const SizedBox(height: 16),
                  _InfoSection(
                    title: isID ? 'Informasi Gudang' : 'Warehouse Info',
                    children: [
                      _InfoRow(
                        icon: Icons.warehouse,
                        label: isID ? 'Nama Gudang' : 'Name',
                        value: item.warehouseName ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.location_on,
                        label: isID ? 'Alamat' : 'Address',
                        value: item.address ?? '-',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _InfoSection(
                    title: 'Partner',
                    children: [
                      _InfoRow(
                        icon: Icons.group,
                        label: isID ? 'Nama Partner' : 'Partner Name',
                        value: item.kth?.kthName ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.place,
                        label: isID ? 'Alamat Partner' : 'Partner Address',
                        value: item.kth?.address ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.domain,
                        label: isID ? 'Kabupaten' : 'Regency',
                        value: item.kth?.regency ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.calendar_month,
                        label: isID ? 'Periode Kemitraan' : 'Partnership Period',
                        value: '${item.kth?.partnershipPeriod ?? '-'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ActionButtons(isID: isID, onEdit: onEdit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final wh.Datum item;
  final bool isID;
  final PendingOpKind? pendingKind;

  const _CardHeader({
    required this.item,
    required this.isID,
    this.pendingKind,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(Insets.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ThemeColor.darkestGreen,
                ThemeColor.darkestGreen.withValues(alpha: 0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: [
              BoxShadow(
                color: ThemeColor.darkestGreen.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.warehouse, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.warehouseName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ThemeTextStyle.textStyleForthBold.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: ThemeColor.darkestGreen,
                          ),
                    ),
                  ),
                  if (pendingKind != null) ...[
                    const SizedBox(width: Insets.sm),
                    PendingSyncBadge(
                      kind: pendingKind!,
                      isID: isID,
                      compact: true,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isID ? 'Aktif' : 'Active',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
      ],
    );
  }
}

class _GradientDivider extends StatelessWidget {
  const _GradientDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Colors.grey.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: ThemeColor.darkestGreen,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        ...children.map(
          (child) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ThemeColor.darkestGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: ThemeColor.darkestGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: ThemeTextStyle.textStyleForthBold.copyWith(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
              textAlign: TextAlign.right,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool isID;
  final VoidCallback onEdit;

  const _ActionButtons({required this.isID, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.settings_outlined, size: 16),
            label: Text(
              isID ? 'Edit' : 'Edit',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColor.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }
}
