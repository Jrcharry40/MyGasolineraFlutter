import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_gasolinera/Implementaciones/auth/presentacion/pages/inicio.dart';
import 'package:my_gasolinera/Implementaciones/home/presentacion/pages/layouthome.dart';
import 'package:my_gasolinera/core/config/config_service.dart';
import 'package:my_gasolinera/core/config/api_config.dart';
import 'package:my_gasolinera/core/config/web_env_loader.dart';
import 'package:my_gasolinera/core/utils/background_refresh_service.dart';
import 'package:flutter/foundation.dart';
import 'package:my_gasolinera/core/theme/Modos/Temas/theme_manager.dart';
import 'package:my_gasolinera/core/utils/app_logger.dart';
import 'package:my_gasolinera/core/utils/crash_handler.dart';

// New Architecture Imports
import 'package:my_gasolinera/core/database/isar_service.dart';
import 'package:my_gasolinera/core/sync/sync_manager.dart';

import 'package:my_gasolinera/Implementaciones/gasolineras/data/services/gasolinera_cache_service.dart';
import 'package:my_gasolinera/Implementaciones/mapa/data/controllers/map_controller.dart';
import 'package:my_gasolinera/Implementaciones/mapa/data/services/map_helpers.dart';

import 'package:my_gasolinera/core/l10n/app_localizations.dart';
import 'package:my_gasolinera/core/providers/language_provider.dart';
import 'package:my_gasolinera/core/providers/font_size_provider.dart';
import 'package:my_gasolinera/core/providers/filter_provider.dart';
import 'package:my_gasolinera/Implementaciones/auth/data/services/auth_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Instancias globales Isar / Sync
late IsarService isarService;
late SyncManager syncManager;
late GasolinerasCacheService gasolineraCacheService;
late BackgroundRefreshService backgroundRefreshService;
late MapController mapController;
final MarkerHelper markerHelper = MarkerHelper();

final LanguageProvider languageProvider = LanguageProvider();
final FontSizeProvider fontSizeProvider = FontSizeProvider();
final FilterProvider filterProvider = FilterProvider();

// Global key para mostrar SnackBars desde cualquier lugar
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // ✅ IMPORTANTE: Inicializar bindings FUERA de zonas
  // Esto evita "Zone mismatch" en Web
  WidgetsFlutterBinding.ensureInitialized();

  final isAPK = !kIsWeb;

  // En Web, cargar variables de entorno desde web/assets/env.json
  if (kIsWeb) {
    await WebEnvLoader.loadWebEnv();
    setWebEnvLoader(WebEnvLoader());
  }

  // En plataformas nativas, usar runZonedGuarded para capturar crashes
  if (isAPK) {
    runZonedGuarded(() async {
      await _initApp();
    }, (error, stack) async {
      final details = FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'Zona Dart',
      );
      final logPath =
          await CrashHandler.saveCrashLog(error.toString(), stack.toString());
      runApp(CrashHandler.buildCrashScreen(details, logPath: logPath));
    });
  } else {
    // En Web, ejecutar sin zonas para evitar problemas
    await _initApp();
  }
}

Future<void> _initApp() async {
  final isAPK = !kIsWeb;

  // Cargar variables de entorno SOLO en plataformas nativas
  if (isAPK) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      AppLogger.warning('No se pudo cargar .env: $e', tag: 'Main');
    }
  }

  // Mostrar modo de plataforma
  AppLogger.info(
      '═══════════════════════════════════════════════════════════',
      tag: 'Main');
  AppLogger.info('MODO PLATAFORMA: ${isAPK ? "APK/Nativo" : "WEB"}',
      tag: 'Main');
  AppLogger.info(
      '═══════════════════════════════════════════════════════════',
      tag: 'Main');

  // Inicializar configuración dinámica del backend
  await ConfigService.initialize();

  // 1. Inicializar base de datos local (Isar solo en nativo, no en web)
  isarService = IsarService();
  if (!kIsWeb) {
    await isarService.db; // Esperar a que abra la DB (solo en APK/nativo)
    AppLogger.info('Base de datos local Isar inicializada', tag: 'Main');
  } else {
    AppLogger.info('Web: sin base de datos local Isar', tag: 'Main');
  }

  // 2. Inicializar servicios dependientes
  gasolineraCacheService = GasolinerasCacheService(isarService);
  syncManager = SyncManager(isarService: isarService);
  mapController = MapController(cacheService: gasolineraCacheService);
  await mapController.precargarFavoritos();

  // 3. Inicializar servicio de background refresh
  backgroundRefreshService = BackgroundRefreshService(syncManager);
  backgroundRefreshService.start();

  // 4. Lanzar sincronización en background en el arranque (si está logueado)
  syncManager.startBackgroundSync();

  // Cargar TEMA
  await ThemeManager().loadInitialTheme();

  // Cargar IDIOMA
  await languageProvider.loadInitialLanguage();

  // Cargar TAMAÑO DE FUENTE
  await fontSizeProvider.loadInitialFontSize();

  // Cargar FILTROS
  await filterProvider.loadInitialFilters();

  // Inicializar Auth
  await AuthService.initialize();

  // Inicializar Logger
  await AppLogger.init();

  // ✅ Optimizaciones de rendimiento para APK (reducir RAM/CPU)
  if (isAPK) {
    PaintingBinding.instance.imageCache.maximumSize = 50;
    PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;

    AppLogger.info('Optimizaciones de rendimiento APK aplicadas', tag: 'Main');
  }

  // Capturar errores de Flutter (widgets, rendering, etc.)
  FlutterError.onError = (details) async {
    FlutterError.presentError(details);
    final logPath = await CrashHandler.saveCrashLog(
      details.exception.toString(),
      details.stack?.toString() ?? '',
    );
    runApp(CrashHandler.buildCrashScreen(details, logPath: logPath));
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeManager(),
      builder: (context, _) {
        return ListenableBuilder(
          listenable: languageProvider,
          builder: (context, _) {
            return ListenableBuilder(
              listenable: fontSizeProvider,
              builder: (context, _) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler:
                        TextScaler.linear(fontSizeProvider.textScaleFactor),
                  ),
                  child: MaterialApp(
                    scaffoldMessengerKey: rootScaffoldMessengerKey,
                    debugShowCheckedModeBanner: false,
                    title: 'MyGasolinera',
                    theme: ThemeManager().currentTheme,
                    locale: languageProvider.currentLocale,
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    home: AuthService.isLoggedIn()
                        ? const Layouthome()
                        : const Inicio(),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
