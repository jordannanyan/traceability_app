import 'package:flutter/material.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeMonitoringPaginationBar extends StatelessWidget {
  final bool isID;
  final int page;
  final int pageCount;
  final int total;
  final int pageSize;
  final int pageItemsLength;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final void Function(int) onPageSizeChanged;

  const TreeMonitoringPaginationBar({
    super.key,
    required this.isID,
    required this.page,
    required this.pageCount,
    required this.total,
    required this.pageSize,
    required this.pageItemsLength,
    required this.onPrev,
    required this.onNext,
    required this.onPageSizeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final start =
        total == 0 ? 0 : ((page - 1) * pageSize + 1);
    final end = total == 0
        ? 0
        : (((page - 1) * pageSize) + pageItemsLength);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(
            color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: isID ? 'Sebelumnya' : 'Previous',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${isID ? "Halaman" : "Page"} $page/$pageCount',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isID ? "Menampilkan" : "Showing"} $start-$end ${isID ? "dari" : "of"} $total',
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isID ? 'Berikutnya' : 'Next',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
          const SizedBox(width: 8),
          DropdownButton<int>(
            value: pageSize,
            underline: const SizedBox.shrink(),
            onChanged: (v) {
              if (v == null) return;
              onPageSizeChanged(v);
            },
            items: const [10, 20, 30, 50, 100]
                .map((e) => DropdownMenuItem<int>(
                      value: e,
                      child: Text('$e'),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
