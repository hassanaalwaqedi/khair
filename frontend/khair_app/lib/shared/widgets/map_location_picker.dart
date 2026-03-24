import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/services/nominatim_service.dart';

/// Callback when a location is selected on the map.
typedef OnLocationSelected = void Function(
  double latitude,
  double longitude,
  String? address,
  String? city,
  String? country,
  String? countryCode,
);

/// Modern, smooth interactive map location picker.
/// Uses OpenStreetMap + Nominatim (free, no API key).
class MapLocationPicker extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final OnLocationSelected onLocationSelected;
  final String searchHint;
  final String useCurrentLocationLabel;
  final String tapToSelectLabel;
  final String selectedLocationLabel;
  final String searchingLabel;

  const MapLocationPicker({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    required this.onLocationSelected,
    this.searchHint = 'Search for a place...',
    this.useCurrentLocationLabel = 'Use my current location',
    this.tapToSelectLabel = 'Tap on the map to select location',
    this.selectedLocationLabel = 'Selected location',
    this.searchingLabel = 'Searching...',
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker>
    with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  LatLng? _selectedPoint;
  String? _resolvedAddress;
  bool _isSearching = false;
  bool _isLocating = false;
  bool _isResolving = false;
  List<NominatimPlace> _searchResults = [];
  Timer? _debounce;

  late final AnimationController _pinAnimController;
  late final Animation<double> _pinBounce;

  @override
  void initState() {
    super.initState();
    _pinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pinBounce = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pinAnimController, curve: Curves.elasticOut),
    );

    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPoint =
          LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _pinAnimController.forward();
      _reverseGeocode(_selectedPoint!);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pinAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _isResolving = true;
      _searchResults = [];
    });
    _pinAnimController.reset();
    _pinAnimController.forward();
    await _reverseGeocode(point);
  }

  Future<void> _reverseGeocode(LatLng point) async {
    setState(() => _isResolving = true);
    final place =
        await NominatimService.reverseGeocode(point.latitude, point.longitude);

    if (!mounted) return;
    setState(() {
      _isResolving = false;
      _resolvedAddress = place?.shortAddress;
    });

    widget.onLocationSelected(
      point.latitude,
      point.longitude,
      place?.shortAddress ?? place?.displayName,
      place?.city,
      place?.country,
      place?.countryCode,
    );
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);
      final results = await NominatimService.search(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  void _selectSearchResult(NominatimPlace place) {
    final point = LatLng(place.lat, place.lng);
    setState(() {
      _selectedPoint = point;
      _resolvedAddress = place.shortAddress;
      _searchResults = [];
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
    _pinAnimController.reset();
    _pinAnimController.forward();
    _mapController.move(point, 15);

    widget.onLocationSelected(
      place.lat,
      place.lng,
      place.shortAddress,
      place.city,
      place.country,
      place.countryCode,
    );
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) setState(() => _isLocating = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      final point = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() {
        _selectedPoint = point;
        _isLocating = false;
      });
      _pinAnimController.reset();
      _pinAnimController.forward();
      _mapController.move(point, 15);
      await _reverseGeocode(point);
    } catch (_) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Default center: Mecca if no initial point
    final center = _selectedPoint ??
        (widget.initialLatitude != null && widget.initialLongitude != null
            ? LatLng(widget.initialLatitude!, widget.initialLongitude!)
            : const LatLng(24.7136, 46.6753)); // Riyadh

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔍 Search bar
        _buildSearchBar(),
        if (_searchResults.isNotEmpty) _buildSearchResults(),
        const SizedBox(height: 12),

        // 🗺️ Map
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: _selectedPoint != null ? 15 : 5,
                    onTap: _onMapTap,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.khair.khair_app',
                    ),
                    if (_selectedPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedPoint!,
                            width: 50,
                            height: 50,
                            child: AnimatedBuilder(
                              animation: _pinBounce,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 0.5 + (_pinBounce.value * 0.5),
                                  child: child,
                                );
                              },
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: Color(0xFFE53935),
                                    size: 40,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 8,
                                        color: Colors.black38,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),

                // Zoom controls
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      _mapButton(
                        icon: Icons.add,
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _mapButton(
                        icon: Icons.remove,
                        onTap: () => _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tap hint overlay
                if (_selectedPoint == null)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 60,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('👆', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.tapToSelectLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
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
          ),
        ),
        const SizedBox(height: 12),

        // 📍 Use my location button
        _buildCurrentLocationButton(),

        // ✅ Selected location info
        if (_selectedPoint != null) ...[
          const SizedBox(height: 14),
          _buildSelectedInfo(),
        ],
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: widget.searchHint,
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 14,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 12, right: 8),
            child: Text('🔍', style: TextStyle(fontSize: 18)),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 40, minHeight: 0),
          suffixIcon: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white38,
                    ),
                  ),
                )
              : _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close,
                          color: Colors.white.withValues(alpha: 0.4),
                          size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        itemBuilder: (context, index) {
          final place = _searchResults[index];
          return InkWell(
            onTap: () => _selectSearchResult(place),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.city ?? place.displayName.split(',').first,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          place.displayName,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrentLocationButton() {
    return GestureDetector(
      onTap: _isLocating ? null : _useCurrentLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLocating)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.blue,
                ),
              )
            else
              const Text('📌', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              widget.useCurrentLocationLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedInfo() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1B5E20).withValues(alpha: 0.15),
            const Color(0xFF2E7D32).withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedLocationLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (_isResolving)
                  Text(
                    widget.searchingLabel,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Text(
                    _resolvedAddress ?? '${_selectedPoint!.latitude.toStringAsFixed(5)}, ${_selectedPoint!.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }
}
