import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:uuid/uuid.dart';

// Solo LOCAL. En un dispositivo, sustituir localhost por el host local accesible:
// --dart-define=LOGISTICA_API10_BASE_URL=http://<HOST_LOCAL>:3010/api10
const logisticaApi10BaseUrl = String.fromEnvironment(
  'LOGISTICA_API10_BASE_URL',
  defaultValue: 'http://localhost:3010/api10',
);

const deliveryPhotoMaxBytes = 10 * 1024 * 1024;
const deliverySignatureMaxBytes = 2 * 1024 * 1024;

class DeliveryApiException implements Exception {
  const DeliveryApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class DeliveryEvidence {
  DeliveryEvidence._({
    required this.clientEvidenceId,
    required this.type,
    required this.filename,
    required this.mimeType,
    required List<int> bytes,
  }) : bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final String clientEvidenceId;
  final String type;
  final String filename;
  final String mimeType;
  final Uint8List bytes;
}

class DeliveryAttempt {
  DeliveryAttempt._(this.clientRequestId, this.creationPayload, this.evidences);

  factory DeliveryAttempt.freeze({
    required String pedido,
    required String equipos,
    required String chofer,
    required String observaciones,
    required String instalara,
    required double latitude,
    required double longitude,
    required String appVersion,
    required List<Uint8List> photos,
    required Uint8List signature,
  }) {
    if (pedido.trim().isEmpty ||
        equipos.trim().isEmpty ||
        chofer.trim().isEmpty) {
      throw const DeliveryApiException('Completa pedido, equipo y chofer.');
    }
    if (!latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const DeliveryApiException('No se obtuvo un GPS válido.');
    }
    if (photos.isEmpty || photos.length > 15) {
      throw const DeliveryApiException('Agrega entre 1 y 15 fotos.');
    }
    for (final photo in photos) {
      if (photo.isEmpty || photo.length > deliveryPhotoMaxBytes) {
        throw const DeliveryApiException('Cada foto debe pesar hasta 10 MiB.');
      }
      if (photo.length < 3 ||
          photo[0] != 0xff ||
          photo[1] != 0xd8 ||
          photo[2] != 0xff) {
        throw const DeliveryApiException(
          'Una foto no tiene formato JPEG. Vuelve a seleccionarla.',
        );
      }
    }
    const pngHeader = [137, 80, 78, 71, 13, 10, 26, 10];
    if (signature.isEmpty || signature.length > deliverySignatureMaxBytes) {
      throw const DeliveryApiException('La firma debe pesar hasta 2 MiB.');
    }
    if (signature.length < pngHeader.length ||
        pngHeader.asMap().entries.any(
              (entry) => signature[entry.key] != entry.value,
            )) {
      throw const DeliveryApiException(
        'No se pudo exportar la firma como PNG. Vuelve a firmar.',
      );
    }

    const uuid = Uuid();
    final requestId = uuid.v4();
    final evidence = <DeliveryEvidence>[
      for (var i = 0; i < photos.length; i++)
        DeliveryEvidence._(
          clientEvidenceId: uuid.v4(),
          type: 'PHOTO',
          filename: 'photo_${i + 1}.jpg',
          mimeType: 'image/jpeg',
          bytes: photos[i],
        ),
      DeliveryEvidence._(
        clientEvidenceId: uuid.v4(),
        type: 'SIGNATURE',
        filename: 'signature.png',
        mimeType: 'image/png',
        bytes: signature,
      ),
    ];
    return DeliveryAttempt._(
      requestId,
      Map<String, Object?>.unmodifiable({
        'client_request_id': requestId,
        'pedido': pedido.trim(),
        'equipos': equipos.trim(),
        'chofer': chofer.trim(),
        'observaciones': observaciones,
        'instalara': instalara,
        'latitude': latitude,
        'longitude': longitude,
        'app_version': appVersion,
      }),
      List<DeliveryEvidence>.unmodifiable(evidence),
    );
  }

  /// Rebuilds a saved attempt without generating UUIDs or transforming bytes.
  factory DeliveryAttempt.restore(
    Map<String, dynamic> metadata,
    List<List<int>> evidenceBytes,
  ) =>
      _restore(metadata, evidenceBytes);

  /// Checks terminal metadata without requiring files already removed by cleanup.
  static void validateMetadata(Map<String, dynamic> metadata) {
    _restore(metadata, null);
  }

