import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'logistica_delivery_service.dart';

class DeliveryAttemptStoreException implements Exception {
  const DeliveryAttemptStoreException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// One private pending slot. Call runExclusive around recovery or a full send.
class LogisticaDeliveryAttemptStore {
  LogisticaDeliveryAttemptStore({
    Directory? rootDirectory,
    Future<Directory> Function()? directoryResolver,
    Future<void> Function(Directory)? deleteCleanupDirectory,
  })  : _deleteCleanupDirectory = deleteCleanupDirectory ?? _deleteRecursively,
        _resolveDirectory = directoryResolver ??
            (rootDirectory == null
                ? getApplicationSupportDirectory
                : () async => rootDirectory);

  final Future<Directory> Function() _resolveDirectory;
  final Future<void> Function(Directory) _deleteCleanupDirectory;
  static final Set<String> _activeDirectories = {};
  String? _unpublishedKey;
  static const _manifestName = 'manifest.json';

  static const _cleanupPrefix = '.cleanup-logistica_delivery_attempt-';
  static int _cleanupSequence = 0;

  static Future<void> _deleteRecursively(Directory directory) async {
    await directory.delete(recursive: true);
  }

  Future<void> _tryDeleteCleanup(Directory directory, Directory parent) async {
    try {
      final target = directory.absolute;
      final name = target.path.split(Platform.pathSeparator).last;
      // Only direct sibling directories in this store's reserved namespace.
      // Never follow a symlink or accept a path from a manifest for deletion.
      if (target.parent.path != parent.absolute.path ||
          !name.startsWith(_cleanupPrefix) ||
          await FileSystemEntity.type(target.path, followLinks: false) !=
              FileSystemEntityType.directory) {
        return;
      }
      await _deleteCleanupDirectory(target);
    } catch (_) {
      // Retirement already succeeded. Residue must never block an active attempt.
    }
  }

  Future<void> _sweepCleanupDirectories(Directory parent) async {
    try {
      await for (final entity in parent.list(followLinks: false)) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (name.startsWith(_cleanupPrefix)) {
          await _tryDeleteCleanup(Directory(entity.path), parent);
        }
      }
    } catch (_) {
      // Listing/deleting old local residue is best-effort, independently of load.
    }
  }

  Future<Directory> _directory() async {
    final root = (await _resolveDirectory()).absolute;
    await _sweepCleanupDirectories(root);
    final directory = Directory(
      '${root.absolute.path}${Platform.pathSeparator}logistica_delivery_attempt',
    );
    final type =
        await FileSystemEntity.type(directory.path, followLinks: false);
    if (type != FileSystemEntityType.notFound &&
        type != FileSystemEntityType.directory) {
      throw const DeliveryAttemptStoreException(
        'El almacenamiento de Entregas no es un directorio seguro.',
      );
    }
    return directory;
  }

