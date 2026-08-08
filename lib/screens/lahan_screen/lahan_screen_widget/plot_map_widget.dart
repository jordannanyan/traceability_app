import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:traceability_app/themes/theme_color.dart';
import 'package:traceability_app/models/get_plot_by_farmer_id.dart';

import 'package:traceability_app/themes/app_tokens.dart';
enum PlotMapMode { marker, polygon }

class PlotMapFlutterMap extends StatefulWidget {
  final List<Datum> plots;
  final double height;
  final void Function(Datum plot)? onMarkerTap;
  final String title;

  const PlotMapFlutterMap({
    super.key,
    required this.plots,
    this.height = 200,
    this.onMarkerTap,
    this.title = 'Peta Lahan',
  });

  @override
  State<PlotMapFlutterMap> createState() => _PlotMapFlutterMapState();
}

class _PlotMapFlutterMapState extends State<PlotMapFlutterMap> {
  final MapController _mapController = MapController();
  late final List<_MarkerData> _markers;
  int? _selectedMarkerIndex;

  PlotMapMode _mode = PlotMapMode.marker;

  static const _fallbackCenter = LatLng(-2.5, 118.0);
  static const _fallbackZoom = 4.5;

  @override
  void initState() {
    super.initState();

    _markers = widget.plots
        .map((d) {
          final ll = _parseLatLng(d.latitude, d.longitude);
          return ll == null ? null : _MarkerData(d, ll);
        })
        .whereType<_MarkerData>()
        .toList();

    if (_markers.isNotEmpty) _selectedMarkerIndex = 0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitAllMarkersOrFallback(animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant PlotMapFlutterMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.plots != widget.plots) {
      final newMarkers = widget.plots
          .map((d) {
            final ll = _parseLatLng(d.latitude, d.longitude);
            return ll == null ? null : _MarkerData(d, ll);
          })
          .whereType<_MarkerData>()
          .toList();

      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
        _selectedMarkerIndex = _markers.isNotEmpty ? 0 : null;

        // jika mode polygon tapi sekarang tidak ada polygon, balik ke marker
        if (_mode == PlotMapMode.polygon && !_hasAnyPolygon(widget.plots)) {
          _mode = PlotMapMode.marker;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitAllMarkersOrFallback(animated: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final init = _initialView();
    final hasPoly = _hasAnyPolygon(widget.plots);

    final polyItems = hasPoly && _mode == PlotMapMode.polygon
        ? _buildPolygonOverlays(widget.plots)
        : const <_PolyOverlay>[];

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
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
              initialCenter: init.$1,
              initialZoom: init.$2,
              minZoom: 2,
              maxZoom: 18,
              cameraConstraint: CameraConstraint.contain(
                bounds: LatLngBounds(
                  const LatLng(-85, -180),
                  const LatLng(85, 180),
                ),
              ),
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.traceability.app',
                maxNativeZoom: 18,
                maxZoom: 18,
                minZoom: 2,
                tileDimension: 256,
                errorTileCallback: (tile, error, stack) {
                  debugPrint('Tile error ${tile.coordinates}: $error');
                },
              ),

              // Polygon overlay (mode polygon)
              if (polyItems.isNotEmpty)
                PolygonLayer(
                  polygons: polyItems.map((p) {
                    return Polygon(
                      points: p.points,
                      color: ThemeColor.darkestGreen.withValues(alpha: 0.14),
                      borderColor: ThemeColor.darkestGreen.withValues(alpha: 0.95),
                      borderStrokeWidth: 2,
                    );
                  }).toList(),
                ),

              if (_markers.isNotEmpty)
                MarkerLayer(
                  markers: _markers.asMap().entries.map((entry) {
                    final i = entry.key;
                    final m = entry.value;
                    final selected = _selectedMarkerIndex == i;
                    final double w = selected ? 96 : 36;
                    final double h = selected ? 84 : 36;
                    return Marker(
                      point: m.point,
                      width: w,
                      height: h,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedMarkerIndex = i);
                          widget.onMarkerTap?.call(m.plot);
                        },
                        child: _markerWidget(m, selected),
                      ),
                    );
                  }).toList(),
                ),

