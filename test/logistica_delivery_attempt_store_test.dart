import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sistema_rastreabilidad/services/logistica_delivery_attempt_store.dart';
import 'package:sistema_rastreabilidad/services/logistica_delivery_service.dart';

import 'logistica_delivery_service_test.dart' as fixture;

const uid = 'TEST_ONLY_UID';
const baseUrl = 'http://localhost:3010/api10';

void main() {
  late Directory root;
  late LogisticaDeliveryAttemptStore store;
  late DeliveryAttempt original;

  Directory pending() => Directory(
        '${root.path}${Platform.pathSeparator}logistica_delivery_attempt',
      );
  File pendingFile(String name) => File(
        '${pending().path}${Platform.pathSeparator}$name',
      );
  Future<void> save(DeliveryAttempt attempt) =>
      store.save(attempt, firebaseUid: uid, apiBaseUrl: baseUrl);
  Future<DeliveryAttempt?> load({
    String firebaseUid = uid,
    String apiBaseUrl = baseUrl,
    bool cleanupCompleted = false,
  }) =>
      store.load(
        firebaseUid: firebaseUid,
        apiBaseUrl: apiBaseUrl,
        cleanupCompleted: cleanupCompleted,
      );
  Future<Map<String, dynamic>> manifest() async =>
      jsonDecode(await pendingFile('manifest.json').readAsString())
          as Map<String, dynamic>;
  Future<void> rewrite(void Function(Map<String, dynamic>) change) async {
    final data = await manifest();
    data.remove('manifestCrc32');
    change(data);
    var crc = 0xffffffff;
    for (final byte in utf8.encode(jsonEncode(data))) {
      crc ^= byte;
      for (var i = 0; i < 8; i++) {
        crc = (crc & 1) != 0 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
      }
    }
    data['manifestCrc32'] =
        ((crc ^ 0xffffffff) & 0xffffffff).toRadixString(16).padLeft(8, '0');
    await pendingFile('manifest.json')
        .writeAsString(jsonEncode(data), flush: true);
  }

  DeliveryAttempt progress({int confirmed = 0, bool completed = false}) {
    final data =
        jsonDecode(jsonEncode(original.toMetadata())) as Map<String, dynamic>;
    data['deliveryId'] = '1';
    data['completed'] = completed;
    data['confirmedEvidenceIds'] = original.evidences
        .take(confirmed)
        .map((e) => e.clientEvidenceId)
        .toList();
    return DeliveryAttempt.restore(
      data,
      original.evidences.map((e) => e.bytes).toList(),
    );
  }

  Future<void> cleanup(DeliveryAttempt attempt) => store.cleanup(
        firebaseUid: uid,
        apiBaseUrl: baseUrl,
        clientRequestId: attempt.clientRequestId,
      );
  final storeError = isA<DeliveryAttemptStoreException>();

  setUp(() async {
    root = await Directory.systemTemp.createTemp('delivery_attempt_test_');
    store = LogisticaDeliveryAttemptStore(rootDirectory: root);
    original = fixture.attempt();
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  test('Sin pendiente devuelve null sin invocar path_provider', () async {
    expect(await load(), isNull);
    final injected =
        LogisticaDeliveryAttemptStore(directoryResolver: () async => root);
    expect(await injected.load(firebaseUid: uid, apiBaseUrl: baseUrl), isNull);
  });

  test('Guardar y cargar conserva clientRequestId', () async {
    await save(original);
    expect((await load())!.clientRequestId, original.clientRequestId);
  });

  test('Conserva todos los clientEvidenceId y el orden', () async {
    await save(original);
    expect((await load())!.evidences.map((e) => e.clientEvidenceId),
        original.evidences.map((e) => e.clientEvidenceId));
  });

  test('Conserva payload exacto y bytes byte a byte sin Base64', () async {
    await save(original);
    final restored = (await load())!;
    expect(restored.creationPayload, original.creationPayload);
    for (var i = 0; i < original.evidences.length; i++) {
      expect(restored.evidences[i].bytes, original.evidences[i].bytes);
    }
    final data = await manifest();
    expect(data['schemaVersion'], 1);
    expect(data['firebaseUid'], uid);
    expect(data['apiBaseUrl'], baseUrl);
    for (final item in data['evidences'] as List) {
      expect(item.keys, isNot(contains('bytes')));
      expect(item.keys, isNot(contains('base64')));
      expect(
          item.keys,
          containsAll([
            'clientEvidenceId',
            'type',
            'filename',
            'mimeType',
            'storedFilename',
          ]));
    }
    expect(data.keys, isNot(contains('token')));
    expect(() => restored.evidences.first.bytes[0] = 0, throwsUnsupportedError);
  });

  test('Conserva deliveryId validado', () async {
    await save(progress());
    expect((await load())!.deliveryId, '1');
  });

  test('Conserva confirmedEvidenceIds sin confirmar otras evidencias',
      () async {
    await save(progress(confirmed: 1));
    final restored = (await load())!;
    expect(restored.isConfirmed(restored.evidences.first), isTrue);
    expect(restored.isConfirmed(restored.evidences.last), isFalse);
  });

  test('Conserva completed y sus confirmaciones', () async {
    await save(progress(confirmed: 2, completed: true));
    final restored = (await load())!;
    expect(restored.completed, isTrue);
    expect(restored.evidences.every(restored.isConfirmed), isTrue);
  });

  test('UID distinto se rechaza sin borrar ni reemplazar', () async {
    await save(original);
    final before = await pendingFile('manifest.json').readAsBytes();
    await expectLater(load(firebaseUid: 'OTHER_UID'), throwsA(storeError));
    await expectLater(
      store.save(fixture.attempt(),
          firebaseUid: 'OTHER_UID', apiBaseUrl: baseUrl),
      throwsA(storeError),
    );
    expect(await pendingFile('manifest.json').readAsBytes(), before);
    expect((await load())!.clientRequestId, original.clientRequestId);
  });

  test('Backend distinto se rechaza sin borrar ni reemplazar', () async {
    await save(original);
    final before = await pendingFile('manifest.json').readAsBytes();
    const other = 'http://other-local:3010/api10';
    await expectLater(load(apiBaseUrl: other), throwsA(storeError));
    await expectLater(
      store.save(original, firebaseUid: uid, apiBaseUrl: other),
      throwsA(storeError),
    );
    expect(await pendingFile('manifest.json').readAsBytes(), before);
  });

  test('Manifiesto corrupto bloquea sin generar otro intento', () async {
    await save(original);
    await pendingFile('manifest.json').writeAsString('{incompleto');
    await expectLater(load(), throwsA(storeError));
    await expectLater(save(fixture.attempt()), throwsA(storeError));
    expect(await pendingFile('manifest.json').readAsString(), '{incompleto');
  });

  test('Corrupción de metadata válida como JSON se detecta por CRC', () async {
    await save(original);
    final data = await manifest();
    (data['creationPayload'] as Map)['pedido'] = '999999';
    await pendingFile('manifest.json').writeAsString(jsonEncode(data));
    await expectLater(load(), throwsA(storeError));
    expect(await pendingFile('manifest.json').exists(), isTrue);
  });

  test('Evidencia faltante bloquea sin borrar el manifiesto', () async {
    await save(original);
    await pendingFile('evidence_0.bin').delete();
    await expectLater(load(), throwsA(storeError));
    expect(await pendingFile('manifest.json').exists(), isTrue);
  });

  test('Corrupción de bytes del mismo tamaño se rechaza', () async {
    await save(original);
    final file = pendingFile('evidence_0.bin');
    final bytes = await file.readAsBytes();
    bytes[bytes.length - 1] ^= 1;
    await file.writeAsBytes(bytes);
    await expectLater(load(), throwsA(storeError));
    expect(await file.readAsBytes(), bytes);
    var requests = 0;
    await expectLater(
        fixture.service((request) async {
          requests++;
          return fixture.normalResponse(request);
        }).send(original, persist: save),
        throwsA(storeError));
    expect(requests, 0);
  });

  test('Manifiesto con rutas externas es rechazado sin tocar el exterior',
      () async {
    await save(original);
    final external = File('${root.path}${Platform.pathSeparator}outside.bin');
    await external.writeAsString('TEST_ONLY_KEEP');
    await rewrite((data) {
      (data['evidences'] as List).first['storedFilename'] = '../outside.bin';
    });
    await expectLater(load(), throwsA(storeError));
    expect(await external.readAsString(), 'TEST_ONLY_KEEP');
  });

  test('Versión desconocida y estado inconsistente bloquean', () async {
    await save(original);
    await rewrite((data) => data['schemaVersion'] = 99);
    await expectLater(load(), throwsA(storeError));
    await rewrite((data) {
      data['schemaVersion'] = 1;
      data['completed'] = true;
    });
    await expectLater(load(cleanupCompleted: true), throwsA(storeError));
    expect(await pendingFile('manifest.json').exists(), isTrue);
  });

  test('Directorio incompleto sin manifiesto bloquea nuevos UUID', () async {
    await pending().create();
    await pendingFile('evidence_0.bin').writeAsBytes(fixture.jpeg());
    await expectLater(load(), throwsA(storeError));
    await expectLater(save(original), throwsA(storeError));
    expect(await pendingFile('evidence_0.bin').readAsBytes(), fixture.jpeg());
  });

  test('No permite reemplazar un pendiente por otro intento', () async {
    await save(original);
    await expectLater(save(fixture.attempt()), throwsA(storeError));
    expect((await load())!.clientRequestId, original.clientRequestId);
  });

  test('No permite retroceder confirmaciones guardadas', () async {
    await save(progress(confirmed: 1));
    await expectLater(save(progress()), throwsA(storeError));
    final restored = (await load())!;
    expect(restored.isConfirmed(restored.evidences.first), isTrue);
  });

  test('Cleanup pendiente está prohibido y conserva archivos', () async {
    await save(original);
    await expectLater(cleanup(original), throwsA(storeError));
    expect((await load())!.clientRequestId, original.clientRequestId);
  });

  test('Cleanup COMPLETED elimina manifiesto y todos los archivos', () async {
    final completed = progress(confirmed: 2, completed: true);
    await save(completed);
    await cleanup(completed);
    expect(await pending().exists(), isFalse);
    expect(await root.list().toList(), isEmpty);
    await cleanup(completed);
    expect(await load(), isNull);
  });

  test('Recuperar COMPLETED solo limpia sin requerir HTTP', () async {
    await save(progress(confirmed: 2, completed: true));
    store = LogisticaDeliveryAttemptStore(rootDirectory: root);
    expect(await load(cleanupCompleted: true), isNull);
    expect(await pending().exists(), isFalse);
  });

  test('Cleanup interrumpido continúa aunque ya falten evidencias', () async {
    await save(progress(confirmed: 2, completed: true));
    await pendingFile('evidence_0.bin').delete();
    expect(await load(cleanupCompleted: true), isNull);
    expect(await pending().exists(), isFalse);
  });

  test('Guardado inicial fallido no permite HTTP', () async {
    final failing = LogisticaDeliveryAttemptStore(
      directoryResolver: () async =>
          throw const FileSystemException('TEST_ONLY_DISK'),
    );
    var requests = 0;
    final api = fixture.service((request) async {
      requests++;
      return fixture.normalResponse(request);
    });
    await expectLater(
      api.send(original,
          persist: (value) =>
              failing.save(value, firebaseUid: uid, apiBaseUrl: baseUrl)),
      throwsA(storeError),
    );
    expect(requests, 0);
  });

  test(
      'Manifiesto atrasado tras create recupera mismo payload y UUID por replay',
      () async {
    final requests = <String>[];
    final api = fixture.service((request) async {
      requests.add(request.url.path);
      return fixture.normalResponse(request);
    });
    await expectLater(
        api.send(original, persist: (value) async {
          if (value.deliveryId != null) {
            throw const DeliveryAttemptStoreException('TEST_ONLY_DISK');
          }
          await save(value);
        }),
        throwsA(storeError));
    expect(requests.length, 1);
    store = LogisticaDeliveryAttemptStore(rootDirectory: root);
    final restored = (await load())!;
    expect(restored.deliveryId, isNull);
    expect(restored.clientRequestId, original.clientRequestId);
    expect(restored.creationPayload, original.creationPayload);
    await fixture.service((request) async {
      if (request is http.Request && request.url.path.endsWith('/entregas')) {
        expect(request.body, jsonEncode(original.creationPayload));
      }
      if (request is http.MultipartRequest) {
        final photo = request.fields['evidence_type'] == 'PHOTO';
        final expected =
            photo ? original.evidences.first : original.evidences.last;
        expect(request.fields['client_evidence_id'], expected.clientEvidenceId);
        expect(await request.files.single.finalize().toBytes(), expected.bytes);
      }
      return fixture.normalResponse(request, createStatus: 200);
    }).send(restored, persist: save);
    expect((await load())!.completed, isTrue);
  });

  test('Recreación tras 202 repite PHOTO con los mismos UUID y bytes',
      () async {
    await expectLater(
        fixture.service((request) async {
          if (request is http.MultipartRequest) {
            return fixture.jsonResponse({'ok': true, 'status': 'PENDING'}, 202);
          }
          return fixture.normalResponse(request);
        }).send(original, persist: save),
        throwsA(fixture.apiError(202)));
    store = LogisticaDeliveryAttemptStore(rootDirectory: root);
    final restored = (await load())!;
    expect(restored.deliveryId, '1');
    final paths = <String>[];
    await fixture.service((request) async {
      paths.add(request.url.path);
      if (request is http.MultipartRequest) {
        final expected = request.fields['evidence_type'] == 'PHOTO'
            ? original.evidences.first
            : original.evidences.last;
        expect(request.fields['client_evidence_id'], expected.clientEvidenceId);
        expect(await request.files.single.finalize().toBytes(), expected.bytes);
      }
      return fixture.normalResponse(request);
    }).send(restored, persist: save);
    expect(paths.length, 3);
    expect(paths.any((path) => path.endsWith('/entregas')), isFalse);
  });

  test('Fallo real de escritura tras PHOTO conserva checkpoint anterior',
      () async {
    var block = true;
    await expectLater(
        fixture.service((request) async {
          if (request is http.MultipartRequest && block) {
            await Directory(pendingFile('manifest.tmp').path).create();
            block = false;
          }
          return fixture.normalResponse(request);
        }).send(original, persist: save),
        throwsA(storeError));
    expect(original.isConfirmed(original.evidences.first), isTrue);
    await Directory(pendingFile('manifest.tmp').path).delete();
    store = LogisticaDeliveryAttemptStore(rootDirectory: root);
    final restored = (await load())!;
    expect(restored.isConfirmed(restored.evidences.first), isFalse);
    expect(restored.deliveryId, '1');
    final photo = original.evidences.first;
    await fixture.service((request) async {
      if (request is http.MultipartRequest &&
          request.fields['evidence_type'] == 'PHOTO') {
        expect(request.fields['client_evidence_id'], photo.clientEvidenceId);
        expect(await request.files.single.finalize().toBytes(), photo.bytes);
        return fixture.normalResponse(request, uploadStatus: 200);
      }
      return fixture.normalResponse(request);
    }).send(restored, persist: save);
    expect(restored.completed, isTrue);
  });

  test('COMPLETED no guardado reanuda únicamente finalizar por replay',
      () async {
    await expectLater(
        fixture
            .service((request) async => fixture.normalResponse(request))
            .send(original, persist: (value) async {
          if (value.completed) {
            throw const DeliveryAttemptStoreException('TEST_ONLY_DISK');
          }
          await save(value);
        }),
        throwsA(storeError));
    store = LogisticaDeliveryAttemptStore(rootDirectory: root);
    final restored = (await load())!;
    expect(restored.completed, isFalse);
    expect(restored.evidences.every(restored.isConfirmed), isTrue);
    var calls = 0;
    await fixture.service((request) async {
      calls++;
      expect(request.url.path.endsWith('/finalizar'), isTrue);
      return fixture.normalResponse(request, finalizeReplay: true);
    }).send(restored, persist: save);
    expect(calls, 1);
    await cleanup(restored);
  });

  test('Cleanup retira por rename con manifiesto y bytes todavía intactos',
      () async {
    final completed = progress(confirmed: 2, completed: true);
    String? retiredPath;
    bool? activeExistedAtDelete;
    bool? manifestExistedAtDelete;
    List<int>? retiredPhoto;
    store = LogisticaDeliveryAttemptStore(
      rootDirectory: root,
      deleteCleanupDirectory: (directory) async {
        retiredPath = directory.path;
        activeExistedAtDelete = await pending().exists();
        manifestExistedAtDelete = await File(
                '${directory.path}${Platform.pathSeparator}manifest.json')
            .exists();
        retiredPhoto = await File(
                '${directory.path}${Platform.pathSeparator}evidence_0.bin')
            .readAsBytes();
        throw const FileSystemException('TEST_ONLY_INTERRUPTED_DELETE');
      },
    );
    await save(completed);
    await cleanup(completed);
    expect(activeExistedAtDelete, isFalse);
    expect(manifestExistedAtDelete, isTrue);
    expect(retiredPhoto, completed.evidences.first.bytes);
    expect(retiredPath, isNotNull);
    final retired = Directory(retiredPath!);
    expect(retired.parent.path, pending().parent.path);
    expect(retired.path.split(Platform.pathSeparator).last,
        startsWith('.cleanup-logistica_delivery_attempt-'));
    expect(await retired.exists(), isTrue);
    expect(await pending().exists(), isFalse);
    // The namespace is already empty even if recursive deletion never finished.
    expect(await load(cleanupCompleted: true), isNull);
  });

  test('Residuo cleanup corrupto no se interpreta como intento activo',
      () async {
    final residue =
        await root.createTemp('.cleanup-logistica_delivery_attempt-');
    final damaged =
        File('${residue.path}${Platform.pathSeparator}manifest.json');
    await damaged.writeAsString('{incompleto');
    var deleteCalls = 0;
    store = LogisticaDeliveryAttemptStore(
      rootDirectory: root,
      deleteCleanupDirectory: (_) async {
        deleteCalls++;
        throw const FileSystemException('TEST_ONLY_DELETE_DENIED');
      },
    );
    expect(await load(), isNull);
    expect(deleteCalls, greaterThan(0));
    expect(await damaged.readAsString(), '{incompleto');
  });

  test('Residuo no eliminable no bloquea guardar y cargar otro intento',
      () async {
    final residue =
        await root.createTemp('.cleanup-logistica_delivery_attempt-');
    await File('${residue.path}${Platform.pathSeparator}evidence_0.bin')
        .writeAsBytes(fixture.jpeg());
    store = LogisticaDeliveryAttemptStore(
      rootDirectory: root,
      deleteCleanupDirectory: (_) async =>
          throw const FileSystemException('TEST_ONLY_DELETE_DENIED'),
    );
    await save(original);
    final restored = (await load())!;
    expect(restored.clientRequestId, original.clientRequestId);
    expect(restored.creationPayload, original.creationPayload);
    for (var i = 0; i < original.evidences.length; i++) {
      expect(restored.evidences[i].clientEvidenceId,
          original.evidences[i].clientEvidenceId);
      expect(restored.evidences[i].bytes, original.evidences[i].bytes);
    }
    expect(await residue.exists(), isTrue);
  });

  test('Sweep de tombstones es local y no provoca replay HTTP', () async {
    final completed = progress(confirmed: 2, completed: true);
    await save(completed);
    final residue = await pending().rename(
      '${root.path}${Platform.pathSeparator}.cleanup-logistica_delivery_attempt-interrupted',
    );
    // Also simulate deletion interrupted after some files were already removed.
    await File('${residue.path}${Platform.pathSeparator}evidence_0.bin')
        .delete();
    var requests = 0;
    final api = fixture.service((request) async {
      requests++;
      return fixture.normalResponse(request);
    });
    store = LogisticaDeliveryAttemptStore(rootDirectory: root);
    final restored =
        await store.runExclusive(() => load(cleanupCompleted: true));
    if (restored != null) {
      await api.send(restored, persist: save);
    }
    expect(requests, 0);
    expect(restored, isNull);
    expect(await residue.exists(), isFalse);
    expect(await pending().exists(), isFalse);
  });

  test('Fallo de borrado de tombstone tampoco provoca replay HTTP', () async {
    final completed = progress(confirmed: 2, completed: true);
    await save(completed);
    await pending().rename(
      '${root.path}${Platform.pathSeparator}.cleanup-logistica_delivery_attempt-denied',
    );
    store = LogisticaDeliveryAttemptStore(
      rootDirectory: root,
      deleteCleanupDirectory: (_) async =>
          throw const FileSystemException('TEST_ONLY_DELETE_DENIED'),
    );
    var requests = 0;
    final api = fixture.service((request) async {
      requests++;
      return fixture.normalResponse(request);
    });
    final restored =
        await store.runExclusive(() => load(cleanupCompleted: true));
    if (restored != null) {
      await api.send(restored, persist: save);
    }
    expect(requests, 0);
    expect(restored, isNull);
    await save(original);
    expect((await load())!.clientRequestId, original.clientRequestId);
  });

  test('Tombstones no debilitan bloqueo de manifiesto activo corrupto',
      () async {
    await save(original);
    await pendingFile('manifest.json').writeAsString('{activo-corrupto');
    final residue =
        await root.createTemp('.cleanup-logistica_delivery_attempt-');
    await expectLater(load(cleanupCompleted: true), throwsA(storeError));
    await expectLater(save(fixture.attempt()), throwsA(storeError));
    expect(
        await pendingFile('manifest.json').readAsString(), '{activo-corrupto');
    expect(await pendingFile('evidence_0.bin').readAsBytes(), fixture.jpeg());
    expect(await residue.exists(), isFalse);
  });

  test('Sweep respeta directorios ajenos y archivos con prefijo reservado',
      () async {
    final unrelated = await root.createTemp('keep_');
    final marker = File('${unrelated.path}${Platform.pathSeparator}keep.txt');
    await marker.writeAsString('TEST_ONLY_KEEP');
    final reservedFile = File(
      '${root.path}${Platform.pathSeparator}.cleanup-logistica_delivery_attempt-file',
    );
    await reservedFile.writeAsString('TEST_ONLY_NOT_A_DIRECTORY');
    expect(await load(), isNull);
    expect(await marker.readAsString(), 'TEST_ONLY_KEEP');
    expect(await reservedFile.readAsString(), 'TEST_ONLY_NOT_A_DIRECTORY');
  });

  test('Exclusión compartida impide dos envíos y libera después de error',
      () async {
    final entered = Completer<void>();
    final release = Completer<void>();
    final first = store.runExclusive(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    final second = LogisticaDeliveryAttemptStore(rootDirectory: root);
    await expectLater(second.runExclusive(() async {}), throwsA(storeError));
    release.complete();
    await first;
    await expectLater(
      store.runExclusive(
          () async => throw const DeliveryApiException('TEST_ONLY_API')),
      throwsA(isA<DeliveryApiException>()),
    );
    await second.runExclusive(() async {});
  });
}
