import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/datasources/sheikh_remote_datasource.dart';
import '../../domain/entities/sheikh_profile.dart';

// ─── Events ────────────────────────────────────────

abstract class SheikhEvent extends Equatable {
  const SheikhEvent();
  @override
  List<Object?> get props => [];
}

class LoadSheikhs extends SheikhEvent {
  const LoadSheikhs();
}

// ─── State ─────────────────────────────────────────

enum SheikhStatus { initial, loading, success, failure }

class SheikhState extends Equatable {
  final SheikhStatus status;
  final List<SheikhProfile> sheikhs;
  final String? errorMessage;

  const SheikhState({
    this.status = SheikhStatus.initial,
    this.sheikhs = const [],
    this.errorMessage,
  });

  SheikhState copyWith({
    SheikhStatus? status,
    List<SheikhProfile>? sheikhs,
    String? errorMessage,
  }) {
    return SheikhState(
      status: status ?? this.status,
      sheikhs: sheikhs ?? this.sheikhs,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, sheikhs, errorMessage];
}

// ─── Bloc ──────────────────────────────────────────

class SheikhBloc extends Bloc<SheikhEvent, SheikhState> {
  final SheikhRemoteDataSource _dataSource;

  SheikhBloc(this._dataSource) : super(const SheikhState()) {
    on<LoadSheikhs>(_onLoadSheikhs);
  }

  Future<void> _onLoadSheikhs(
    LoadSheikhs event,
    Emitter<SheikhState> emit,
  ) async {
    emit(state.copyWith(status: SheikhStatus.loading));
    try {
      final sheikhs = await _dataSource.getSheikhs();
      emit(state.copyWith(
        status: SheikhStatus.success,
        sheikhs: sheikhs,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SheikhStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }
}
