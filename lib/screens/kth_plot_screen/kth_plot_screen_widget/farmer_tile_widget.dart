import 'package:flutter/material.dart';

import 'package:traceability_app/models/get_farmers_by_kth_id.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_farmer_list_controller.dart';
import 'package:traceability_app/screens/kth_plot_screen/kth_plot_screen.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class FarmerTile extends StatelessWidget {
  final GetFarmerByKthId farmer;
  final String subtitleText;
  final VoidCallback? onTap;

  const FarmerTile({
    super.key,
    required this.farmer,
    required this.subtitleText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final farmerName = (farmer.farmerName ?? '-').trim();

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ThemeColor.darkestGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_outline,
          color: ThemeColor.darkestGreen,
        ),
      ),
      title: Text(
        farmerName.isEmpty ? '-' : farmerName,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        subtitleText,
        style: const TextStyle(color: Colors.black54),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class FarmerListCard extends StatelessWidget {
  final KthFarmerListController c;
  final List<GetFarmerByKthId> farmers;
  final bool isID;
  final BuildContext ctx;

  const FarmerListCard({
    super.key,
    required this.c,
    required this.farmers,
    required this.isID,
    required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    if (farmers.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        decoration: _cardDeco(),
        child: Center(
          child: Text(
            isID ? 'Tidak ada petani yang cocok' : 'No matching farmers',
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      decoration: _cardDeco(),
      child: ListView.separated(
        separatorBuilder: (_, __) => const Divider(height: 1),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: farmers.length,
        itemBuilder: (_, i) {
          final f = farmers[i];
          final farmerId = f.id;
          final farmerName = (f.farmerName ?? '-').trim();

          return FarmerTile(
            farmer: f,
            subtitleText: c.subtitleFarmer(f),
            onTap: (farmerId == null || farmerId == 0)
                ? null
                : () async {
                    await Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => KthPlotScreen(
                          farmerId: farmerId,
                          farmerName: farmerName,
                        ),
                      ),
                    );
                  },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FarmerCard — individual card used in the redesigned farmer list screen
// ---------------------------------------------------------------------------

class FarmerCard extends StatelessWidget {
  final GetFarmerByKthId farmer;
  final String subtitle;
  final bool isID;
  final VoidCallback? onTap;

  const FarmerCard({
    super.key,
    required this.farmer,
    required this.subtitle,
    required this.isID,
    required this.onTap,
  });

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = (farmer.farmerName ?? '').trim();
    final hp = (farmer.noHp ?? '').trim();
    final nik = (farmer.nik ?? '').trim();
    final addr = (farmer.address ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with initials
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D6B2E), Color(0xFF169843)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _initials(name.isEmpty ? '?' : name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? '-' : name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (hp.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        _InfoRow(icon: Icons.phone_outlined, text: hp),
                      ],
                      if (nik.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _InfoRow(icon: Icons.badge_outlined, text: nik),
                      ],
                      if (addr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        _InfoRow(
                            icon: Icons.location_on_outlined,
                            text: addr,
                            maxLines: 1),
                      ],
                    ],
                  ),
                ),

                // Chevron
                Icon(Icons.chevron_right,
                    color: onTap != null
                        ? Colors.grey.shade400
                        : Colors.grey.shade200),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final int maxLines;

  const _InfoRow(
      {required this.icon, required this.text, this.maxLines = 2});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

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
