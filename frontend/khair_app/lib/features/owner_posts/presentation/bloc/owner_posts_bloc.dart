import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/owner_post.dart';
import '../../domain/repositories/owner_post_repository.dart';

part 'owner_posts_event.dart';
part 'owner_posts_state.dart';

class OwnerPostsBloc extends Bloc<OwnerPostsEvent, OwnerPostsState> {
  final OwnerPostRepository _repository;

  OwnerPostsBloc(this._repository) : super(const OwnerPostsState()) {
    on<LoadActivePosts>(_onLoadActive);
    on<LoadAllPosts>(_onLoadAll);
    on<CreateOwnerPost>(_onCreate);
    on<UpdateOwnerPost>(_onUpdate);
    on<DeleteOwnerPost>(_onDelete);
  }

  Future<void> _onLoadActive(
      LoadActivePosts event, Emitter<OwnerPostsState> emit) async {
    emit(state.copyWith(status: OwnerPostsStatus.loading));
    try {
      final posts = await _repository.getActivePosts();
      emit(state.copyWith(
          status: OwnerPostsStatus.success, activePosts: posts));
    } catch (e) {
      emit(state.copyWith(
          status: OwnerPostsStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadAll(
      LoadAllPosts event, Emitter<OwnerPostsState> emit) async {
    emit(state.copyWith(status: OwnerPostsStatus.loading));
    try {
      final posts = await _repository.getAllPosts();
      emit(state.copyWith(status: OwnerPostsStatus.success, allPosts: posts));
    } catch (e) {
      emit(state.copyWith(
          status: OwnerPostsStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreate(
      CreateOwnerPost event, Emitter<OwnerPostsState> emit) async {
    emit(state.copyWith(formStatus: OwnerPostsStatus.loading));
    try {
      await _repository.createPost(
        title: event.title,
        shortDescription: event.shortDescription,
        imageUrl: event.imageUrl,
        externalLink: event.externalLink,
        location: event.location,
      );
      emit(state.copyWith(formStatus: OwnerPostsStatus.success));
      add(LoadAllPosts());
    } catch (e) {
      emit(state.copyWith(
          formStatus: OwnerPostsStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdate(
      UpdateOwnerPost event, Emitter<OwnerPostsState> emit) async {
    emit(state.copyWith(formStatus: OwnerPostsStatus.loading));
    try {
      await _repository.updatePost(event.id, event.data);
      emit(state.copyWith(formStatus: OwnerPostsStatus.success));
      add(LoadAllPosts());
    } catch (e) {
      emit(state.copyWith(
          formStatus: OwnerPostsStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onDelete(
      DeleteOwnerPost event, Emitter<OwnerPostsState> emit) async {
    try {
      await _repository.deletePost(event.id);
      add(LoadAllPosts());
    } catch (e) {
      emit(state.copyWith(
          status: OwnerPostsStatus.failure, errorMessage: e.toString()));
    }
  }
}
