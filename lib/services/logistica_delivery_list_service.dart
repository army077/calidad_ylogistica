import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import 'logistica_delivery_service.dart' show logisticaApi10BaseUrl;

enum LogisticaDeliveryListFailure {
  authentication,
  authorization,
  configuration,
  invalidResponse,
  http,
  timeout,
  network,
}

class LogisticaDeliveryListException implements Exception {
  const LogisticaDeliveryListException(
    this.failure,
    this.message, {
    this.statusCode,
  });

  final LogisticaDeliveryListFailure failure;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

const _invalidResponse = LogisticaDeliveryListException(
  LogisticaDeliveryListFailure.invalidResponse,
  'La respuesta de API10 no es válida. Reintenta la consulta.',
);

enum LogisticaDeliverySource { current, legacy }

class LogisticaDeliveryListItem {
  const LogisticaDeliveryListItem._({
    required this.source,
    required this.id,
    required this.pedido,
    required this.displayName,
    required this.email,
    required this.status,
    required this.legacyRecordState,
    required this.createdAt,
    required this.recordedLocalAt,
    required this.timeZone,
    required this.photoCount,
    required this.legacyImageCount,
  });

  factory LogisticaDeliveryListItem.fromJson(Object? value) {
    const fields = {
      'source',
      'id',
      'pedido',
      'display_name',
      'email',
      'status',
      'legacy_record_state',
      'created_at',
      'recorded_local_at',
      'time_zone',
      'photo_count',
      'legacy_image_count',
    };
    if (value is! Map<String, dynamic> || !fields.every(value.containsKey)) {
      throw _invalidResponse;
    }
    final source = switch (value['source']) {
      'CURRENT' => LogisticaDeliverySource.current,
      'LEGACY' => LogisticaDeliverySource.legacy,
      _ => throw _invalidResponse,
    };
    final id = value['id'];
    final pedido = value['pedido'];
    final name = value['display_name'];
    final email = value['email'];
    if (id is! String ||
        id.trim().isEmpty ||
        pedido is! String ||
        (name != null && name is! String) ||
        (email != null && email is! String)) {
      throw _invalidResponse;
    }
    DateTime? createdAt;
    String? recordedLocalAt;
    final photoCount = value['photo_count'];
    final legacyImageCount = value['legacy_image_count'];
    if (source == LogisticaDeliverySource.current) {
      final timestamp = value['created_at'];
      if (timestamp is! String ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$')
              .hasMatch(timestamp) ||
          value['status'] != 'COMPLETED' ||
          value['legacy_record_state'] != null ||
          value['recorded_local_at'] != null ||
          value['time_zone'] != 'UTC' ||
          photoCount is! int ||
          photoCount < 0 ||
          legacyImageCount != null) {
        throw _invalidResponse;
      }
      createdAt = DateTime.tryParse(timestamp);
      if (createdAt == null ||
          !createdAt.isUtc ||
          !createdAt.toIso8601String().startsWith(timestamp.substring(0, 19))) {
        throw _invalidResponse;
      }
    } else {
      final timestamp = value['recorded_local_at'];
      if (value['status'] != null ||
          value['legacy_record_state'] != 'RECORDED' ||
          value['created_at'] != null ||
          value['time_zone'] != null ||
          photoCount != null ||
          legacyImageCount is! int ||
          timestamp is! String ||
          !_validHistoricalClock(timestamp)) {
        throw _invalidResponse;
      }
      recordedLocalAt = timestamp;
    }
    return LogisticaDeliveryListItem._(
      source: source,
      id: id,
      pedido: pedido,
      displayName: name as String?,
      email: email as String?,
      status: value['status'] as String?,
      legacyRecordState: value['legacy_record_state'] as String?,
      createdAt: createdAt,
      recordedLocalAt: recordedLocalAt,
      timeZone: value['time_zone'] as String?,
      photoCount: photoCount as int?,
      legacyImageCount: legacyImageCount as int?,
    );
  }

  // Validate a wall clock without DateTime, timezone conversion or DST rules.
  static bool _validHistoricalClock(String value) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?$',
    ).firstMatch(value);
    if (match == null) return false;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    final leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    final days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return year > 0 &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= days[month - 1] &&
        int.parse(match[4]!) <= 23 &&
        int.parse(match[5]!) <= 59 &&
        int.parse(match[6]!) <= 59;
  }

  final LogisticaDeliverySource source;
  final String id;
  final String pedido;
  final String? displayName;
  final String? email;
  final String? status;
  final String? legacyRecordState;
  final DateTime? createdAt;
  // Literal backend text: never parsed into a timezone-bearing DateTime.
  final String? recordedLocalAt;
  final String? timeZone;
  final int? photoCount;
  final int? legacyImageCount;

  String get uiKey => '${source.name}:$id';
}

class LogisticaDeliveryListSection {
  LogisticaDeliveryListSection._(
    List<LogisticaDeliveryListItem> items,
    this.nextCursor,
  ) : items = List.unmodifiable(items);

