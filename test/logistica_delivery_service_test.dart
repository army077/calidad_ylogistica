import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sistema_rastreabilidad/services/logistica_delivery_service.dart';

Uint8List jpeg() => Uint8List.fromList([255, 216, 255, 224, 1, 2, 3]);
Uint8List png() => Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);

DeliveryAttempt attempt({
  List<Uint8List>? photos,
  Uint8List? signature,
}) =>
    DeliveryAttempt.freeze(
      pedido: '000123',
      equipos: 'EQUIPO TEST',
      chofer: 'CHOFER TEST',
      observaciones: 'PRUEBA AISLADA',
      instalara: 'No',
      latitude: 20.123456,
      longitude: -103.123456,
      appVersion: 'v5',
      photos: photos ?? [jpeg()],
      signature: signature ?? png(),
    );

class FakeClient extends http.BaseClient {
  FakeClient(this.handler);

  final Future<http.Response> Function(http.BaseRequest) handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() => closed = true;
}

http.Response jsonResponse(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {
      'content-type': 'application/json; charset=utf-8',
    });

http.Response normalResponse(
  http.BaseRequest request, {
  int createStatus = 201,
  int uploadStatus = 201,
  bool finalizeReplay = false,
}) {
  if (request.url.path.endsWith('/entregas')) {
    final payload =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    return jsonResponse({
      'ok': true,
      'idempotent_replay': createStatus == 200,
      'delivery': {
        'id': '1',
        'client_request_id': payload['client_request_id'],
        'status': 'PENDING_EVIDENCE',
      },
    }, createStatus);
  }
  if (request.url.path.endsWith('/evidencias')) {
    final multipart = request as http.MultipartRequest;
    return jsonResponse({
      'ok': true,
      'idempotent_replay': uploadStatus == 200,
      'evidence': {
        'id': multipart.fields['evidence_type'] == 'PHOTO' ? '10' : '11',
        'client_evidence_id': multipart.fields['client_evidence_id'],
        'evidence_type': multipart.fields['evidence_type'],
        'sequence_no': 1,
        'status': 'UPLOADED',
      },
    }, uploadStatus);
  }
  expect(request.url.path, '/api10/logistica/entregas/1/finalizar');
  expect((request as http.Request).bodyBytes, isEmpty);
  return jsonResponse({
    'ok': true,
    'idempotent_replay': finalizeReplay,
    'delivery': {
      'id': '1',
      'status': 'COMPLETED',
      'completed_at': '2026-10-20T12:00:00.000Z',
    },
  }, 200);
}

LogisticaDeliveryService service(
  Future<http.Response> Function(http.BaseRequest) handler, {
  Future<String?> Function()? tokenProvider,
  Duration timeout = const Duration(seconds: 1),
  List<FakeClient>? clients,
}) =>
    LogisticaDeliveryService(
      tokenProvider: tokenProvider ?? () async => 'TEST_ONLY_TOKEN',
      requestTimeout: timeout,
      uploadTimeout: timeout,
      clientFactory: () {
        final client = FakeClient(handler);
        clients?.add(client);
        return client;
      },
    );

Matcher apiError([int? status]) => isA<DeliveryApiException>().having(
      (e) => status == null || e.statusCode == status,
      'status',
      isTrue,
    );

