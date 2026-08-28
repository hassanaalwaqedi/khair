import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../domain/entities/location_entity.dart';
import '../../domain/usecases/resolve_location_usecase.dart';

part 'location_event.dart';
part 'location_state.dart';

class LocationBloc extends Bloc<LocationEvent, LocationState> {
  final ResolveLocationUseCase _resolveLocationUseCase;

  LocationBloc(this._resolveLocationUseCase) : super(const LocationInitial()) {
    on<ResolveLocationEvent>(_onResolveLocation);
    on<LoadCachedLocationEvent>(_onLoadCachedLocation);
    on<RefreshAuthorizedLocationEvent>(_onRefreshAuthorizedLocation);
  }

  Future<void> _onLoadCachedLocation(
    LoadCachedLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    final cached = await _resolveLocationUseCase.getCachedLocation();
    if (cached != null) {
      emit(LocationLoaded(cached));
    }
  }

  Future<void> _onResolveLocation(
    ResolveLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    // First, try to emit cached location for instant display
    final cached = await _resolveLocationUseCase.getCachedLocation();
    if (cached != null) {
      emit(LocationLoaded(cached));
    } else {
      emit(const LocationLoading());
    }

    // Then resolve fresh location
    double? lat;
    double? lng;

    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        // Check permission
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          // Get current position
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 10),
            ),
          );
          lat = position.latitude;
          lng = position.longitude;
        }
      }
    } catch (_) {
      // GPS failed — will use IP fallback (no lat/lng sent)
    }

    // Call backend to resolve location
    final result = await _resolveLocationUseCase(
      latitude: lat,
      longitude: lng,
    );

    result.fold(
      (failure) {
        // If we already have cached location, keep showing it
        if (cached == null) {
          emit(LocationError(failure.message));
        }
      },
      (location) {
        emit(LocationLoaded(location));
        // Cache the resolved location for next startup
        _resolveLocationUseCase.cacheLocation(location);
      },
    );
  }

  Future<void> _onRefreshAuthorizedLocation(
    RefreshAuthorizedLocationEvent event,
    Emitter<LocationState> emit,
  ) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final result = await _resolveLocationUseCase(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      result.fold((_) {}, (location) {
        emit(LocationLoaded(location));
        _resolveLocationUseCase.cacheLocation(location);
      });
    } catch (_) {
      // Cached location remains usable when GPS is unavailable.
    }
  }
}
