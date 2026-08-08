// lib/screens/tree_screen/widgets/tree_location_map.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class TreeLocationMap extends StatefulWidget {
  final double lat;
  final double lng;
  final double height;
  final String title;

  const TreeLocationMap({
    super.key,
    required this.lat,
    required this.lng,
    this.height = 220,
    this.title = 'Tree Location Map',
  });

  @override
  State<TreeLocationMap> createState() => _TreeLocationMapState();
}

class _TreeLocationMapState extends State<TreeLocationMap> {
  final MapController _mapController = MapController();

  static const _fallbackCenter = LatLng(-2.5, 118.0);
  static const _fallbackZoom = 4.5;

  // Samakan zoom agar tidak “loncat”
  static const double _pointZoom = 16.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _moveToPoint());
  }

  @override
  void didUpdateWidget(covariant TreeLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Jika koordinat berubah, auto move
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _moveToPoint());
    }
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? safe = _safeLatLng(widget.lat, widget.lng);
    final LatLng point = safe ?? _fallbackCenter;

    final initCenter = point;
    final initZoom = safe != null ? _pointZoom : _fallbackZoom;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initCenter,
              initialZoom: initZoom,
              minZoom: 2,
              maxZoom: 19,
              interactionOptions:
                  const InteractionOptions(flags: InteractiveFlag.all),
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-85, -180),
                  const LatLng(85, 180),
                ),
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.traceability.app',
                maxNativeZoom: 18,
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: point,
                    width: 44,
                    height: 44,
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        size: 32,
                        color: ThemeColor.darkestGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // Title chip
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined,
                      size: 16, color: ThemeColor.darkestGreen),
                  const SizedBox(width: 4),
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ThemeColor.darkestGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recenter button
          Positioned(
            bottom: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                color: ThemeColor.darkestGreen,
                borderRadius: BorderRadius.circular(Radii.xl),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon:
                    const Icon(Icons.my_location, color: Colors.white, size: 20),
                onPressed: _moveToPoint,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _moveToPoint() {
    final p = _safeLatLng(widget.lat, widget.lng);
    if (p == null) {
      _mapController.move(_fallbackCenter, _fallbackZoom);
      return;
    }

    // Offset sedikit ke atas supaya marker tidak ketutup tombol bawah
    // Ini offset kecil, aman untuk zoom 16.
    final offsetLat = p.latitude + 0.0007; // kira-kira puluhan meter
    final adjusted = LatLng(offsetLat, p.longitude);

    _mapController.move(adjusted, _pointZoom);
  }

  LatLng? _safeLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    if (lat == 0.0 && lng == 0.0) return null;
    return LatLng(lat, lng);
  }
}
