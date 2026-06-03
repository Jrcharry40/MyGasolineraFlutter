import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:my_gasolinera/core/utils/app_logger.dart';

/// Cargador de variables de entorno para Web
/// Lee desde web/assets/env.json en tiempo de ejecución
class WebEnvLoader {
  static final Map<String, String> _webEnv = {};
  static bool _isLoaded = false;

  /// Carga las variables de entorno desde web/assets/env.json
  static Future<void> loadWebEnv() async {
    if (!kIsWeb || _isLoaded) return;

    try {
      final response = await http.get(
        Uri.parse('/assets/env.json'),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        _webEnv.addAll(
          jsonData.map((key, value) => MapEntry(key, value.toString())),
        );
        _isLoaded = true;
        AppLogger.info('Variables de entorno Web cargadas desde env.json',
            tag: 'WebEnvLoader');
      } else {
        AppLogger.warning('No se pudo cargar env.json (HTTP ${response.statusCode})',
            tag: 'WebEnvLoader');
      }
    } catch (e) {
      AppLogger.warning('Error al cargar env.json: $e', tag: 'WebEnvLoader');
    }
  }

  /// Obtiene una variable de entorno Web
  static String? get(String key) {
    return _webEnv[key];
  }

  /// Obtiene una variable de entorno Web con valor por defecto
  static String getOrDefault(String key, String defaultValue) {
    return _webEnv[key] ?? defaultValue;
  }
}
