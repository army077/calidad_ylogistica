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
      'id': id,
      'pedido': pedido,
      'auth_display_name': 'Usuario de prueba',
      'auth_email': 'prueba@example.invalid',
      'created_at': '2026-10-21T12:34:56.123456Z',
      'status': 'COMPLETED',
      'photo_count': 2,
    };

Map<String, Object?> page({List<Object?>? items, String? cursor}) => {
      'ok': true,
      'items': items ?? [item()],
      'next_cursor': cursor
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
      final delivery = result.items.single;
      expect(delivery.id, '1');
      expect(delivery.pedido, 'PEDIDO-A');
      expect(delivery.authDisplayName, 'Usuario de prueba');
      expect(delivery.authEmail, 'prueba@example.invalid');
      expect(delivery.status, 'COMPLETED');
      expect(delivery.photoCount, 2);
      expect(delivery.createdAt.isUtc, isTrue);
      expect(
          delivery.createdAt.toIso8601String(), '2026-10-21T12:34:56.123456Z');
      expect(result.nextCursor, isNull);
      expect(() => result.items.clear(), throwsUnsupportedError);
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
        'auth_display_name': null,
        'auth_email': null,
        'photo_count': 0,
      });
      expect(delivery.authDisplayName, isNull);
      expect(delivery.authEmail, isNull);
      expect(delivery.photoCount, 0);
    });
    test('next_cursor opaco se conserva', () {
      const cursor = 'opaque+/=%cursor';
      expect(
          LogisticaDeliveryListPage.fromJson(page(cursor: cursor)).nextCursor,
          cursor);
    });
    test('items vacío válido', () {
      final result = LogisticaDeliveryListPage.fromJson(page(items: []));
      expect(result.items, isEmpty);
      expect(result.nextCursor, isNull);
    });
    final badPages = <String, Object?>{
      'raíz no objeto': [],
      'ok false': {...page(), 'ok': false},
      'ok string': {...page(), 'ok': 'true'},
      'items no lista': {...page(), 'items': {}},
      'item no objeto': page(items: [null]),
      'cursor no string': {...page(), 'next_cursor': 1},
      'cursor vacío': page(cursor: ''),
      'cursor sin items': page(items: [], cursor: 'cursor'),
      'cursor faltante': {'ok': true, 'items': []},
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
      'auth_display_name': 4,
      'auth_email': [],
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
        expect(request.url.path, '/api10/logistica/entregas');
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
            {'limit': '1', 'pedido': pedido, 'cursor': cursor});
        return jsonResponse(page());
      }).fetchPage(pedido: pedido, cursor: cursor, limit: 1);
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
            {...item(pedido: 'Árbol 漢'), 'auth_display_name': 'José'}
          ]))).fetchPage();
      expect(result.items.single.pedido, 'Árbol 漢');
      expect(result.items.single.authDisplayName, 'José');
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
    test('URL ajena a API10 LOCAL no HTTP', () async {
      final clients = <TestClient>[];
      await expectLater(
          service((_) async => jsonResponse(page()),
                  baseUrl: 'https://example.invalid/api10', clients: clients)
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
      expect(find.text('No hay entregas registradas.'), findsNothing);
      response.complete(jsonResponse(page(items: [])));
      await tester.pumpAndSettle();
      expect(find.text('No hay entregas registradas.'), findsOneWidget);
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
      expect(find.text('No hay entregas registradas.'), findsNothing);
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('No hay entregas registradas.'), findsOneWidget);
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
      expect(requests[1].queryParameters['cursor'], 'EXACT_CURSOR');
      expect(requests[2].queryParameters['cursor'], 'EXACT_CURSOR');
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
        if (request.url.queryParameters.containsKey('cursor')) {
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
          {...item(), 'auth_display_name': null, 'auth_email': null}
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
}
