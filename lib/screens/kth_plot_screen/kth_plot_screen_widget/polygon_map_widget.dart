import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';

import 'package:traceability_app/screens/kth_plot_screen/kth_polygon_controller.dart';
import 'package:traceability_app/themes/theme_color.dart';

class KthPolygonMapWidget extends StatelessWidget {
  final KthPolygonController c;

  const KthPolygonMapWidget({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pts = c.points.map((e) => e.latLng).toList();
      return FlutterMap(
        mapController: c.mapController,
        options: MapOptions(
          initialCenter: c.center,
          initialZoom: c.zoom,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.traceability_app',
          ),
          if (pts.length >= 3)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: pts,
                  color: ThemeColor.darkestGreen.withValues(alpha: 0.18),
                  borderColor: ThemeColor.darkestGreen,
                  borderStrokeWidth: 2,
                ),
              ],
            ),
          if (pts.length >= 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: pts,
                  strokeWidth: 3,
                  color: ThemeColor.darkestGreen,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (int i = 0; i < c.points.length; i++)
                Marker(
                  point: c.points[i].latLng,
                  width: 44,
                  height: 44,
                  child: KthPointMarker(
                    idx: i + 1,
                    hasPhoto: c.points[i].hasAnyPhoto,
                  ),
                ),
            ],
          ),
        ],
      );
    });
  }
}

class KthPointMarker extends StatelessWidget {
  final int idx;
  final bool hasPhoto;

  const KthPointMarker({
    super.key,
    required this.idx,
    required this.hasPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: ThemeColor.darkestGreen, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            idx.toString(),
            style: TextStyle(
              color: ThemeColor.darkestGreen,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (hasPhoto)
            Icon(Icons.photo, size: 12, color: ThemeColor.darkestGreen),
        ],
      ),
    );
  }
}