void main() {
  test('Congela UUID, payload y bytes sin conservar referencias editables', () {
    final photo = jpeg();
    final signature = png();
    final frozen = attempt(photos: [photo], signature: signature);
    photo[0] = 0;
    signature[0] = 0;
    expect(frozen.evidences.first.bytes, jpeg());
    expect(frozen.evidences.last.bytes, png());
    expect(frozen.creationPayload['pedido'], '000123');
    expect(frozen.creationPayload.keys, isNot(contains('correo')));
    expect(frozen.creationPayload.keys, isNot(contains('usuario')));
    expect(frozen.creationPayload.keys, isNot(contains('signature')));
    expect(frozen.creationPayload.keys, isNot(contains('imagenes')));
    final ids = [
      frozen.clientRequestId,
      ...frozen.evidences.map((e) => e.clientEvidenceId),
    ];
    expect(ids.toSet().length, 3);
    for (final id in ids) {
      expect(
          id,
          matches(RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          )));
    }
    expect(() => frozen.creationPayload['pedido'] = 'otro',
        throwsUnsupportedError);
    expect(() => frozen.evidences.first.bytes[0] = 0, throwsUnsupportedError);
  });

  test('JSON -> PHOTO JPEG -> SIGNATURE PNG -> finalizar; token por operación',
      () async {
    final frozen = attempt();
    final calls = <String>[];
    final clients = <FakeClient>[];
    var tokens = 0;
    final api = service((request) async {
      calls.add(request.url.path);
      expect(
          request.headers['Authorization'], 'Bearer TEST_ONLY_${calls.length}');
      if (request is http.MultipartRequest) {
        final isPhoto = request.fields['evidence_type'] == 'PHOTO';
        final evidence =
            isPhoto ? frozen.evidences.first : frozen.evidences.last;
        expect(request.fields.keys.toSet(),
            {'client_evidence_id', 'evidence_type'});
        expect(request.fields['client_evidence_id'], evidence.clientEvidenceId);
        expect(request.files.single.field, 'file');
        expect(request.files.single.filename,
            isPhoto ? 'photo_1.jpg' : 'signature.png');
        expect(request.files.single.contentType.toString(),
            isPhoto ? 'image/jpeg' : 'image/png');
        expect(await request.files.single.finalize().toBytes(), evidence.bytes);
      }
      return normalResponse(request);
    }, tokenProvider: () async => 'TEST_ONLY_${++tokens}', clients: clients);
    await api.send(frozen);
    expect(frozen.completed, isTrue);
    expect(frozen.deliveryId, '1');
    expect(tokens, 4);
    expect(calls, [
      '/api10/logistica/entregas',
      '/api10/logistica/entregas/1/evidencias',
      '/api10/logistica/entregas/1/evidencias',
      '/api10/logistica/entregas/1/finalizar',
    ]);
    expect(clients.every((c) => c.closed), isTrue);
  });

  test('Acepta creación y evidencias como replay HTTP 200', () async {
    final frozen = attempt();
    await service((request) async => normalResponse(
          request,
          createStatus: 200,
          uploadStatus: 200,
          finalizeReplay: true,
        )).send(frozen);
    expect(frozen.completed, isTrue);
  });

  for (final status in [400, 401, 403, 409, 500]) {
    test('HTTP $status conserva intento y no produce éxito', () async {
      final frozen = attempt();
      final ids = frozen.evidences.map((e) => e.clientEvidenceId).toList();
      await expectLater(
        service((_) async => jsonResponse({'error': 'Error público'}, status))
            .send(frozen),
        throwsA(apiError(status)),
      );
      expect(frozen.completed, isFalse);
      expect(frozen.deliveryId, isNull);
      expect(frozen.evidences.map((e) => e.clientEvidenceId), ids);
    });
  }

  test('HTTP 202 detiene el flujo y retry conserva PHOTO UUID y bytes',
      () async {
    final frozen = attempt();
    var pending = true;
    var creations = 0;
    var photoRequests = 0;
    var finalizations = 0;
    final photoIds = <String>[];
    final photoBytes = <List<int>>[];
    final api = service((request) async {
      if (request.url.path.endsWith('/entregas')) creations++;
      if (request is http.MultipartRequest &&
          request.fields['evidence_type'] == 'PHOTO') {
        photoRequests++;
        photoIds.add(request.fields['client_evidence_id']!);
        photoBytes.add(await request.files.single.finalize().toBytes());
        if (pending) {
          return jsonResponse({'ok': true, 'status': 'PENDING'}, 202);
        }
      }
      if (request.url.path.endsWith('/finalizar')) finalizations++;
      return normalResponse(request);
    });
    await expectLater(api.send(frozen), throwsA(apiError(202)));
    expect(frozen.deliveryId, '1');
    expect(frozen.isConfirmed(frozen.evidences.first), isFalse);
    expect(finalizations, 0);
    pending = false;
    await api.send(frozen);
    expect(creations, 1);
    expect(photoRequests, 2);
    expect(photoIds.toSet(), {frozen.evidences.first.clientEvidenceId});
    expect(photoBytes[0], photoBytes[1]);
    expect(frozen.completed, isTrue);
  });

  test('Retry omite PHOTO confirmada y reutiliza SIGNATURE fallida', () async {
    final frozen = attempt();
    var failSignature = true;
    var photos = 0;
    var signatures = 0;
    var creations = 0;
    final signatureIds = <String>[];
    final signatureBytes = <List<int>>[];
    final api = service((request) async {
      if (request.url.path.endsWith('/entregas')) creations++;
      if (request is http.MultipartRequest) {
        if (request.fields['evidence_type'] == 'PHOTO') {
          photos++;
        } else {
          signatures++;
          signatureIds.add(request.fields['client_evidence_id']!);
          signatureBytes.add(await request.files.single.finalize().toBytes());
          if (failSignature) return jsonResponse({'error': 'Temporal'}, 500);
        }
      }
      return normalResponse(request, uploadStatus: failSignature ? 201 : 200);
    });
    await expectLater(api.send(frozen), throwsA(apiError(500)));
    expect(frozen.isConfirmed(frozen.evidences.first), isTrue);
    expect(frozen.isConfirmed(frozen.evidences.last), isFalse);
    failSignature = false;
    await api.send(frozen);
    expect(creations, 1);
    expect(photos, 1);
    expect(signatures, 2);
    expect(signatureIds.toSet(), {frozen.evidences.last.clientEvidenceId});
    expect(signatureBytes[0], signatureBytes[1]);
  });

  test('Timeout de creación reenvía exactamente el mismo payload y UUID',
      () async {
    final frozen = attempt();
    final blocked = Completer<http.Response>();
    final payloads = <String>[];
    var first = true;
    final api = service((request) async {
      if (request.url.path.endsWith('/entregas')) {
        payloads.add((request as http.Request).body);
        if (first) {
          first = false;
          return blocked.future;
        }
        return normalResponse(request, createStatus: 200);
      }
      return normalResponse(request);
    }, timeout: const Duration(milliseconds: 20));
    await expectLater(api.send(frozen), throwsA(apiError()));
    blocked.complete(jsonResponse({}, 201));
    expect(frozen.deliveryId, isNull);
    await api.send(frozen);
    expect(payloads.length, 2);
    expect(payloads[0], payloads[1]);
    expect(frozen.completed, isTrue);
  });

  test('Error de red conserva estado y cierra el cliente', () async {
    final frozen = attempt();
    final clients = <FakeClient>[];
    await expectLater(
      service((_) async => throw http.ClientException('TEST_ONLY_NETWORK'),
              clients: clients)
          .send(frozen),
      throwsA(apiError()),
    );
    expect(frozen.completed, isFalse);
    expect(clients.single.closed, isTrue);
  });

  test('Token ausente no envía HTTP; sesión perdida conserva delivery.id',
      () async {
    final frozen = attempt();
    var requests = 0;
    var tokenCalls = 0;
    final api = service((request) async {
      requests++;
      return normalResponse(request);
    }, tokenProvider: () async => ++tokenCalls == 1 ? 'TEST_ONLY' : null);
    await expectLater(api.send(frozen), throwsA(apiError(401)));
    expect(requests, 1);
    expect(frozen.deliveryId, '1');
    expect(frozen.completed, isFalse);
    await expectLater(
      service((_) async => fail('No debe enviar HTTP'),
          tokenProvider: () async => null).send(attempt()),
      throwsA(apiError(401)),
    );
  });

  test('HTML y JSON inesperado no se aceptan como creación exitosa', () async {
    for (final body in ['<html>error</html>', '[]', '{"ok":true}']) {
      final frozen = attempt();
      await expectLater(
        service((_) async => http.Response(body, 201)).send(frozen),
        throwsA(apiError()),
      );
      expect(frozen.completed, isFalse);
      expect(frozen.deliveryId, isNull);
    }
  });

  test('HTTP 200 sin COMPLETED nunca confirma éxito', () async {
    final frozen = attempt();
    await expectLater(
      service((request) async {
        if (request.url.path.endsWith('/finalizar')) {
          return jsonResponse({
            'ok': true,
            'idempotent_replay': false,
            'delivery': {'id': '1', 'status': 'PENDING_EVIDENCE'},
          }, 200);
        }
        return normalResponse(request);
      }).send(frozen),
      throwsA(apiError()),
    );
    expect(frozen.completed, isFalse);
    expect(frozen.evidences.every(frozen.isConfirmed), isTrue);
  });

  test('Retry tras fallo de finalizar solo vuelve a finalizar', () async {
    final frozen = attempt();
    var failFinalize = true;
    var creates = 0;
    var uploads = 0;
    var finalizes = 0;
    final api = service((request) async {
      if (request.url.path.endsWith('/entregas')) creates++;
      if (request.url.path.endsWith('/evidencias')) uploads++;
      if (request.url.path.endsWith('/finalizar')) {
        finalizes++;
        if (failFinalize) return jsonResponse({'error': 'Temporal'}, 500);
      }
      return normalResponse(request, finalizeReplay: true);
    });
    await expectLater(api.send(frozen), throwsA(apiError(500)));
    failFinalize = false;
    await api.send(frozen);
    expect(creates, 1);
    expect(uploads, 2);
    expect(finalizes, 2);
    expect(frozen.completed, isTrue);
  });

  test('Rechaza límites y formatos antes de crear el intento', () {
    final bigPhoto = Uint8List(deliveryPhotoMaxBytes + 1)
      ..setRange(0, 3, [255, 216, 255]);
    final bigSignature = Uint8List(deliverySignatureMaxBytes + 1)
      ..setRange(0, 8, png().take(8));
    for (final photos in [
      <Uint8List>[],
      List.generate(16, (_) => jpeg()),
      [bigPhoto],
      [png()],
    ]) {
      expect(() => attempt(photos: photos), throwsA(apiError()));
    }
    expect(() => attempt(signature: bigSignature), throwsA(apiError()));
    expect(() => attempt(signature: jpeg()), throwsA(apiError()));
    final exactPhoto = Uint8List(deliveryPhotoMaxBytes)
      ..setRange(0, 3, [255, 216, 255]);
    final exactSignature = Uint8List(deliverySignatureMaxBytes)
      ..setRange(0, 8, png().take(8));
    expect(
      () => attempt(photos: [exactPhoto], signature: exactSignature),
      returnsNormally,
    );
  });

  test('Configuración ajena al endpoint LOCAL se rechaza sin HTTP', () async {
    final api = LogisticaDeliveryService(
      tokenProvider: () async => 'TEST_ONLY',
      baseUrl: 'https://example.invalid/api10',
      clientFactory: () => throw StateError('No debe enviar HTTP'),
    );
    await expectLater(api.send(attempt()), throwsA(apiError()));
  });

  test('El checkpoint inicial debe terminar antes del primer HTTP', () async {
    final frozen = attempt();
    final ready = Completer<void>();
    var requests = 0;
    var checkpoints = 0;
    final api = service((request) async {
      requests++;
      return normalResponse(request);
    });
    final sending = api.send(frozen, persist: (value) async {
      checkpoints++;
      if (checkpoints == 1) await ready.future;
    });
    await Future<void>.delayed(Duration.zero);
    expect(requests, 0);
    ready.complete();
    await sending;
    expect(requests, 4);
    expect(checkpoints, 5);
  });

  test('Fallo de guardado inicial no permite HTTP', () async {
    var requests = 0;
    await expectLater(
      service((request) async {
        requests++;
        return normalResponse(request);
      }).send(attempt(),
          persist: (_) async => throw StateError('TEST_ONLY_DISK')),
      throwsStateError,
    );
    expect(requests, 0);
  });

  test('Fallo de checkpoint después de create detiene HTTP posterior',
      () async {
    final frozen = attempt();
    var requests = 0;
    final api = service((request) async {
      requests++;
      return normalResponse(request);
    });
    await expectLater(
        api.send(frozen, persist: (value) async {
          if (value.deliveryId != null) throw StateError('TEST_ONLY_DISK');
        }),
        throwsStateError);
    expect(requests, 1);
    expect(frozen.deliveryId, '1');
    await api.send(frozen, persist: (_) async {});
    expect(requests, 4);
    expect(frozen.completed, isTrue);
  });

  test('Fallo de checkpoint de PHOTO detiene la firma y conserva confirmación',
      () async {
    final frozen = attempt();
    var requests = 0;
    final api = service((request) async {
      requests++;
      return normalResponse(request);
    });
    await expectLater(
        api.send(frozen, persist: (value) async {
          if (value.isConfirmed(value.evidences.first)) {
            throw StateError('TEST_ONLY_DISK');
          }
        }),
        throwsStateError);
    expect(requests, 2);
    expect(frozen.isConfirmed(frozen.evidences.first), isTrue);
    await api.send(frozen, persist: (_) async {});
    expect(requests, 4);
    expect(frozen.completed, isTrue);
  });

  test('Fallo de checkpoint COMPLETED reintenta guardado sin HTTP', () async {
    final frozen = attempt();
    var requests = 0;
    final api = service((request) async {
      requests++;
      return normalResponse(request);
    });
    await expectLater(
        api.send(frozen, persist: (value) async {
          if (value.completed) throw StateError('TEST_ONLY_DISK');
        }),
        throwsStateError);
    expect(frozen.completed, isTrue);
    expect(requests, 4);
    var terminalSaves = 0;
    await api.send(frozen, persist: (value) async {
      expect(value.completed, isTrue);
      terminalSaves++;
    });
    expect(terminalSaves, 1);
    expect(requests, 4);
  });
}