  File _file(Directory directory, String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  Future<T> runExclusive<T>(Future<T> Function() operation) async {
    late final Directory directory;
    try {
      directory = await _directory();
    } on DeliveryAttemptStoreException {
      rethrow;
    } catch (_) {
      throw const DeliveryAttemptStoreException(
        'No se pudo acceder al almacenamiento local. Revisa el pendiente antes de enviar.',
      );
    }
    final key = directory.absolute.path;
    if (!_activeDirectories.add(key)) {
      throw const DeliveryAttemptStoreException(
        'Hay otra operación de Entregas en curso. Espera y vuelve a revisar el pendiente.',
      );
    }
    try {
      return await operation();
    } finally {
      _activeDirectories.remove(key);
    }
  }

  static String _base(String value) => value.replaceFirst(RegExp(r'/+$'), '');

  Future<void> _regularFile(File file) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw const FormatException('Missing or unsafe pending file.');
    }
  }

  Future<Map<String, dynamic>> _readManifest(
    Directory directory,
    String firebaseUid,
    String apiBaseUrl,
  ) async {
    final file = _file(directory, _manifestName);
    await _regularFile(file);
    if (await file.length() > 1024 * 1024) {
      throw const FormatException('Oversized manifest.');
    }
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid manifest.');
    }
    final checksum = decoded.remove('manifestCrc32');
    if (checksum is! String ||
        checksum != _crc32(utf8.encode(jsonEncode(decoded))) ||
        decoded['schemaVersion'] != 1 ||
        decoded['firebaseUid'] is! String ||
        decoded['apiBaseUrl'] is! String ||
        decoded['completed'] is! bool ||
        decoded['evidences'] is! List) {
      throw const FormatException('Unsupported or damaged manifest.');
    }
    if (firebaseUid.isEmpty || decoded['firebaseUid'] != firebaseUid) {
      throw const DeliveryAttemptStoreException(
        'El intento pendiente pertenece a otro usuario. Inicia sesión con su cuenta; no se borró.',
      );
    }
    if (decoded['apiBaseUrl'] != _base(apiBaseUrl)) {
      throw const DeliveryAttemptStoreException(
        'El intento pendiente pertenece a otro backend. Restablece su configuración; no se borró.',
      );
    }
    final evidences = decoded['evidences'] as List;
    if (evidences.length < 2 || evidences.length > 16) {
      throw const FormatException('Invalid evidence count.');
    }
    for (var i = 0; i < evidences.length; i++) {
      final evidence = evidences[i];
      if (evidence is! Map<String, dynamic> ||
          evidence['storedFilename'] != 'evidence_$i.bin' ||
          evidence['byteLength'] is! int ||
          (evidence['byteLength'] as int) <= 0 ||
          (evidence['byteLength'] as int) >
              (i == evidences.length - 1
                  ? deliverySignatureMaxBytes
                  : deliveryPhotoMaxBytes) ||
          evidence['crc32'] is! String ||
          !RegExp(r'^[0-9a-f]{8}$').hasMatch(evidence['crc32'] as String)) {
        throw const FormatException(
            'Invalid internal evidence filename or integrity data.');
      }
    }
    // Validate metadata even during recovery from an interrupted terminal cleanup.
    DeliveryAttempt.validateMetadata(decoded);
    return decoded;
  }

  Future<DeliveryAttempt?> load({
    required String firebaseUid,
    required String apiBaseUrl,
    bool cleanupCompleted = false,
  }) async {
    try {
      final directory = await _directory();
      if (!await directory.exists()) return null;
      final manifest = await _readManifest(directory, firebaseUid, apiBaseUrl);
      if (cleanupCompleted && manifest['completed'] == true) {
        await _cleanup(directory, manifest);
        return null;
      }
      final bytes = <List<int>>[];
      for (final item in manifest['evidences'] as List) {
        final file = _file(directory, item['storedFilename'] as String);
        await _regularFile(file);
        if (await file.length() != item['byteLength']) {
          throw const FormatException('Evidence length changed.');
        }
        final data = await file.readAsBytes();
        if (_crc32(data) != item['crc32']) {
          throw const FormatException('Evidence checksum changed.');
        }
        bytes.add(data);
      }
      return DeliveryAttempt.restore(manifest, bytes);
    } on DeliveryAttemptStoreException {
      rethrow;
    } catch (_) {
      throw const DeliveryAttemptStoreException(
        'El pendiente local está incompleto o no se puede leer. Se bloqueó el envío; '
        'no se borraron datos ni se generó otro intento. Revisa el almacenamiento y vuelve a intentar.',
      );
    }
  }

  Future<void> save(
    DeliveryAttempt attempt, {
    required String firebaseUid,
    required String apiBaseUrl,
  }) async {
    try {
      if (firebaseUid.isEmpty) {
        throw const DeliveryAttemptStoreException(
          'Inicia sesión antes de guardar el intento de Entregas.',
        );
      }
      final directory = await _directory();
      final metadata = attempt.toMetadata();
      final key =
          jsonEncode([firebaseUid, _base(apiBaseUrl), attempt.clientRequestId]);
      final existed = await directory.exists();
      final manifestFile = _file(directory, _manifestName);
      Map<String, dynamic>? previous;
      if (existed) {
        final manifestType = await FileSystemEntity.type(
          manifestFile.path,
          followLinks: false,
        );
        if (manifestType != FileSystemEntityType.notFound ||
            _unpublishedKey != key) {
          previous = await _readManifest(directory, firebaseUid, apiBaseUrl);
        }
      } else {
        await directory.create(recursive: true);
        _unpublishedKey = key;
      }
      if (previous != null) {
        if (previous['clientRequestId'] != attempt.clientRequestId ||
            jsonEncode(previous['creationPayload']) !=
                jsonEncode(attempt.creationPayload) ||
            (previous['deliveryId'] != null &&
                previous['deliveryId'] != attempt.deliveryId) ||
            (previous['completed'] == true && !attempt.completed) ||
            !(previous['confirmedEvidenceIds'] as List).every(
              (id) => (metadata['confirmedEvidenceIds'] as List).contains(id),
            )) {
          throw const DeliveryAttemptStoreException(
            'Existe otro intento o un avance más reciente. Reabre Entregas para recuperarlo; no se reemplazó.',
          );
        }
      }
      final evidenceMetadata = metadata['evidences'] as List;
      for (var i = 0; i < attempt.evidences.length; i++) {
        final evidence = attempt.evidences[i];
        final item = evidenceMetadata[i] as Map<String, Object?>;
        item['storedFilename'] = 'evidence_$i.bin';
        item['byteLength'] = evidence.bytes.length;
        item['crc32'] = _crc32(evidence.bytes);
        if (previous == null) {
          final file = _file(directory, 'evidence_$i.bin');
          final type =
              await FileSystemEntity.type(file.path, followLinks: false);
          if (type != FileSystemEntityType.notFound &&
              type != FileSystemEntityType.file) {
            throw const FormatException('Unsafe evidence file.');
          }
          await file.writeAsBytes(evidence.bytes, flush: true);
        }
      }
      if (previous != null &&
          jsonEncode(previous['evidences']) != jsonEncode(evidenceMetadata)) {
        throw const FormatException('Pending evidence identity changed.');
      }
      if (previous != null && !attempt.completed) {
        // Before more HTTP, make sure recovery still has the exact evidence files.
        for (final item in evidenceMetadata) {
          final file = _file(directory, item['storedFilename'] as String);
          await _regularFile(file);
          if (await file.length() != item['byteLength'] ||
              _crc32(await file.readAsBytes()) != item['crc32']) {
            throw const FormatException(
                'Saved evidence is missing or damaged.');
          }
        }
      }
      final manifest = <String, Object?>{
        'schemaVersion': 1,
        'firebaseUid': firebaseUid,
        'apiBaseUrl': _base(apiBaseUrl),
        ...metadata,
      };
      manifest['manifestCrc32'] = _crc32(utf8.encode(jsonEncode(manifest)));
      final temporary = _file(directory, 'manifest.tmp');
      final type =
          await FileSystemEntity.type(temporary.path, followLinks: false);
      if (type != FileSystemEntityType.notFound &&
          type != FileSystemEntityType.file) {
        throw const FormatException('Unsafe temporary manifest.');
      }
      await temporary.writeAsString(jsonEncode(manifest), flush: true);
      // Same-directory replacement: never remove the previous manifest first.
      await temporary.rename(manifestFile.path);
      _unpublishedKey = null;
    } on DeliveryAttemptStoreException {
      rethrow;
    } catch (_) {
      throw const DeliveryAttemptStoreException(
        'No se pudo guardar el intento local. El envío se detuvo; conserva el '
        'formulario y reintenta con los mismos datos.',
      );
    }
  }

  Future<void> cleanup({
    required String firebaseUid,
    required String apiBaseUrl,
    required String clientRequestId,
  }) async {
    try {
      final directory = await _directory();
      if (!await directory.exists()) return;
      final manifest = await _readManifest(directory, firebaseUid, apiBaseUrl);
      if (manifest['clientRequestId'] != clientRequestId) {
        throw const FormatException('Different pending attempt.');
      }
      await _cleanup(directory, manifest);
    } on DeliveryAttemptStoreException {
      rethrow;
    } catch (_) {
      throw const DeliveryAttemptStoreException(
        'No se pudo limpiar el pendiente COMPLETED. Vuelve a revisar el pendiente; no se reenviará.',
      );
    }
  }

  Future<void> _cleanup(
      Directory directory, Map<String, dynamic> manifest) async {
    if (manifest['completed'] != true) {
      throw const DeliveryAttemptStoreException(
        'El intento sigue pendiente. Solo se permite limpiar después de COMPLETED.',
      );
    }
    // Preserve the existing checks before retiring the active directory.
    final allowed = <String>{
      _manifestName,
      'manifest.tmp',
      for (var i = 0; i < (manifest['evidences'] as List).length; i++)
        'evidence_$i.bin',
    };
    for (final entity in await directory.list(followLinks: false).toList()) {
      final name = entity.path.split(Platform.pathSeparator).last;
      if (!allowed.contains(name) ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.file) {
        throw const FormatException(
            'Unexpected entry in private pending directory.');
      }
    }
    // Retire the whole directory atomically before removing any of its files.
    // A crash before rename leaves the terminal manifest active and recoverable;
    // a crash afterwards leaves only an inert sibling tombstone.
    final parent = directory.parent;
    late String tombstonePath;
    do {
      final suffix = _cleanupSequence++;
      final timestamp = DateTime.now().microsecondsSinceEpoch;
      tombstonePath = '${parent.path}${Platform.pathSeparator}'
          '$_cleanupPrefix${manifest['clientRequestId']}-$timestamp-$suffix';
    } while (await FileSystemEntity.type(tombstonePath, followLinks: false) !=
        FileSystemEntityType.notFound);
    final retired = await directory.rename(tombstonePath);
    _unpublishedKey = null;
    await _tryDeleteCleanup(retired, parent);
  }

  // CRC32 detects accidental corruption without adding a hashing dependency.
  static final List<int> _crcTable = List.generate(256, (value) {
    var crc = value;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >>> 1) ^ 0xedb88320 : crc >>> 1;
    }
    return crc;
  });

  static String _crc32(List<int> bytes) {
    var crc = 0xffffffff;
    for (final byte in bytes) {
      crc = _crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
    }
    return ((crc ^ 0xffffffff) & 0xffffffff).toRadixString(16).padLeft(8, '0');
  }
}
