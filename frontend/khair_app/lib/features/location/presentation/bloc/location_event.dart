part of 'location_bloc.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

/// Dispatched on app startup to resolve user location
class ResolveLocationEvent extends LocationEvent {}

/// Dispatched to load cached location without API call
class LoadCachedLocationEvent extends LocationEvent {}
