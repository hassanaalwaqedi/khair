import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../network/auth_interceptor.dart';
import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/data/datasources/registration_datasource.dart';
import '../../features/auth/presentation/bloc/registration_bloc.dart';
import '../../features/events/data/datasources/events_remote_datasource.dart';
import '../../features/events/data/repositories/events_repository_impl.dart';
import '../../features/events/domain/repositories/events_repository.dart';
import '../../features/events/presentation/bloc/events_bloc.dart';
import '../../features/organizer/data/datasources/organizer_remote_datasource.dart';
import '../../features/organizer/data/repositories/organizer_repository_impl.dart';
import '../../features/organizer/domain/repositories/organizer_repository.dart';
import '../../features/organizer/presentation/bloc/organizer_bloc.dart';
import '../../features/organizer/presentation/cubit/create_event_cubit.dart';
import '../../features/admin/data/datasources/admin_remote_datasource.dart';
import '../../features/admin/data/repositories/admin_repository_impl.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/admin/presentation/bloc/admin_bloc.dart';
import '../../features/location/data/datasource/location_remote_datasource.dart';
import '../../features/location/data/repository/location_repository_impl.dart';
import '../../features/location/domain/repository/location_repository.dart';
import '../../features/location/domain/usecases/resolve_location_usecase.dart';
import '../../features/location/presentation/bloc/location_bloc.dart';
import '../../features/ai/data/ai_remote_datasource.dart';
import '../../features/ai/presentation/bloc/ai_bloc.dart';
import '../../features/map/data/services/geo_service.dart';
import '../../features/map/presentation/managers/map_state_manager.dart';
import '../../features/map/presentation/managers/marker_cluster_manager.dart';
import '../../features/spiritual_quotes/data/datasources/spiritual_quotes_remote_datasource.dart';
import '../../features/spiritual_quotes/data/repositories/spiritual_quotes_repository_impl.dart';
import '../../features/spiritual_quotes/domain/repositories/spiritual_quotes_repository.dart';
import '../../features/owner_posts/data/datasources/owner_post_remote_datasource.dart';
import '../../features/owner_posts/data/repositories/owner_post_repository_impl.dart';
import '../../features/owner_posts/domain/repositories/owner_post_repository.dart';
import '../../features/owner_posts/presentation/bloc/owner_posts_bloc.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // External
  const secureStorage = FlutterSecureStorage();
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);

  // Dio
  final dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_URL',
        defaultValue: 'http://localhost:8080/api/v1'),
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.json,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json; charset=utf-8',
      'Accept-Charset': 'utf-8',
    },
  ));

  dio.interceptors.add(AuthInterceptor(secureStorage));
  dio.interceptors.add(LogInterceptor(
    requestBody: true,
    responseBody: true,
  ));

  getIt.registerSingleton<Dio>(dio);
  getIt.registerSingleton<ApiClient>(ApiClient(dio));

  // Auth Feature
  getIt.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      getIt<AuthRemoteDataSource>(),
      getIt<FlutterSecureStorage>(),
    ),
  );
  getIt.registerFactory<AuthBloc>(
    () => AuthBloc(getIt<AuthRepository>()),
  );

  // Registration Feature
  getIt.registerLazySingleton<RegistrationRemoteDataSource>(
    () => RegistrationRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerFactory<RegistrationBloc>(
    () => RegistrationBloc(getIt<RegistrationRemoteDataSource>()),
  );

  // Events Feature
  getIt.registerLazySingleton<EventsRemoteDataSource>(
    () => EventsRemoteDataSourceImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<EventsRepository>(
    () => EventsRepositoryImpl(getIt<EventsRemoteDataSource>()),
  );
  getIt.registerFactory<EventsBloc>(
    () => EventsBloc(getIt<EventsRepository>()),
  );

  // Organizer Feature
  getIt.registerLazySingleton<OrganizerRemoteDataSource>(
    () => OrganizerRemoteDataSourceImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<OrganizerRepository>(
    () => OrganizerRepositoryImpl(getIt<OrganizerRemoteDataSource>()),
  );
  getIt.registerFactory<OrganizerBloc>(
    () => OrganizerBloc(getIt<OrganizerRepository>()),
  );

  // Admin Feature
  getIt.registerLazySingleton<AdminRemoteDataSource>(
    () => AdminRemoteDataSourceImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AdminRepository>(
    () => AdminRepositoryImpl(getIt<AdminRemoteDataSource>()),
  );
  getIt.registerFactory<AdminBloc>(
    () => AdminBloc(getIt<AdminRepository>()),
  );

  // Location Feature
  getIt.registerLazySingleton<LocationRemoteDataSource>(
    () => LocationRemoteDataSourceImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(getIt<LocationRemoteDataSource>()),
  );
  getIt.registerLazySingleton<ResolveLocationUseCase>(
    () => ResolveLocationUseCase(getIt<LocationRepository>()),
  );
  getIt.registerFactory<LocationBloc>(
    () => LocationBloc(getIt<ResolveLocationUseCase>()),
  );

  // AI Feature
  getIt.registerLazySingleton<AiRemoteDataSource>(
    () => AiRemoteDataSourceImpl(getIt<ApiClient>()),
  );
  getIt.registerFactory<AiBloc>(
    () => AiBloc(getIt<AiRemoteDataSource>()),
  );

  // Smart Map Feature
  getIt.registerLazySingleton<GeoService>(
    () => GeoService(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<MarkerClusterManager>(
    MarkerClusterManager.new,
  );
  getIt.registerFactory<MapStateManager>(
    () => MapStateManager(
      getIt<GeoService>(),
      getIt<MarkerClusterManager>(),
    ),
  );

  // Spiritual Quotes Feature
  getIt.registerLazySingleton<SpiritualQuotesRemoteDataSource>(
    () => SpiritualQuotesRemoteDataSourceImpl(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<SpiritualQuotesRepository>(
    () => SpiritualQuotesRepositoryImpl(
      getIt<SpiritualQuotesRemoteDataSource>(),
    ),
  );

  // Create Event Feature
  getIt.registerFactory<CreateEventCubit>(
    () => CreateEventCubit(getIt<EventsRepository>()),
  );

  // Owner Posts Feature
  getIt.registerLazySingleton<OwnerPostRemoteDataSource>(
    () => OwnerPostRemoteDataSource(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<OwnerPostRepository>(
    () => OwnerPostRepositoryImpl(getIt<OwnerPostRemoteDataSource>()),
  );
  getIt.registerFactory<OwnerPostsBloc>(
    () => OwnerPostsBloc(getIt<OwnerPostRepository>()),
  );
}
