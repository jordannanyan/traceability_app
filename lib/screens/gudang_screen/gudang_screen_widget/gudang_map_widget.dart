import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:traceability_app/themes/theme_color.dart';

import 'package:traceability_app/themes/app_tokens.dart';
class GudangMapWidget extends StatefulWidget {
  final List<LatLng> markerLocations;
  final LatLng mapCenter;

  const GudangMapWidget({
    super.key,
    required this.markerLocations,
    required this.mapCenter,
  });

  @override
  State<GudangMapWidget> createState() => _GudangMapWidgetState();
}

class _GudangMapWidgetState extends State<GudangMapWidget> {
  final MapController _mapController = MapController(); // MapController to control the map
  int? selectedMarkerIndex;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 400,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: widget.mapCenter,
                initialZoom: 13.0,
                onTap: (_, __) => setState(() => selectedMarkerIndex = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                MarkerLayer(
                  markers: List.generate(
                    widget.markerLocations.length,
                    (index) => Marker(
                      width: selectedMarkerIndex == index ? 200.0 : 80.0,
                      height: 120.0,
                      point: widget.markerLocations[index],
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() {
                              selectedMarkerIndex = selectedMarkerIndex == index ? null : index;
                            }),
                            child: Icon(
                              Icons.location_on,
                              size: 40,
                              color: ThemeColor.darkestGreen,
                            ),
                          ),
                          if (selectedMarkerIndex == index)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'Gudang ${index + 1}',
                                style: TextStyle(
                                  color: ThemeColor.darkestGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () {
              _mapController.move(widget.mapCenter, 13.0); // Recenter map to initial center and zoom
            },
            backgroundColor: ThemeColor.darkestGreen,
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ),
      ],
    );
  }
}