  factory LogisticaDeliveryListSection.fromJson(
    Object? value,
    LogisticaDeliverySource source,
  ) {
    if (value is! Map<String, dynamic> ||
        value['items'] is! List ||
        !value.containsKey('next_cursor')) {
      throw _invalidResponse;
    }
    final cursor = value['next_cursor'];
    if (cursor != null && (cursor is! String || cursor.isEmpty)) {
      throw _invalidResponse;
    }
    final items = (value['items'] as List)
        .map(LogisticaDeliveryListItem.fromJson)
        .toList();
    if (items.any((item) => item.source != source) ||
        (items.isEmpty && cursor != null)) {
      throw _invalidResponse;
    }
    return LogisticaDeliveryListSection._(items, cursor as String?);
  }

  final List<LogisticaDeliveryListItem> items;
  final String? nextCursor;
}

class LogisticaDeliveryListPage {
  const LogisticaDeliveryListPage._(this.current, this.legacy);

  factory LogisticaDeliveryListPage.fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['ok'] != true) {
      throw _invalidResponse;
    }
    return LogisticaDeliveryListPage._(
      LogisticaDeliveryListSection.fromJson(
          value['current'], LogisticaDeliverySource.current),
      LogisticaDeliveryListSection.fromJson(
          value['legacy'], LogisticaDeliverySource.legacy),
    );
  }

  final LogisticaDeliveryListSection current;
  final LogisticaDeliveryListSection legacy;
}

class LogisticaDeliveryListService {
  LogisticaDeliveryListService({
    FirebaseAuth? auth,
    String baseUrl = logisticaApi10BaseUrl,
    http.Client Function()? clientFactory,
    this.requestTimeout = const Duration(seconds: 30),
  })  : _auth = auth,
        _baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _clientFactory = clientFactory ?? http.Client.new;

  final FirebaseAuth? _auth;
  final String _baseUrl;
  final http.Client Function() _clientFactory;
  final Duration requestTimeout;

  Future<LogisticaDeliveryListPage> fetchPage({
    String? pedido,
    String? currentCursor,
    String? legacyCursor,
    int limit = 25,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'Debe estar entre 1 y 100.');
    }
    final base = Uri.tryParse(_baseUrl);
    if (base == null ||
        base.scheme != 'http' ||
        base.host.isEmpty ||
        base.port != 3010 ||
        base.path != '/api10' ||
        base.hasQuery ||
        base.hasFragment ||
        base.userInfo.isNotEmpty) {
      throw const LogisticaDeliveryListException(
        LogisticaDeliveryListFailure.configuration,
        'Configura LOGISTICA_API10_BASE_URL con el host LOCAL y puerto 3010.',
      );
    }
    final token = await _idToken();
    final uri = base.replace(
      path: '${base.path}/logistica/entregas/historial',
      queryParameters: {
        'limit': '$limit',
        if (pedido != null && pedido.isNotEmpty) 'pedido': pedido,
        if (currentCursor != null) 'current_cursor': currentCursor,
        if (legacyCursor != null) 'legacy_cursor': legacyCursor,
      },
    );
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    final client = _clientFactory();
    final http.Response response;
    try {
      response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })()
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const LogisticaDeliveryListException(
        LogisticaDeliveryListFailure.timeout,
        'Se agotó el tiempo de espera. Reintenta la consulta.',
      );
    } on http.ClientException {
      throw const LogisticaDeliveryListException(
        LogisticaDeliveryListFailure.network,
        'No se pudo conectar con API10 LOCAL. Revisa la conexión y reintenta.',
      );
    } finally {
      client.close();
    }
    if (response.statusCode != 200) {
      final failure = switch (response.statusCode) {
        401 => LogisticaDeliveryListFailure.authentication,
        403 => LogisticaDeliveryListFailure.authorization,
        _ => LogisticaDeliveryListFailure.http,
      };
      final message = switch (response.statusCode) {
        401 => 'La sesión no es válida. Inicia sesión y reintenta.',
        403 => 'No tienes autorización para consultar las entregas.',
        400 => 'La consulta no es válida. Revisa la búsqueda y reintenta.',
        >= 500 => 'Error del servidor. Reintenta la consulta.',
        _ => 'Respuesta HTTP no esperada. Reintenta la consulta.',
      };
      throw LogisticaDeliveryListException(failure, message,
          statusCode: response.statusCode);
    }
    try {
      return LogisticaDeliveryListPage.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw _invalidResponse;
    }
  }

  Future<String> _idToken() async {
    try {
      final user = (_auth ?? FirebaseAuth.instance).currentUser;
      if (user != null) {
        // Firebase renews expired tokens; obtain one before every GET.
        final token = await user.getIdToken().timeout(requestTimeout);
        if (token != null && token.trim().isNotEmpty) return token;
      }
    } on TimeoutException {
      throw const LogisticaDeliveryListException(
        LogisticaDeliveryListFailure.timeout,
        'Se agotó el tiempo de espera de la sesión. Reintenta la consulta.',
      );
    } on Exception {
      throw const LogisticaDeliveryListException(
        LogisticaDeliveryListFailure.authentication,
        'No se pudo validar la sesión. Inicia sesión y reintenta.',
      );
    }
    throw const LogisticaDeliveryListException(
      LogisticaDeliveryListFailure.authentication,
      'Inicia sesión para consultar tus entregas.',
    );
  }
}
