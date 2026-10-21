import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sistema_rastreabilidad/pages/firma-entrega-registros/registros-entrega.dart';
import 'package:sistema_rastreabilidad/services/logistica_delivery_list_service.dart';

class TestAuth implements FirebaseAuth {
  TestAuth(this.user);
  User? user;
  @override
  User? get currentUser => user;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestUser implements User {
  TestUser([this.tokenProvider]);
  final Future<String?> Function()? tokenProvider;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      tokenProvider == null ? 'TEST_ONLY_TOKEN' : await tokenProvider!();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestClient extends http.BaseClient {
  TestClient(this.handler);
  final Future<http.Response> Function(http.BaseRequest) handler;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
        Stream.value(response.bodyBytes), response.statusCode,
        headers: response.headers);
  }

  @override
  void close() => closed = true;
}

Map<String, Object?> item({String id = '1', String pedido = 'PEDIDO-A'}) => {
      'source': 'CURRENT',
      'id': id,
      'pedido': pedido,
      'display_name': 'Usuario de prueba',
      'email': 'prueba@example.invalid',
      'status': 'COMPLETED',
      'legacy_record_state': null,
      'created_at': '2026-10-21T12:34:56.123456Z',
      'recorded_local_at': null,
      'time_zone': 'UTC',
      'photo_count': 2,
      'legacy_image_count': null,
    };

Map<String, Object?> legacyItem(
        {String id = 'legacy-1', String pedido = 'LEGACY-A'}) =>
    {
      'source': 'LEGACY',
      'id': id,
      'pedido': pedido,
      'display_name': 'Usuario histórico',
      'email': 'declarado@example.invalid',
      'status': null,
      'legacy_record_state': 'RECORDED',
      'created_at': null,
      'recorded_local_at': '2023-12-04T10:29:47',
      'time_zone': null,
      'photo_count': null,
      'legacy_image_count': 17,
    };

Map<String, Object?> page({
  List<Object?>? items,
  String? cursor,
  List<Object?> legacyItems = const [],
  String? legacyCursor,
}) =>
    {
      'ok': true,
      'current': {
        'items': items ?? [item()],
        'next_cursor': cursor
      },
      'legacy': {'items': legacyItems, 'next_cursor': legacyCursor},
    };

