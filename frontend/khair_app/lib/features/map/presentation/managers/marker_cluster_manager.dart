import 'package:latlong2/latlong.dart';

import '../../domain/models/map_models.dart';

class MarkerClusterManager {
  List<MapClusterNode> buildClusters({
    required List<MapEvent> events,
    required double zoom,
  }) {
    if (events.isEmpty) return const [];

    final cellSize = _gridSizeForZoom(zoom);
    final buckets = <String, List<MapEvent>>{};

    for (final event in events) {
      final row = (event.latitude / cellSize).floor();
      final col = (event.longitude / cellSize).floor();
      final key = '$row:$col';
      buckets.putIfAbsent(key, () => <MapEvent>[]).add(event);
    }

    return buckets.entries.map((entry) {
      final members = entry.value;
      final center = _averagePoint(members);
      return MapClusterNode(
        key: entry.key,
        center: center,
        events: members,
      );
    }).toList();
  }

  double _gridSizeForZoom(double zoom) {
    // Very tight clustering — only merge truly overlapping markers
    if (zoom <= 6) return 0.5;
    if (zoom <= 8) return 0.15;
    if (zoom <= 10) return 0.06;
    if (zoom <= 12) return 0.02;   // ~2km — was 0.16 (~17km)
    if (zoom <= 14) return 0.005;  // ~500m
    if (zoom <= 16) return 0.001;  // ~100m
    return 0.0004;                 // ~40m
  }

  LatLng _averagePoint(List<MapEvent> events) {
    double lat = 0;
    double lng = 0;
    for (final event in events) {
      lat += event.latitude;
      lng += event.longitude;
    }
    return LatLng(lat / events.length, lng / events.length);
  }
}