  static DeliveryAttempt _restore(
    Map<String, dynamic> metadata,
    List<List<int>>? evidenceBytes,
  ) {
    final requestId = metadata['clientRequestId'];
    final payload = metadata['creationPayload'];
    final savedEvidence = metadata['evidences'];
    final deliveryId = metadata['deliveryId'];
    final confirmed = metadata['confirmedEvidenceIds'];
    final completed = metadata['completed'];
    final uuid = RegExp(
      r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
    );
    const payloadKeys = {
      'client_request_id',
      'pedido',
      'equipos',
      'chofer',
      'observaciones',
      'instalara',
      'latitude',
      'longitude',
      'app_version',
    };
    if (requestId is! String ||
        !uuid.hasMatch(requestId) ||
        payload is! Map<String, dynamic> ||
        payload.length != payloadKeys.length ||
        !payloadKeys.every(payload.containsKey) ||
        payload['client_request_id'] != requestId ||
        savedEvidence is! List ||
        savedEvidence.length < 2 ||
        savedEvidence.length > 16 ||
        (evidenceBytes != null &&
            evidenceBytes.length != savedEvidence.length) ||
        confirmed is! List ||
        completed is! bool) {
      throw const FormatException('Invalid saved delivery metadata.');
    }
    for (final key in [
      'pedido',
      'equipos',
      'chofer',
      'observaciones',
      'instalara',
      'app_version'
    ]) {
      if (payload[key] is! String ||
          (['pedido', 'equipos', 'chofer'].contains(key) &&
              (payload[key] as String).trim().isEmpty)) {
        throw const FormatException('Invalid saved delivery payload.');
      }
    }
    for (final entry in {'latitude': 90, 'longitude': 180}.entries) {
      final value = payload[entry.key];
      if (value is! num || !value.isFinite || value.abs() > entry.value) {
        throw const FormatException('Invalid saved coordinates.');
      }
    }
    if (deliveryId != null &&
        (deliveryId is! String ||
            !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(deliveryId) ||
            BigInt.parse(deliveryId) > BigInt.parse('9223372036854775807'))) {
      throw const FormatException('Invalid saved delivery ID.');
    }
    final evidences = <DeliveryEvidence>[];
    final ids = <String>{requestId};
    for (var i = 0; i < savedEvidence.length; i++) {
      final item = savedEvidence[i];
      final photo = i < savedEvidence.length - 1;
      final bytes = evidenceBytes?[i];
      final filename = photo ? 'photo_${i + 1}.jpg' : 'signature.png';
      if (item is! Map<String, dynamic> ||
          item['clientEvidenceId'] is! String ||
          !uuid.hasMatch(item['clientEvidenceId'] as String) ||
          !ids.add(item['clientEvidenceId'] as String) ||
          item['type'] != (photo ? 'PHOTO' : 'SIGNATURE') ||
          item['mimeType'] != (photo ? 'image/jpeg' : 'image/png') ||
          item['filename'] != filename ||
          (bytes != null &&
              (bytes.isEmpty ||
                  bytes.length >
                      (photo
                          ? deliveryPhotoMaxBytes
                          : deliverySignatureMaxBytes)))) {
        throw const FormatException('Invalid saved evidence.');
      }
      const png = [137, 80, 78, 71, 13, 10, 26, 10];
      final header = photo ? const [255, 216, 255] : png;
      if (bytes != null &&
          (bytes.length < header.length ||
              header.asMap().entries.any((e) => bytes[e.key] != e.value))) {
        throw const FormatException('Invalid saved evidence format.');
      }
      evidences.add(DeliveryEvidence._(
        clientEvidenceId: item['clientEvidenceId'] as String,
        type: item['type'] as String,
        filename: item['filename'] as String,
        mimeType: item['mimeType'] as String,
        bytes: bytes ?? const [],
      ));
    }
    final confirmedIds = <String>{};
    for (final id in confirmed) {
      if (id is! String ||
          !confirmedIds.add(id) ||
          !evidences.any((e) => e.clientEvidenceId == id)) {
        throw const FormatException('Invalid confirmed evidence IDs.');
      }
    }
    if ((deliveryId == null && confirmedIds.isNotEmpty) ||
        (completed &&
            (deliveryId == null || confirmedIds.length != evidences.length))) {
      throw const FormatException('Invalid saved progress.');
    }
    return DeliveryAttempt._(
      requestId,
      Map<String, Object?>.unmodifiable(payload),
      List<DeliveryEvidence>.unmodifiable(evidences),
    )
      .._deliveryId = deliveryId as String?
      .._confirmedEvidenceIds.addAll(confirmedIds)
      .._completed = completed;
  }

