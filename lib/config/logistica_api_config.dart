import 'package:flutter/foundation.dart';

// A release/profile build must explicitly supply its backend. No production
// domain is assumed and the debug default never reaches a non-debug build.
const logisticaApi10BaseUrl = String.fromEnvironment(
  'LOGISTICA_API10_BASE_URL',
  defaultValue: kDebugMode ? 'http://localhost:3010/api10' : '',
);

class LogisticaApiConfigurationException implements Exception {
  const LogisticaApiConfigurationException();

  static const message =
      'Configura LOGISTICA_API10_BASE_URL con HTTPS y path /api10. '
      'HTTP en puerto 3010 solo está permitido en debug.';

  @override
  String toString() => message;
}

class LogisticaApiConfig {
  const LogisticaApiConfig({this.baseUrl = logisticaApi10BaseUrl});

  final String baseUrl;

  Uri get baseUri => _validate(baseUrl, isDebug: kDebugMode);

  void validate() {
    // Validation remains lazy so services can return their controlled errors.
    _validate(baseUrl, isDebug: kDebugMode);
  }

  // Tests may exercise both policies; services always use the real kDebugMode.
  // This does not construct a config or override its runtime build policy.
  @visibleForTesting
  static Uri validateForMode(String value, {required bool isDebug}) =>
      _validate(value, isDebug: isDebug);

  static Uri _validate(String value, {required bool isDebug}) {
    try {
      return _parse(value, isDebug: isDebug);
    } on FormatException {
      throw const LogisticaApiConfigurationException();
    } on ArgumentError {
      throw const LogisticaApiConfigurationException();
    }
  }

  static Uri _parse(String value, {required bool isDebug}) {
    final uri = Uri.tryParse(value);
    final authorityEnd = value.indexOf('/', value.indexOf('://') + 3);
    if (value.isEmpty ||
        RegExp(r'[\s\\\x00-\x1f\x7f]').hasMatch(value) ||
        uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        RegExp(r'[\s/@\\?#%]').hasMatch(uri.host) ||
        uri.userInfo.isNotEmpty ||
        value.contains('@') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != '/api10' ||
        authorityEnd < 0 ||
        value.substring(authorityEnd) != '/api10' ||
        uri.port < 1 ||
        uri.port > 65535 ||
        !(uri.scheme == 'https' ||
            (isDebug && uri.scheme == 'http' && uri.port == 3010))) {
      throw const LogisticaApiConfigurationException();
    }
    return uri;
  }

  Uri _endpoint(List<String> suffix, {Map<String, String>? query}) =>
      baseUri.replace(
        pathSegments: [...baseUri.pathSegments, ...suffix],
        queryParameters: query == null || query.isEmpty ? null : query,
      );

  Uri get deliveriesUri => _endpoint(const ['logistica', 'entregas']);

  Uri evidenceUri(String deliveryId) => _endpoint(
      ['logistica', 'entregas', _deliveryId(deliveryId), 'evidencias']);

  Uri finalizeUri(String deliveryId) => _endpoint(
      ['logistica', 'entregas', _deliveryId(deliveryId), 'finalizar']);

  Uri historyUri({Map<String, String>? query}) =>
      _endpoint(const ['logistica', 'entregas', 'historial'], query: query);

  static String _deliveryId(String value) {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(value)) {
      throw ArgumentError.value(value, 'deliveryId', 'ID de entrega inválido.');
    }
    return value;
  }
}