http.Response jsonResponse(Object? body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

LogisticaDeliveryListService service(
  Future<http.Response> Function(http.BaseRequest) handler, {
  FirebaseAuth? auth,
  Duration timeout = const Duration(seconds: 30),
  List<TestClient>? clients,
  String baseUrl = 'http://localhost:3010/api10',
}) =>
    LogisticaDeliveryListService(
      auth: auth ?? TestAuth(TestUser()),
      baseUrl: baseUrl,
      requestTimeout: timeout,
      clientFactory: () {
        final client = TestClient(handler);
        clients?.add(client);
        return client;
      },
    );

Matcher failure(LogisticaDeliveryListFailure kind, {int? status}) =>
    isA<LogisticaDeliveryListException>()
        .having((e) => e.failure, 'failure', kind)
        .having((e) => e.statusCode, 'statusCode', status);

void main() {
  group('Contrato API10', () {
    test('parsea contrato, fotos, fecha UTC y microsegundos', () {
      final result = LogisticaDeliveryListPage.fromJson(page());
      final delivery = result.current.items.single;
      expect(delivery.id, '1');
      expect(delivery.pedido, 'PEDIDO-A');
      expect(delivery.displayName, 'Usuario de prueba');
      expect(delivery.email, 'prueba@example.invalid');
      expect(delivery.status, 'COMPLETED');
      expect(delivery.photoCount, 2);
      expect(delivery.createdAt!.isUtc, isTrue);
      expect(
          delivery.createdAt!.toIso8601String(), '2026-10-21T12:34:56.123456Z');
      expect(result.current.nextCursor, isNull);
      expect(() => result.current.items.clear(), throwsUnsupportedError);
    });
    test('BIGINT permanece String sin pérdida de precisión', () {
      final delivery =
          LogisticaDeliveryListItem.fromJson(item(id: '9223372036854775807'));
      expect(delivery.id, isA<String>());
      expect(delivery.id, '9223372036854775807');
    });
    test('nombre/email null y cero fotos válidos', () {
      final delivery = LogisticaDeliveryListItem.fromJson({
        ...item(),
        'display_name': null,
        'email': null,
        'photo_count': 0,
      });
      expect(delivery.displayName, isNull);
      expect(delivery.email, isNull);
      expect(delivery.photoCount, 0);
    });
    test('next_cursor opaco se conserva', () {
      const cursor = 'opaque+/=%cursor';
      expect(
          LogisticaDeliveryListPage.fromJson(page(cursor: cursor))
              .current
              .nextCursor,
          cursor);
    });
    test('items vacío válido', () {
      final result = LogisticaDeliveryListPage.fromJson(page(items: []));
      expect(result.current.items, isEmpty);
      expect(result.current.nextCursor, isNull);
    });
    final badPages = <String, Object?>{
      'raíz no objeto': [],
      'ok false': {...page(), 'ok': false},
      'ok string': {...page(), 'ok': 'true'},
      'items no lista': {
        ...page(),
        'current': {'items': {}, 'next_cursor': null}
      },
      'item no objeto': page(items: [null]),
      'cursor no string': {
        ...page(),
        'current': {'items': [], 'next_cursor': 1}
      },
      'cursor vacío': page(cursor: ''),
      'cursor sin items': page(items: [], cursor: 'cursor'),
      'cursor faltante': {
        ...page(),
        'current': {'items': []}
      },
    };
    for (final entry in badPages.entries) {
      test('rechaza ${entry.key}', () {
        expect(() => LogisticaDeliveryListPage.fromJson(entry.value),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      });
    }
    final badFields = <String, Object?>{
      'id': 1,
      'pedido': null,
      'display_name': 4,
      'email': [],
      'created_at': 'fecha inválida',
      'status': 'PENDING_EVIDENCE',
      'photo_count': -1,
    };
    for (final entry in badFields.entries) {
      test('rechaza campo ${entry.key}', () {
        expect(
            () => LogisticaDeliveryListItem.fromJson(
                {...item(), entry.key: entry.value}),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      });
    }
    test('rechaza fechas imposibles, sin UTC y contadores no enteros', () {
      for (final timestamp in [
        '2026-02-31T12:00:00Z',
        '2026-10-21T12:00:00',
        '2026-10-21T12:00:00-06:00'
      ]) {
        expect(
            () => LogisticaDeliveryListItem.fromJson(
                {...item(), 'created_at': timestamp}),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
      for (final count in ['2', 2.5, null]) {
        expect(
            () => LogisticaDeliveryListItem.fromJson(
                {...item(), 'photo_count': count}),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
    });
    test('campos ausentes no se convierten en lista vacía', () {
      for (final key in item().keys) {
        final incomplete = item()..remove(key);
        expect(
            () => LogisticaDeliveryListPage.fromJson(page(items: [incomplete])),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
    });
  });

  group('GET autenticado', () {
    test('sin Firebase user falla sin HTTP', () async {
      final clients = <TestClient>[];
      await expectLater(
          service((_) async => jsonResponse(page()),
                  auth: TestAuth(null), clients: clients)
              .fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.authentication)));
      expect(clients, isEmpty);
    });
    for (final token in <String?>[null, '', '   ']) {
      test('token ausente/vacío ${token?.length} no HTTP', () async {
        final clients = <TestClient>[];
        await expectLater(
            service((_) async => jsonResponse(page()),
                    auth: TestAuth(TestUser(() async => token)),
                    clients: clients)
                .fetchPage(),
            throwsA(failure(LogisticaDeliveryListFailure.authentication)));
        expect(clients, isEmpty);
      });
    }
    test('error Firebase controlado sin HTTP', () async {
      final clients = <TestClient>[];
      await expectLater(
          service((_) async => jsonResponse(page()),
                  auth: TestAuth(TestUser(() async {
            throw FirebaseAuthException(code: 'TEST_ONLY_AUTH_ERROR');
          })), clients: clients)
              .fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.authentication)));
      expect(clients, isEmpty);
    });
    test('usuario/token vigente antes de cada GET y Bearer', () async {
      var calls = 0;
      final auth = TestAuth(TestUser(() async => 'TEST_ONLY_FIRST'));
      final clients = <TestClient>[];
      final api = service((request) async {
        calls++;
        expect(request.method, 'GET');
        expect(request.url.path, '/api10/logistica/entregas/historial');
        expect(request.url.queryParameters, {'limit': '25'});
        expect(request.headers['Authorization'],
            calls == 1 ? 'Bearer TEST_ONLY_FIRST' : 'Bearer TEST_ONLY_SECOND');
        expect(request.followRedirects, isFalse);
        return jsonResponse(page());
      }, auth: auth, clients: clients);
      await api.fetchPage();
      auth.user = TestUser(() async => 'TEST_ONLY_SECOND');
      await api.fetchPage();
      expect(calls, 2);
      expect(clients.every((c) => c.closed), isTrue);
    });
    test('pedido codificado, cursor exacto y limit sin identidad', () async {
      const pedido = 'Pedido + /?&= á漢#';
      const cursor = 'opaque+/=%cursor';
      await service((request) async {
        expect(request.url.queryParameters,
            {'limit': '1', 'pedido': pedido, 'current_cursor': cursor});
        return jsonResponse(page());
      }).fetchPage(pedido: pedido, currentCursor: cursor, limit: 1);
    });
    test('búsqueda vacía omite pedido y cursor', () async {
      await service((request) async {
        expect(request.url.queryParameters, {'limit': '25'});
        return jsonResponse(page(items: []));
      }).fetchPage(pedido: '');
    });
    for (final status in [400, 401, 403, 500, 202]) {
      test('HTTP $status error tipado incluso con body inválido', () async {
        final clients = <TestClient>[];
        final kind = switch (status) {
          401 => LogisticaDeliveryListFailure.authentication,
          403 => LogisticaDeliveryListFailure.authorization,
          _ => LogisticaDeliveryListFailure.http,
        };
        await expectLater(
            service(
                    (_) async =>
                        http.Response('TEST_ONLY_PRIVATE_BODY', status),
                    clients: clients)
                .fetchPage(),
            throwsA(allOf(
              failure(kind, status: status),
              isA<LogisticaDeliveryListException>().having(
                  (e) => e.message.contains('TEST_ONLY_PRIVATE_BODY'),
                  'no expone body',
                  isFalse),
            )));
        expect(clients.single.closed, isTrue);
      });
    }
    test('JSON inválido no es lista vacía', () async {
      await expectLater(
          service((_) async => http.Response('{', 200)).fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
    });
    test('HTTP 200 valida contrato y UTF-8', () async {
      final result = await service((_) async => jsonResponse(page(items: [
            {...item(pedido: 'Árbol 漢'), 'display_name': 'José'}
          ]))).fetchPage();
      expect(result.current.items.single.pedido, 'Árbol 漢');
      expect(result.current.items.single.displayName, 'José');
      await expectLater(
          service((_) async => jsonResponse({...page(), 'ok': false}))
              .fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
    });
    test('timeout HTTP distinguible cierra cliente', () async {
      final clients = <TestClient>[];
      await expectLater(
          service((_) => Completer<http.Response>().future,
                  timeout: const Duration(milliseconds: 5), clients: clients)
              .fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.timeout)));
      expect(clients.single.closed, isTrue);
    });
    test('timeout token no inicia HTTP', () async {
      final clients = <TestClient>[];
      await expectLater(
          service((_) async => jsonResponse(page()),
                  auth: TestAuth(TestUser(() => Completer<String?>().future)),
                  timeout: const Duration(milliseconds: 5),
                  clients: clients)
              .fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.timeout)));
      expect(clients, isEmpty);
    });
    test('red distinguible cierra cliente', () async {
      final clients = <TestClient>[];
      await expectLater(
          service((_) async => throw http.ClientException('TEST_ONLY_NETWORK'),
                  clients: clients)
              .fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.network)));
      expect(clients.single.closed, isTrue);
    });
    test('URL con path inválido no inicia HTTP', () async {
      final clients = <TestClient>[];
      await expectLater(
          service((_) async => jsonResponse(page()),
                  baseUrl: 'https://example.invalid/ruta-incorrecta',
                  clients: clients)
              .fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.configuration)));
      expect(clients, isEmpty);
    });
  });

  group('Pantalla', () {
    testWidgets('carga inicial, vacío y mounted tras dispose', (tester) async {
      final response = Completer<http.Response>();
      await tester.pumpWidget(MaterialApp(
        home: Registroentregas(service: service((_) => response.future)),
      ));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No hay entregas actuales.'), findsNothing);
      response.complete(jsonResponse(page(items: [])));
      await tester.pumpAndSettle();
      expect(find.text('No hay entregas actuales.'), findsOneWidget);
      final lateResponse = Completer<http.Response>();
      await tester.pumpWidget(MaterialApp(
          home: Registroentregas(
        key: const ValueKey('second-screen'),
        service: service((_) => lateResponse.future),
      )));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      lateResponse.complete(jsonResponse(page()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
    testWidgets('error inicial permite reintentar y no finge vacío',
        (tester) async {
      var calls = 0;
      await tester.pumpWidget(
          MaterialApp(home: Registroentregas(service: service((_) async {
        calls++;
        return calls == 1
            ? jsonResponse({}, 401)
            : jsonResponse(page(items: []));
      }))));
      await tester.pumpAndSettle();
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('No hay entregas actuales.'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('No hay entregas actuales.'), findsOneWidget);
      expect(calls, 2);
    });
    testWidgets('fallo de página conserva items, reintenta cursor y deduplica',
        (tester) async {
      final requests = <Uri>[];
      await tester.pumpWidget(
          MaterialApp(home: Registroentregas(service: service((request) async {
        requests.add(request.url);
        if (requests.length == 1) {
          return jsonResponse(page(cursor: 'EXACT_CURSOR'));
        }
        if (requests.length == 2) return jsonResponse({}, 500);
        return jsonResponse(page(items: [item(), item(id: '2', pedido: 'B')]));
      }))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();
      expect(find.text('Pedido: PEDIDO-A'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Pedido: PEDIDO-A'), findsOneWidget);
      expect(find.text('Pedido: B'), findsOneWidget);
      expect(find.text('Cargar más'), findsNothing);
      expect(requests[1].queryParameters['current_cursor'], 'EXACT_CURSOR');
      expect(requests[2].queryParameters['current_cursor'], 'EXACT_CURSOR');
    });
    testWidgets('debounce servidor, reset cursor y limpiar búsqueda',
        (tester) async {
      final requests = <Uri>[];
      await tester.pumpWidget(
          MaterialApp(home: Registroentregas(service: service((request) async {
        requests.add(request.url);
        return jsonResponse(request.url.queryParameters.containsKey('pedido')
            ? page(items: [])
            : page(cursor: 'OLD_CURSOR'));
      }))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'S');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextField), 'SEARCH');
      await tester.pump(const Duration(milliseconds: 349));
      expect(requests.length, 1);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(
          requests.last.queryParameters, {'limit': '25', 'pedido': 'SEARCH'});
      expect(find.text('No se encontraron pedidos.'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters, {'limit': '25'});
      expect(find.text('Pedido: PEDIDO-A'), findsOneWidget);
    });
    testWidgets('búsqueda nueva ignora página antigua en vuelo',
        (tester) async {
      final oldPage = Completer<http.Response>();
      await tester.pumpWidget(
          MaterialApp(home: Registroentregas(service: service((request) async {
        if (request.url.queryParameters.containsKey('current_cursor')) {
          return oldPage.future;
        }
        if (request.url.queryParameters.containsKey('pedido')) {
          return jsonResponse(page(items: [item(id: '3', pedido: 'NUEVO')]));
        }
        return jsonResponse(page(cursor: 'OLD_CURSOR'));
      }))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cargar más'));
      await tester.pump();
      expect(find.text('Pedido: PEDIDO-A'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'NUEVO');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      oldPage.complete(jsonResponse(
          page(items: [item(id: '2', pedido: 'ANTIGUO')], cursor: 'STALE')));
      await tester.pumpAndSettle();
      expect(find.text('Pedido: NUEVO'), findsOneWidget);
      expect(find.text('Pedido: ANTIGUO'), findsNothing);
      expect(find.text('Pedido: PEDIDO-A'), findsNothing);
      expect(find.text('Cargar más'), findsNothing);
    });
    testWidgets('nulls y fecha local sin ajuste fijo en UI', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Registroentregas(
              service: service(
        (_) async => jsonResponse(page(items: [
          {...item(), 'display_name': null, 'email': null}
        ])),
      ))));
      await tester.pumpAndSettle();
      expect(find.text('Usuario'), findsOneWidget);
      await tester.tap(find.text('Pedido: PEDIDO-A'));
      await tester.pumpAndSettle();
      final local = DateTime.parse('2026-10-21T12:34:56.123456Z').toLocal();
      expect(find.text('Correo: No disponible'), findsOneWidget);
      expect(find.text('Fecha: ${DateFormat('yyyy-MM-dd').format(local)}'),
          findsOneWidget);
      expect(find.text('Hora: ${DateFormat('hh:mm:ss a').format(local)}'),
          findsOneWidget);
      expect(find.textContaining('Img Subidas: 2'), findsOneWidget);
    });
  });

  group('Historial separado', () {
    test('parsea ambas secciones, source e identidad estable sin inferir ID',
        () {
      final result = LogisticaDeliveryListPage.fromJson(page(
        items: [item(id: '1')],
        cursor: 'CURRENT_OPAQUE',
        legacyItems: [legacyItem(id: '1')],
        legacyCursor: 'LEGACY_OPAQUE',
      ));
      final current = result.current.items.single;
      final legacy = result.legacy.items.single;
      expect(current.source, LogisticaDeliverySource.current);
      expect(legacy.source, LogisticaDeliverySource.legacy);
      expect(current.id, legacy.id);
      expect(current.uiKey, isNot(legacy.uiKey));
      expect(result.current.nextCursor, 'CURRENT_OPAQUE');
      expect(result.legacy.nextCursor, 'LEGACY_OPAQUE');
      expect(legacy.status, isNull);
      expect(legacy.legacyRecordState, 'RECORDED');
      expect(legacy.createdAt, isNull);
      expect(legacy.recordedLocalAt, '2023-12-04T10:29:47');
      expect(legacy.timeZone, isNull);
      expect(legacy.photoCount, isNull);
      expect(legacy.legacyImageCount, 17);
      expect(current.recordedLocalAt, isNull);
      expect(current.legacyRecordState, isNull);
      expect(current.legacyImageCount, isNull);
      expect(current.timeZone, 'UTC');
      expect(() => result.legacy.items.clear(), throwsUnsupportedError);
    });

    test('ambas secciones vacías son válidas', () {
      final result = LogisticaDeliveryListPage.fromJson(page(items: []));
      expect(result.current.items, isEmpty);
      expect(result.legacy.items, isEmpty);
      expect(result.current.nextCursor, isNull);
      expect(result.legacy.nextCursor, isNull);
    });

    for (final source in [null, '', 'OTHER', 'current', 1]) {
      test('source obligatorio y estricto: $source', () {
        expect(
            () => LogisticaDeliveryListItem.fromJson(
                {...item(), 'source': source}),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      });
    }

    test('LEGACY no se acepta dentro de CURRENT ni a la inversa', () {
      for (final body in [
        page(items: [legacyItem()]),
        page(items: [], legacyItems: [item()])
      ]) {
        expect(() => LogisticaDeliveryListPage.fromJson(body),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
    });

    test('legacy requiere todos sus campos incluso los null', () {
      for (final key in legacyItem().keys) {
        final incomplete = legacyItem()..remove(key);
        expect(() => LogisticaDeliveryListItem.fromJson(incomplete),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
    });

    test('LEGACY rechaza semántica moderna o inferencia de zona', () {
      for (final patch in [
        {'status': 'COMPLETED'},
        {'created_at': '2023-12-04T10:29:47Z'},
        {'time_zone': 'UTC'},
        {'time_zone': 'America/Mexico_City'},
        {'photo_count': 17},
        {'legacy_record_state': null},
        {'legacy_image_count': null},
        {'legacy_image_count': '17'},
        {'legacy_image_count': 1.5},
        {'recorded_local_at': null},
        {'id': 1},
      ]) {
        expect(
            () =>
                LogisticaDeliveryListItem.fromJson({...legacyItem(), ...patch}),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
    });

    test('CURRENT rechaza mezcla de campos históricos', () {
      for (final patch in [
        {'recorded_local_at': '2023-12-04T10:29:47'},
        {'legacy_record_state': 'RECORDED'},
        {'legacy_image_count': 15},
        {'time_zone': null},
        {'created_at': null},
      ]) {
        expect(() => LogisticaDeliveryListItem.fromJson({...item(), ...patch}),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
    });

    test('hora histórica permanece literal incluso en reloj con riesgo DST',
        () {
      for (final clock in [
        '2023-12-04T10:29:47',
        '2024-03-10T02:30:00',
        '2024-02-29T23:59:59.123456',
      ]) {
        final parsed = LogisticaDeliveryListItem.fromJson(
            {...legacyItem(), 'recorded_local_at': clock});
        expect(parsed.recordedLocalAt, clock);
        expect(parsed.recordedLocalAt, isA<String>());
        expect(parsed.createdAt, isNull);
      }
    });

    test('fecha histórica inválida, Z u offset fallan sin normalizar', () {
      for (final clock in [
        '2023-02-29T10:29:47',
        '2024-02-30T10:29:47',
        '2024-00-01T10:29:47',
        '2024-01-01T24:00:00',
        '2024-01-01T10:60:00',
        '2024-01-01T10:00:60',
        '0000-01-01T00:00:00',
        '2023-12-04T10:29:47Z',
        '2023-12-04T10:29:47-06:00',
        '2023-12-04T10:29:47+00:00',
      ]) {
        expect(
            () => LogisticaDeliveryListItem.fromJson(
                {...legacyItem(), 'recorded_local_at': clock}),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
    });

    test('estructura legacy/cursor defectuosos no se presentan como vacío', () {
      for (final section in <Object?>[
        null,
        [],
        {'items': []},
        {'items': [], 'next_cursor': 3},
        {
          'items': [legacyItem()],
          'next_cursor': ''
        },
        {'items': [], 'next_cursor': 'orphan'},
      ]) {
        expect(
            () => LogisticaDeliveryListPage.fromJson(
                {...page(), 'legacy': section}),
            throwsA(failure(LogisticaDeliveryListFailure.invalidResponse)));
      }
    });

    test('cada cursor se envía en su parámetro, sin reciclar el otro',
        () async {
      for (final current in [true, false]) {
        await service((request) async {
          expect(request.url.queryParameters, {
            'limit': '25',
            'pedido': 'Pedido +/? á',
            if (current) 'current_cursor': 'C+/=%',
            if (!current) 'legacy_cursor': 'L+/=%',
          });
          return jsonResponse(page(items: []));
        }).fetchPage(
            pedido: 'Pedido +/? á',
            currentCursor: current ? 'C+/=%' : null,
            legacyCursor: current ? null : 'L+/=%');
      }
    });

    testWidgets('secciones vacías tienen mensajes propios', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Registroentregas(
        service: service((_) async => jsonResponse(page(items: []))),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Entregas actuales'), findsOneWidget);
      expect(find.text('Registros históricos'), findsOneWidget);
      expect(find.text('No hay entregas actuales.'), findsOneWidget);
      expect(
          find.text('No hay registros históricos asociados.'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('legacy muestra RECORDED y reloj literal, nunca fotos subidas',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Registroentregas(
              service: service((_) async => jsonResponse(
                  page(items: [], legacyItems: [legacyItem()]))))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pedido: LEGACY-A'));
      await tester.pumpAndSettle();
      expect(find.text('Registro histórico'), findsOneWidget);
      expect(find.text('Usuario declarado: Usuario histórico'), findsOneWidget);
      expect(find.text('Correo declarado: declarado@example.invalid'),
          findsOneWidget);
      expect(find.text('Fecha registrada: 2023-12-04'), findsOneWidget);
      expect(find.text('Hora registrada: 10:29:47'), findsOneWidget);
      expect(find.text('Estado del registro: RECORDED'), findsOneWidget);
      expect(find.text('Contador de imágenes legacy (declarado): 17'),
          findsOneWidget);
      expect(find.textContaining('Img Subidas'), findsNothing);
      expect(find.textContaining('COMPLETED'), findsNothing);
      expect(find.textContaining('UTC'), findsNothing);
      expect(find.textContaining('PHOTO UPLOADED'), findsNothing);
    });

    testWidgets(
        'paginación independiente preserva otra sección/cursor y source+id',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final requests = <Uri>[];
      await tester.pumpWidget(
          MaterialApp(home: Registroentregas(service: service((request) async {
        requests.add(request.url);
        final query = request.url.queryParameters;
        if (query.containsKey('current_cursor')) {
          expect(query['current_cursor'], 'C1');
          expect(query.containsKey('legacy_cursor'), isFalse);
          return jsonResponse(page(
              items: [item(), item(id: '2', pedido: 'CURRENT-B')],
              cursor: 'C2',
              legacyItems: [legacyItem(pedido: 'IGNORE-LEGACY')],
              legacyCursor: 'IGNORE-L'));
        }
        if (query.containsKey('legacy_cursor')) {
          expect(query['legacy_cursor'], 'L1');
          expect(query.containsKey('current_cursor'), isFalse);
          return jsonResponse(page(
              items: [item(pedido: 'IGNORE-CURRENT')],
              cursor: 'IGNORE-C',
              legacyItems: [
                legacyItem(id: '1'),
                legacyItem(id: '2', pedido: 'LEGACY-B')
              ]));
        }
        return jsonResponse(page(
            cursor: 'C1',
            legacyItems: [legacyItem(id: '1')],
            legacyCursor: 'L1'));
      }))));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('current:1')), findsOneWidget);
      expect(find.byKey(const ValueKey('legacy:1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('more-current')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-legacy')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('current:1')), findsOneWidget);
      expect(find.byKey(const ValueKey('legacy:1')), findsOneWidget);
      expect(find.byKey(const ValueKey('current:2')), findsOneWidget);
      expect(find.byKey(const ValueKey('legacy:2')), findsOneWidget);
      expect(find.textContaining('IGNORE-'), findsNothing);
      expect(find.byKey(const ValueKey('more-current')), findsOneWidget);
      expect(find.byKey(const ValueKey('more-legacy')), findsNothing);
      expect(requests.length, 3);
    });

    testWidgets(
        'error adicional LEGACY conserva datos y permite reintentar solo su cursor',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var calls = 0;
      await tester.pumpWidget(
          MaterialApp(home: Registroentregas(service: service((request) async {
        calls++;
        if (calls == 1) {
          return jsonResponse(
              page(legacyItems: [legacyItem()], legacyCursor: 'L1'));
        }
        expect(request.url.queryParameters['legacy_cursor'], 'L1');
        expect(
            request.url.queryParameters.containsKey('current_cursor'), isFalse);
        if (calls == 2) return jsonResponse({}, 500);
        return jsonResponse(page(
            items: [], legacyItems: [legacyItem(id: '2', pedido: 'LEGACY-B')]));
      }))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-legacy')));
      await tester.pumpAndSettle();
      expect(find.text('Pedido: PEDIDO-A'), findsOneWidget);
      expect(find.text('Pedido: LEGACY-A'), findsOneWidget);
      expect(find.byKey(const ValueKey('retry-legacy')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('retry-legacy')));
      await tester.pumpAndSettle();
      expect(find.text('Pedido: PEDIDO-A'), findsOneWidget);
      expect(find.text('Pedido: LEGACY-A'), findsOneWidget);
      expect(find.text('Pedido: LEGACY-B'), findsOneWidget);
    });

    testWidgets(
        'cambiar búsqueda reinicia ambos cursores e ignora respuestas antiguas',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final old = Completer<http.Response>();
      final requests = <Uri>[];
      await tester.pumpWidget(
          MaterialApp(home: Registroentregas(service: service((request) async {
        requests.add(request.url);
        if (request.url.queryParameters.containsKey('legacy_cursor')) {
          return old.future;
        }
        if (request.url.queryParameters.containsKey('pedido')) {
          return jsonResponse(page(items: []));
        }
        return jsonResponse(page(
            cursor: 'C1', legacyItems: [legacyItem()], legacyCursor: 'L1'));
      }))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-legacy')));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'SIN-MATCH');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(requests.last.queryParameters,
          {'limit': '25', 'pedido': 'SIN-MATCH'});
      old.complete(jsonResponse(page(
          legacyItems: [legacyItem(pedido: 'OLD')], legacyCursor: 'STALE')));
      await tester.pumpAndSettle();
      expect(find.text('No se encontraron pedidos.'), findsOneWidget);
      expect(find.text('No hay registros históricos asociados.'), findsNothing);
      expect(find.text('Pedido: OLD'), findsNothing);
      expect(find.byKey(const ValueKey('more-current')), findsNothing);
      expect(find.byKey(const ValueKey('more-legacy')), findsNothing);
    });

    testWidgets(
        'cargas adicionales simultáneas no pisan secciones ni usan widget desmontado',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final c = Completer<http.Response>(), l = Completer<http.Response>();
      await tester.pumpWidget(
          MaterialApp(home: Registroentregas(service: service((request) async {
        if (request.url.queryParameters.containsKey('current_cursor')) {
          return c.future;
        }
        if (request.url.queryParameters.containsKey('legacy_cursor')) {
          return l.future;
        }
        return jsonResponse(page(
            cursor: 'C1', legacyItems: [legacyItem()], legacyCursor: 'L1'));
      }))));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('more-current')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('more-legacy')));
      await tester.pump();
      expect(find.byKey(const ValueKey('loading-current')), findsOneWidget);
      expect(find.byKey(const ValueKey('loading-legacy')), findsOneWidget);
      c.complete(jsonResponse(
          page(items: [item(id: '2', pedido: 'CURRENT-B')], legacyItems: [])));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Pedido: CURRENT-B'), findsOneWidget);
      expect(find.text('Pedido: LEGACY-A'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      l.complete(
          jsonResponse(page(items: [], legacyItems: [legacyItem(id: '2')])));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  for (final url in [
    'https://backend.example/api10',
    'https://backend.example:8443/api10',
  ]) {
    test('Historial HTTPS con Bearer, búsqueda y dos cursores: $url', () async {
      const pedido = 'Pedido + /?&= á漢#%_';
      await service((request) async {
        expect(request.url.scheme, 'https');
        expect(request.url.origin, Uri.parse(url).origin);
        expect(request.url.path, '/api10/logistica/entregas/historial');
        expect(request.url.queryParameters, {
          'limit': '1',
          'pedido': pedido,
          'current_cursor': 'C+/=%',
          'legacy_cursor': 'L+/=%',
        });
        expect(request.headers['Authorization'], 'Bearer TEST_ONLY_TOKEN');
        return jsonResponse(page(items: [], legacyItems: []));
      }, baseUrl: url)
          .fetchPage(
              pedido: pedido,
              currentCursor: 'C+/=%',
              legacyCursor: 'L+/=%',
              limit: 1);
    });
  }

  test('Historial con configuración inválida no solicita token ni HTTP',
      () async {
    for (final url in [
      '',
      'http://servidor-real/api10',
      'https://backend.example/otra-ruta',
      'https://user:TEST_ONLY_PASSWORD@backend.example/api10',
      'https://backend.example/api10#fragment',
    ]) {
      var tokens = 0;
      final clients = <TestClient>[];
      final api = service((_) async => jsonResponse(page()), baseUrl: url,
          auth: TestAuth(TestUser(() async {
        tokens++;
        return 'TEST_ONLY';
      })), clients: clients);
      await expectLater(api.fetchPage(),
          throwsA(failure(LogisticaDeliveryListFailure.configuration)));
      expect(tokens, 0);
      expect(clients, isEmpty);
    }
  });
}