  Map<String, Object?> toMetadata() => {
        'clientRequestId': clientRequestId,
        'creationPayload': creationPayload,
        'deliveryId': _deliveryId,
        'completed': _completed,
        'confirmedEvidenceIds': _confirmedEvidenceIds.toList(),
        'evidences': [
          for (final evidence in evidences)
            <String, Object?>{
              'clientEvidenceId': evidence.clientEvidenceId,
              'type': evidence.type,
              'filename': evidence.filename,
              'mimeType': evidence.mimeType,
            },
        ],
      };

  final String clientRequestId;
  final Map<String, Object?> creationPayload;
  final List<DeliveryEvidence> evidences;
  String? _deliveryId;
  final Set<String> _confirmedEvidenceIds = {};
  bool _completed = false;

  String? get deliveryId => _deliveryId;
  bool get completed => _completed;
  bool isConfirmed(DeliveryEvidence evidence) =>
      _confirmedEvidenceIds.contains(evidence.clientEvidenceId);
}

class LogisticaDeliveryService {
  LogisticaDeliveryService({
    required Future<String?> Function() tokenProvider,
    String baseUrl = logisticaApi10BaseUrl,
    http.Client Function()? clientFactory,
    this.requestTimeout = const Duration(seconds: 30),
    this.uploadTimeout = const Duration(minutes: 3),
  })  : _tokenProvider = tokenProvider,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _clientFactory = clientFactory ?? http.Client.new;

  final Future<String?> Function() _tokenProvider;
  final String _baseUrl;
  final http.Client Function() _clientFactory;
  final Duration requestTimeout;
  final Duration uploadTimeout;

  Future<void> send(
    DeliveryAttempt attempt, {
    void Function(String)? onProgress,
    Future<void> Function(DeliveryAttempt)? persist,
  }) async {
    // Persist before HTTP, and retry a failed terminal checkpoint without HTTP.
    await persist?.call(attempt);
    if (attempt.completed) return;
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        base.scheme != 'http' ||
        base.host.isEmpty ||
        base.port != 3010 ||
        base.path != '/api10' ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      throw const DeliveryApiException(
        'Configura LOGISTICA_API10_BASE_URL con el host LOCAL y puerto 3010.',
      );
    }

    if (attempt.deliveryId == null) {
      onProgress?.call('Preparando entrega...');
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/logistica/entregas'),
      )
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(attempt.creationPayload);
      final response = await _send(request, requestTimeout);
      final body = _decode(response);
      _requireStatus(response, body, const {200, 201});
      final delivery = _object(body?['delivery']);
      final id = _id(delivery?['id']);
      if (body?['ok'] != true ||
          body?['idempotent_replay'] != (response.statusCode == 200) ||
          delivery?['client_request_id'] != attempt.clientRequestId ||
          id == null) {
        throw const DeliveryApiException(
          'Respuesta de creación no válida. Reintenta el mismo envío.',
        );
      }
      attempt._deliveryId = id;
      await persist?.call(attempt);
    }

