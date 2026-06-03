import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_gasolinera/core/utils/app_logger.dart';

/// Cargador de variables Web (solo si está en Web)
WebEnvLoaderForConfig? _webEnvLoader;

///
/// Este archivo contiene la URL base del servidor backend.
/// Cambia solo la URL aquí cuando uses cloudflared o cambies de servidor.
///
/// Ejemplos de URLs:
/// - Desarrollo local: 'http://localhost:3000'
/// - Android Emulator: 'http://10.0.2.2:3000'
/// - Ngrok: 'https://rectricial-dewayne-collusive.ngrok-free.dev'
/// - Producción: 'https://tu-dominio.com'
class ApiConfig {
  /// URL base del backend
  ///
  /// Esta URL se actualiza dinámicamente al iniciar la app usando ConfigService
  /// No incluyas la barra final (/)
  static const String _localUrl = 'http://localhost:3000';
  static const String _androidEmulatorUrl = 'http://10.0.2.2:3000';
  static const String _ngrokUrl =
      'https://rectricial-dewayne-collusive.ngrok-free.dev';

  // Variable de respaldo por si se actualiza dinámicamente
  static String? _dynamicUrl;

  /// URL base del backend
  ///
  /// Esta URL se determina por el switch en lib/important/switch_backend.dart (ahora movido a .env)
  static String get baseUrl {
    // Si se ha establecido una URL dinámica (ej. al inicio), usarla
    if (_dynamicUrl != null) return _dynamicUrl!;

    String? switchBackendStr;
    String? apiUrlNgrok;
    String? apiUrlEmulador;
    String? apiUrlLocal;

    if (kIsWeb) {
      // En Web, leer de WebEnvLoader
      switchBackendStr = _webEnvLoader?.get('SWITCH_BACKEND') ?? '0';
      apiUrlNgrok =
          _webEnvLoader?.get('API_URL_NGROK') ?? _ngrokUrl;
      apiUrlEmulador =
          _webEnvLoader?.get('API_URL_EMULADOR') ?? _androidEmulatorUrl;
      apiUrlLocal =
          _webEnvLoader?.get('API_URL_LOCAL') ?? _localUrl;
    } else {
      // En nativo, leer de dotenv
      switchBackendStr = dotenv.env['SWITCH_BACKEND'] ?? '0';
      apiUrlNgrok =
          dotenv.env['API_URL_NGROK'] ?? _ngrokUrl;
      apiUrlEmulador =
          dotenv.env['API_URL_EMULADOR'] ?? _androidEmulatorUrl;
      apiUrlLocal =
          dotenv.env['API_URL_LOCAL'] ?? _localUrl;
    }

    final switchBackend = int.tryParse(switchBackendStr ?? '0') ?? 0;

    if (switchBackend == 1) {
      return apiUrlNgrok;
    }

    // Si es localhost (0) comprobamos si se ejecuta en Android o Desktop/Web
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return apiUrlEmulador;
    }

    return apiUrlLocal;
  }

  /// Actualiza la URL base dinámicamente
  static void setBaseUrl(String newUrl) {
    if (newUrl.endsWith('/')) {
      _dynamicUrl = newUrl.substring(0, newUrl.length - 1);
    } else {
      _dynamicUrl = newUrl;
    }
    AppLogger.info('URL Base actualizada a: $_dynamicUrl', tag: 'ApiConfig');
  }

  /// Obtiene la URL completa para un endpoint
  ///
  /// Ejemplo:
  /// ```dart
  /// ApiConfig.getUrl('/usuarios') // 'https://tu-url.com/usuarios'
  /// ```
  static String getUrl(String endpoint) {
    // Asegurar que el endpoint comience con /
    if (!endpoint.startsWith('/')) {
      endpoint = '/$endpoint';
    }
    return '$baseUrl$endpoint';
  }

  /// URL para el endpoint de login
  static String get loginUrl => getUrl('/login');

  /// URL para el endpoint de registro
  static String get registerUrl => getUrl('/register');

  /// URL para el endpoint de recuperación de contraseña
  static String get forgotPasswordUrl => getUrl('/forgot-password');

  /// URL para el endpoint de verificación de token
  static String get verifyTokenUrl => getUrl('/verify-token');

  /// URL para el endpoint de reseteo de contraseña
  static String get resetPasswordUrl => getUrl('/reset-password');

  /// URL para el endpoint de facturas
  static String get facturasUrl => getUrl('/facturas');

  /// URL para el endpoint de coches
  static String get cochesUrl => getUrl('/coches');

  /// URL para el endpoint de usuarios
  static String get usuariosUrl => getUrl('/usuarios');

  /// URL para el endpoint de estadísticas
  static String get estadisticasUrl => getUrl('/estadisticas');

  /// URL para el endpoint de perfil
  static String get perfilUrl => getUrl('/api/perfil');

  /// URL para el endpoint de accesibilidad
  static String get accesibilidadUrl => getUrl('/accesibilidad');

  /// Google Maps API key loaded from dotenv
  static String get mapsApiKey {
    if (kIsWeb) {
      return _webEnvLoader?.get('GOOGLE_MAPS_API_KEY') ?? '';
    }
    return dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  }

  /// Headers base para todas las peticiones
  ///
  /// Incluye el header para saltar el aviso de ngrok
  static Map<String, String> get headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      };
}

/// Interfaz para inyectar WebEnvLoader en ApiConfig
abstract class WebEnvLoaderForConfig {
  String? get(String key);
}

/// Establece el cargador de variables Web
void setWebEnvLoader(WebEnvLoaderForConfig loader) {
  _webEnvLoader = loader;
}
