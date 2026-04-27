// ============================================================================
//  core/di/injection_container.dart
//
//  CONTENEDOR DE INVERSIÓN DE CONTROL (IoC) con get_it
//  ────────────────────────────────────────────────────
//  Este archivo es el CORAZÓN de la sesión de hoy.
//
//  CONCEPTO: Inversión de Control (IoC)
//  En lugar de que cada clase cree sus propias dependencias (acoplamiento
//  fuerte), un contenedor central las crea y las proporciona bajo demanda.
//
//  get_it actúa como un "directorio de servicios" (Service Locator):
//    - sl<UserRepository>() → devuelve la implementación registrada
//    - Nadie sabe CÓMO se construyó, solo QÚE tipo recibe.
//
//  TIPOS DE REGISTRO EN get_it:
//  ┌─────────────────────┬─────────────────────────────────────────────────┐
//  │ registerFactory     │ Nueva instancia cada vez que se solicita.        │
//  │                     │ Ideal para: Use Cases, Notifiers.                │
//  ├─────────────────────┼─────────────────────────────────────────────────┤
//  │ registerLazySingleton│ Una sola instancia creada la 1ra vez que se     │
//  │                     │ solicita. Ideal para: Repos, DataSources, Dio.  │
//  ├─────────────────────┼─────────────────────────────────────────────────┤
//  │ registerSingleton   │ Una sola instancia creada AL MOMENTO del         │
//  │                     │ registro. Ideal para: BD, configs globales.      │
//  └─────────────────────┴─────────────────────────────────────────────────┘
// ============================================================================

import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../network/dio_client.dart';
import '../database/app_database.dart';

// Features
import '../../features/products/data/datasources/product_remote_datasource.dart';
import '../../features/products/data/datasources/product_local_datasource.dart';
import '../../features/products/data/repositories/product_repository_impl.dart';
import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/domain/usecases/get_products_usecase.dart';
import '../../features/products/domain/usecases/get_product_detail_usecase.dart';
import '../../features/products/domain/usecases/search_products_usecase.dart';

import '../../features/favorites/data/datasources/favorite_local_datasource.dart';
import '../../features/favorites/data/repositories/favorite_repository_impl.dart';
import '../../features/favorites/domain/repositories/favorite_repository.dart';
import '../../features/favorites/domain/usecases/add_favorite_usecase.dart';
import '../../features/favorites/domain/usecases/remove_favorite_usecase.dart';
import '../../features/favorites/domain/usecases/get_favorites_usecase.dart';

import '../../features/auth/data/datasources/auth_remote_datasource.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';

//AGREGADO POR THIAGO P
import '../../features/artisans/data/datasources/artisan_remote_datasource.dart';
import '../../features/artisans/data/repositories/artisan_repository_impl.dart';
import '../../features/artisans/domain/repositories/artisan_repository.dart';
import '../../features/artisans/domain/usecases/get_artisans_usecase.dart';

// Instancia global del Service Locator
// Convención: se usa "sl" (service locator) como nombre corto
final sl = GetIt.instance;

/// Inicializa todas las dependencias de la aplicación.
/// Se llama UNA SOLA VEZ desde main().
Future<void> init() async {
  // ══════════════════════════════════════════════════════════════════════════
  // CAPA EXTERNAL / INFRAESTRUCTURA
  // Registrar primero los elementos externos que las demás capas necesitan.
  // ══════════════════════════════════════════════════════════════════════════

  // Base de datos local (SQLite) — Singleton porque hay una sola BD
  final database = await AppDatabase.getInstance();
  sl.registerSingleton<AppDatabase>(database);

  // Cliente HTTP (Dio) — LazySingleton: una sola instancia compartida
  sl.registerLazySingleton<Dio>(() => DioClient.createDio());

  // ══════════════════════════════════════════════════════════════════════════
  // FEATURE: PRODUCTS
  // Orden de registro: Data → Domain (de afuera hacia adentro)
  // ══════════════════════════════════════════════════════════════════════════

  // ── DATA LAYER ────────────────────────────────────────────────────────────

  // DataSources — LazySingleton: una sola conexión a la API / BD
  sl.registerLazySingleton<ProductRemoteDataSource>(
    () => ProductRemoteDataSourceImpl(client: sl<Dio>()),
  );
  sl.registerLazySingleton<ProductLocalDataSource>(
    () => ProductLocalDataSourceImpl(database: sl<AppDatabase>()),
  );

  // Repository Implementation — LazySingleton
  // NOTA: Registramos contra la INTERFAZ (ProductRepository), no la
  // implementación. Esto es la esencia del Dependency Inversion Principle.
  sl.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(
      remoteDataSource: sl<ProductRemoteDataSource>(),
      localDataSource: sl<ProductLocalDataSource>(),
    ),
  );

  // ── DOMAIN LAYER ─────────────────────────────────────────────────────────

  // Use Cases — Factory: nueva instancia por solicitud (stateless)
  sl.registerFactory(
      () => GetProductsUseCase(repository: sl<ProductRepository>()));
  sl.registerFactory(
      () => GetProductDetailUseCase(repository: sl<ProductRepository>()));
  sl.registerFactory(
      () => SearchProductsUseCase(repository: sl<ProductRepository>()));

  // ══════════════════════════════════════════════════════════════════════════
  // FEATURE: FAVORITES
  // ══════════════════════════════════════════════════════════════════════════

  sl.registerLazySingleton<FavoriteLocalDataSource>(
    () => FavoriteLocalDataSourceImpl(database: sl<AppDatabase>()),
  );

  sl.registerLazySingleton<FavoriteRepository>(
    () => FavoriteRepositoryImpl(
      localDataSource: sl<FavoriteLocalDataSource>(),
    ),
  );

  sl.registerFactory(
      () => AddFavoriteUseCase(repository: sl<FavoriteRepository>()));
  sl.registerFactory(
      () => RemoveFavoriteUseCase(repository: sl<FavoriteRepository>()));
  sl.registerFactory(
      () => GetFavoritesUseCase(repository: sl<FavoriteRepository>()));

  // ══════════════════════════════════════════════════════════════════════════
  // FEATURE: AUTH
  // ══════════════════════════════════════════════════════════════════════════

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(client: sl<Dio>()),
  );

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl<AuthRemoteDataSource>(),
    ),
  );

  sl.registerFactory(() => LoginUseCase(repository: sl<AuthRepository>()));
  sl.registerFactory(() => LogoutUseCase(repository: sl<AuthRepository>()));
  sl.registerFactory(
      () => GetCurrentUserUseCase(repository: sl<AuthRepository>()));

  // ═══════════════════════════════════════════════════════════════
  // ARTISANS FEATURE
  // ═══════════════════════════════════════════════════════════════
  sl.registerLazySingleton<ArtisanRemoteDataSource>(
    () => ArtisanRemoteDataSourceImpl(client: sl<Dio>()),
  );

  sl.registerLazySingleton<ArtisanRepository>(
    () =>
        ArtisanRepositoryImpl(remoteDataSource: sl<ArtisanRemoteDataSource>()),
  );

  sl.registerFactory(
    () => GetArtisansUseCase(repository: sl<ArtisanRepository>()),
  );
}
