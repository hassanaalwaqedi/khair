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
    if (zoom <= 6) return 1.2;
    if (zoom <= 8) return 0.7;
    if (zoom <= 10) return 0.35;
    if (zoom <= 12) return 0.16;
    if (zoom <= 14) return 0.08;
    if (zoom <= 16) return 0.03;
    return 0.012;
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