              RichAttributionWidget(
                attributions: const [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // === Top-right: Title chip + popup icon (kecil) ===
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 16, color: ThemeColor.darkestGreen),
                      const SizedBox(width: 6),
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

                const SizedBox(width: 8),

                // Popup mode icon (only if polygon exists)
                if (hasPoly)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<PlotMapMode>(
                      tooltip: 'Mode peta',
                      onSelected: (m) => setState(() => _mode = m),
                      itemBuilder: (ctx) => const [
                        PopupMenuItem(
                          value: PlotMapMode.marker,
                          child: Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Marker'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: PlotMapMode.polygon,
                          child: Row(
                            children: [
                              Icon(Icons.polyline, size: 18),
                              SizedBox(width: 10),
                              Text('Polygon'),
                            ],
                          ),
                        ),
                      ],
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          _mode == PlotMapMode.marker ? Icons.location_on_outlined : Icons.polyline,
                          size: 20,
                          color: ThemeColor.darkestGreen,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Recenter button
          Positioned(
            bottom: 12,
            right: 12,
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
                onPressed: () => _fitAllMarkersOrFallback(animated: true),
                icon: const Icon(Icons.my_location, color: Colors.white, size: 20),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
            ),
          ),

          if (_markers.isEmpty)
            Positioned(
              top: 60,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(Insets.md),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tidak ada koordinat lahan yang valid untuk ditampilkan',
                        style: TextStyle(
                          color: Colors.amber.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  (LatLng, double) _initialView() {
    if (_markers.isEmpty) return (_fallbackCenter, _fallbackZoom);
    if (_markers.length == 1) return (_markers.first.point, 13.0);

    final lat = _markers.map((m) => m.point.latitude).reduce((a, b) => a + b) / _markers.length;
    final lng = _markers.map((m) => m.point.longitude).reduce((a, b) => a + b) / _markers.length;
    final center = _isValidLatLng(LatLng(lat, lng)) ? LatLng(lat, lng) : _fallbackCenter;
    return (center, 10.0);
  }

  void _fitAllMarkersOrFallback({required bool animated}) {
    if (_markers.isEmpty) {
      _mapController.move(_fallbackCenter, _fallbackZoom);
      return;
    }
    if (_markers.length == 1) {
      _mapController.move(_markers.first.point, 13.0);
      return;
    }

    try {
      final bounds = LatLngBounds.fromPoints(_markers.map((m) => m.point).toList());
      final fitted = CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      ).fit(_mapController.camera);

      _mapController.move(fitted.center, fitted.zoom);
    } catch (_) {
      _mapController.move(_fallbackCenter, _fallbackZoom);
    }
  }

  LatLng? _parseLatLng(String? lat, String? lng) {
    if (lat == null || lng == null || lat.trim().isEmpty || lng.trim().isEmpty) return null;
    try {
      final la = double.parse(lat.trim().replaceAll(',', '.'));
      final lo = double.parse(lng.trim().replaceAll(',', '.'));
      if (!la.isFinite || !lo.isFinite) return null;
      if (la < -90 || la > 90 || lo < -180 || lo > 180) return null;
      if (la == 0.0 && lo == 0.0) return null;
      return LatLng(la, lo);
    } catch (_) {
      return null;
    }
  }

  bool _isValidLatLng(LatLng p) =>
      p.latitude.isFinite &&
      p.longitude.isFinite &&
      p.latitude >= -90 &&
      p.latitude <= 90 &&
      p.longitude >= -180 &&
      p.longitude <= 180;

  // ===== polygon helpers =====
  bool _hasAnyPolygon(List<Datum> plots) {
    for (final d in plots) {
      // 🔧 kalau field kamu bukan polygonWkt, ganti di sini:
      final s = (d.polygonWkt ?? '').toString().trim();
      if (s.isNotEmpty && _parseWktPolygon(s).length >= 3) return true;
    }
    return false;
  }

  List<_PolyOverlay> _buildPolygonOverlays(List<Datum> plots) {
    final out = <_PolyOverlay>[];
    for (final d in plots) {
      // 🔧 kalau field kamu bukan polygonWkt, ganti di sini:
      final wkt = (d.polygonWkt ?? '').toString().trim();
      if (wkt.isEmpty) continue;
      final pts = _parseWktPolygon(wkt);
      if (pts.length < 3) continue;
      out.add(_PolyOverlay(plot: d, points: pts));
    }
    return out;
  }

  List<LatLng> _parseWktPolygon(String wkt) {
    final s = wkt.trim();
    if (s.isEmpty) return <LatLng>[];

    final up = s.toUpperCase();
    if (!up.startsWith('POLYGON((') || !up.endsWith('))')) return <LatLng>[];

    final inner = s.substring(s.indexOf('((') + 2, s.lastIndexOf('))'));
    final parts = inner.split(',');

    final pts = <LatLng>[];
    for (final p in parts) {
      final t = p.trim().split(RegExp(r'\s+'));
      if (t.length < 2) continue;

      final lng = _tryParseDouble(t[0]);
      final lat = _tryParseDouble(t[1]);
      if (lat == null || lng == null) continue;

      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      if (lat == 0.0 && lng == 0.0) continue;

      pts.add(LatLng(lat, lng));
    }

    if (pts.length >= 2 && _sameLatLng(pts.first, pts.last)) {
      pts.removeLast();
    }
    return pts;
  }

  double? _tryParseDouble(String s) {
    final x = s.trim().replaceAll(',', '.');
    return double.tryParse(x);
  }

  bool _sameLatLng(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 1e-10 &&
        (a.longitude - b.longitude).abs() < 1e-10;
  }

  Widget _markerWidget(_MarkerData m, bool selected) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: Icon(
            Icons.location_on,
            size: selected ? 30 : 24,
            color: selected ? Colors.red.shade600 : ThemeColor.darkestGreen,
          ),
        ),
        if (selected) ...[
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              child: Text(
                m.plot.plotName ?? 'Unknown',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ThemeColor.darkestGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MarkerData {
  final Datum plot;
  final LatLng point;
  _MarkerData(this.plot, this.point);
}

class _PolyOverlay {
  final Datum plot;
  final List<LatLng> points;
  _PolyOverlay({required this.plot, required this.points});
}
