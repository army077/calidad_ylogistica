import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_rastreabilidad/config/logistica_api_config.dart';
import 'package:sistema_rastreabilidad/services/logistica_delivery_service.dart'
    as delivery;

void main() {
  final configurationError = isA<LogisticaApiConfigurationException>();

  group('Política por modo', () {
    for (final host in ['localhost', '127.0.0.1', '[::1]', '192.168.1.20']) {
      test('HTTP local/red de pruebas solo debug: $host', () {
        final url = 'http://$host:3010/api10';
        expect(LogisticaApiConfig.validateForMode(url, isDebug: true).scheme,
            'http');
        expect(() => LogisticaApiConfig.validateForMode(url, isDebug: false),
            throwsA(configurationError));
      });
    }

    for (final url in [
      'https://backend.example/api10',
      'https://backend.example:443/api10',
      'https://backend.example:8443/api10',
      'https://backend.example:3010/api10',
    ]) {
      test('HTTPS válido en debug y release/profile: $url', () {
        for (final debug in [true, false]) {
          final uri = LogisticaApiConfig.validateForMode(url, isDebug: debug);
          expect(uri.scheme, 'https');
          expect(uri.host, 'backend.example');
          expect(uri.path, '/api10');
        }
      });
    }

    final invalid = [
      '',
      '   ',
      'no-es-una-url',
      '//backend.example/api10',
      'ftp://backend.example/api10',
      'http://servidor-real/api10',
      'http://localhost/api10',
      'http://localhost:3011/api10',
      'https:///api10',
      'https://backend.example',
      'https://backend.example/api10/',
      'https://backend.example/otra-ruta',
      'https://backend.example/api10/api10',
      'https://backend.example/a/../api10',
      'https://backend.example/api%31%30',
      'https://usuario:TEST_ONLY_PASSWORD@backend.example/api10',
      'https://usuario@backend.example/api10',
      'https://@backend.example/api10',
      'https://backend.example/api10#fragment',
      'https://backend.example/api10#',
      'https://backend.example/api10?pedido=1',
      'https://backend.example/api10?',
      ' https://backend.example/api10',
      'https://backend.example/api10 ',
      'https://bad host.example/api10',
      'https://backend.example\\api10',
      'https://backend.example:0/api10',
      'https://backend.example:65536/api10',
      'https://backend.example:abc/api10',
      'https://[invalid]/api10',
      'https://backend.example/api10\n',
    ];
    for (var i = 0; i < invalid.length; i++) {
      test('URL inválida #$i rechazada en ambos modos sin exponerla', () {
        for (final debug in [true, false]) {
          expect(
              () => LogisticaApiConfig.validateForMode(invalid[i],
                  isDebug: debug),
              throwsA(configurationError));
        }
      });
    }

    test('release/profile rechaza HTTP remoto incluso con puerto 3010', () {
      expect(
        () => LogisticaApiConfig.validateForMode(
            'http://servidor-real:3010/api10',
            isDebug: false),
        throwsA(configurationError),
      );
    });

    test('configuración vacía no produce fallback ni endpoint implícito', () {
      const config = LogisticaApiConfig(baseUrl: '');
      expect(config.validate, throwsA(configurationError));
      expect(() => config.deliveriesUri, throwsA(configurationError));
      expect(() => config.historyUri(), throwsA(configurationError));
    });

    test('constante pública compatible y default condicionado al modo real',
        () {
      expect(delivery.logisticaApi10BaseUrl, logisticaApi10BaseUrl);
      const configured = String.fromEnvironment('LOGISTICA_API10_BASE_URL',
          defaultValue: kDebugMode ? 'http://localhost:3010/api10' : '');
      expect(logisticaApi10BaseUrl, configured);
    });
  });

  group('Construcción central de endpoints', () {
    for (final url in [
      'http://localhost:3010/api10',
      'https://backend.example/api10',
      'https://backend.example:8443/api10',
    ]) {
      test('URLs completas sin duplicar api10: $url', () {
        final config = LogisticaApiConfig(baseUrl: url);
        final uris = [
          config.deliveriesUri,
          config.evidenceUri('9007199254740993'),
          config.finalizeUri('9007199254740993'),
          config.historyUri(),
        ];
        expect(uris.map((uri) => uri.path), [
          '/api10/logistica/entregas',
          '/api10/logistica/entregas/9007199254740993/evidencias',
          '/api10/logistica/entregas/9007199254740993/finalizar',
          '/api10/logistica/entregas/historial',
        ]);
        for (final uri in uris) {
          expect(uri.origin, Uri.parse(url).origin);
          expect(uri.pathSegments.where((segment) => segment == 'api10').length,
              1);
        }
      });
    }

    test('pedido y ambos cursores conservan caracteres reservados y Unicode',
        () {
      const query = {
        'limit': '25',
        'pedido': 'Pedido + /?&= á漢#%_',
        'current_cursor': 'C+/=%cursor',
        'legacy_cursor': 'L+/=%cursor',
      };
      const config =
          LogisticaApiConfig(baseUrl: 'https://backend.example/api10');
      final uri = config.historyUri(query: query);
      expect(uri.queryParameters, query);
      expect(uri.path, '/api10/logistica/entregas/historial');
      expect(uri.hasFragment, isFalse);
      expect(uri.userInfo, isEmpty);
    });

    test('IDs no pueden insertar rutas, query ni fragmentos', () {
      const config =
          LogisticaApiConfig(baseUrl: 'https://backend.example/api10');
      for (final id in ['', '0', '-1', '../2', '1/x', '1?x=1', '1#x']) {
        expect(() => config.evidenceUri(id), throwsArgumentError);
        expect(() => config.finalizeUri(id), throwsArgumentError);
      }
    });
  });
}