    final photos = attempt.evidences.where((e) => e.type == 'PHOTO').toList();
    for (final evidence in attempt.evidences) {
      if (attempt.isConfirmed(evidence)) continue;
      onProgress?.call(evidence.type == 'PHOTO'
          ? 'Subiendo foto ${photos.indexOf(evidence) + 1}/${photos.length}...'
          : 'Subiendo firma...');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(
            '$_baseUrl/logistica/entregas/${attempt.deliveryId}/evidencias'),
      )
        ..fields['client_evidence_id'] = evidence.clientEvidenceId
        ..fields['evidence_type'] = evidence.type
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          evidence.bytes,
          filename: evidence.filename,
          contentType: MediaType.parse(evidence.mimeType),
        ));
      final response = await _send(request, uploadTimeout);
      final body = _decode(response);
      if (response.statusCode == 202) {
        throw const DeliveryApiException(
          'La evidencia sigue procesándose. Pulsa Reintentar envío para '
          'continuar con el mismo intento.',
          statusCode: 202,
        );
      }
      _requireStatus(response, body, const {200, 201});
      final uploaded = _object(body?['evidence']);
      if (body?['ok'] != true ||
          body?['idempotent_replay'] != (response.statusCode == 200) ||
          uploaded?['client_evidence_id'] != evidence.clientEvidenceId ||
          uploaded?['evidence_type'] != evidence.type ||
          uploaded?['status'] != 'UPLOADED' ||
          _id(uploaded?['id']) == null) {
        throw const DeliveryApiException(
          'La evidencia no quedó confirmada. Reintenta el mismo envío.',
        );
      }
      attempt._confirmedEvidenceIds.add(evidence.clientEvidenceId);
      await persist?.call(attempt);
    }

    onProgress?.call('Finalizando...');
    final response = await _send(
      http.Request(
        'POST',
        Uri.parse(
            '$_baseUrl/logistica/entregas/${attempt.deliveryId}/finalizar'),
      ),
      requestTimeout,
    );
    final body = _decode(response);
    _requireStatus(response, body, const {200});
    final delivery = _object(body?['delivery']);
    final completedAt = delivery?['completed_at'];
    if (body?['ok'] != true ||
        body?['idempotent_replay'] is! bool ||
        _id(delivery?['id']) != attempt.deliveryId ||
        delivery?['status'] != 'COMPLETED' ||
        completedAt is! String ||
        DateTime.tryParse(completedAt) == null) {
      throw const DeliveryApiException(
        'La entrega no quedó finalizada. Reintenta el mismo envío.',
      );
    }
    attempt._completed = true;
    await persist?.call(attempt);
  }

  Future<http.Response> _send(
    http.BaseRequest request,
    Duration timeout,
  ) async {
    try {
      // Se consulta la sesión justo antes de CADA operación, también en retries.
      final token = await _tokenProvider().timeout(requestTimeout);
      if (token == null || token.trim().isEmpty) {
        throw const DeliveryApiException(
          'La sesión no es válida. Inicia sesión y reintenta el envío.',
          statusCode: 401,
        );
      }
      request.headers['Authorization'] = 'Bearer $token';
      final client = _clientFactory();
      try {
        return await (() async {
          final streamed = await client.send(request);
          return http.Response.fromStream(streamed);
        })()
            .timeout(timeout);
      } finally {
        client.close();
      }
    } on TimeoutException {
      throw const DeliveryApiException(
        'Se agotó el tiempo de espera. Reintenta el mismo envío; '
        'se conservaron sus datos.',
      );
    } on http.ClientException {
      throw const DeliveryApiException(
        'No se pudo conectar con API10 LOCAL. Revisa la conexión y '
        'reintenta el mismo envío.',
      );
    }
  }

  Map<String, dynamic>? _object(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  Map<String, dynamic>? _decode(http.Response response) {
    try {
      return _object(jsonDecode(response.body));
    } on FormatException {
      return null;
    }
  }

  String? _id(Object? value) {
    if (value is! String && value is! int) return null;
    final text = value.toString();
    if (!RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(text) ||
        BigInt.parse(text) > BigInt.parse('9223372036854775807')) {
      return null;
    }
    return text;
  }

  void _requireStatus(
    http.Response response,
    Map<String, dynamic>? body,
    Set<int> accepted,
  ) {
    if (accepted.contains(response.statusCode)) return;
    final message = switch (response.statusCode) {
      400 => 'Datos inválidos. Revisa los datos del envío.',
      401 => 'Sesión no válida. Inicia sesión y reintenta.',
      403 => 'Usuario no autorizado para registrar esta entrega.',
      409 => 'Conflicto o estado no válido. No se modificó el intento local.',
      >= 500 => 'Error del servidor. Reintenta el mismo envío.',
      _ => 'Respuesta HTTP no esperada. Reintenta el mismo envío.',
    };
    // Nunca mostrar HTML, objetos arbitrarios ni el body completo.
    final detail = body?['error'];
    final safeDetail = detail is String &&
            detail.length <= 180 &&
            !detail.contains(RegExp(r'[\r\n<>]'))
        ? detail
        : null;
    throw DeliveryApiException(
      safeDetail == null ? message : '$message $safeDetail',
      statusCode: response.statusCode,
    );
  }
}
