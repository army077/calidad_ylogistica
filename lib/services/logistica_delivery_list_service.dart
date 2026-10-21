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

class LogisticaDeliveryListItem {
  const LogisticaDeliveryListItem._({
    required this.id,
    required this.pedido,
    required this.authDisplayName,
    required this.authEmail,
    required this.createdAt,
    required this.status,
    required this.photoCount,
  });

  factory LogisticaDeliveryListItem.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) throw _invalidResponse;
    final id = value['id'];
    final pedido = value['pedido'];
    final name = value['auth_display_name'];
    final email = value['auth_email'];
    final timestamp = value['created_at'];
    final photoCount = value['photo_count'];
    if (id is! String ||
        !RegExp(r'^[1-9][0-9]{0,18}$').hasMatch(id) ||
        BigInt.parse(id) > BigInt.parse('9223372036854775807') ||
        pedido is! String ||
        !value.containsKey('auth_display_name') ||
        !value.containsKey('auth_email') ||
        (name != null && name is! String) ||
        (email != null && email is! String) ||
        timestamp is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z$')
            .hasMatch(timestamp) ||
        value['status'] != 'COMPLETED' ||
        photoCount is! int ||
        photoCount < 0) {
      throw _invalidResponse;
    }
    final createdAt = DateTime.tryParse(timestamp);
    if (createdAt == null ||
        !createdAt.isUtc ||
        !createdAt.toIso8601String().startsWith(timestamp.substring(0, 19))) {
      throw _invalidResponse;
    }
    return LogisticaDeliveryListItem._(
      id: id,
      pedido: pedido,
      authDisplayName: name as String?,
      authEmail: email as String?,
      createdAt: createdAt,
      status: 'COMPLETED',
      photoCount: photoCount,
    );
  }

  final String id;
  final String pedido;
  final String? authDisplayName;
  final String? authEmail;
  final DateTime createdAt;
  final String status;
  final int photoCount;
}

class LogisticaDeliveryListPage {
  LogisticaDeliveryListPage._(
    List<LogisticaDeliveryListItem> items,
    this.nextCursor,
  ) : items = List.unmodifiable(items);

  factory LogisticaDeliveryListPage.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['ok'] != true ||
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
    if (items.isEmpty && cursor != null) throw _invalidResponse;
    return LogisticaDeliveryListPage._(items, cursor as String?);
  }

  final List<LogisticaDeliveryListItem> items;
  final String? nextCursor;
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
    String? cursor,
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
      path: '${base.path}/logistica/entregas',
      queryParameters: {
        'limit': '$limit',
        if (pedido != null && pedido.isNotEmpty) 'pedido': pedido,
        if (cursor != null) 'cursor': cursor,
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
      throw LogisticaDeliveryListException(
        failure,
        message,
        statusCode: response.statusCode,
      );
    }
    try {
      return LogisticaDeliveryListPage.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    } on FormatException {
      throw _invalidResponse;
    }
  }

  Future<String> _idToken() async {
    try {
      final user = (_auth ?? FirebaseAuth.instance).currentUser;
      if (user != null) {
        // Firebase renueva el ID token si caducó; consultar antes de cada GET.
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
