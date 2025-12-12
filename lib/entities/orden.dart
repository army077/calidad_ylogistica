import 'dart:convert';
import 'dart:convert'; import 'package:http/http.dart' as http;

Future<OrdenInspeccion> fetchInspectionOrder(int id) async {
  final url = Uri.parse(
    'https://desarrollotecnologicoar.com/api10/quality/inspection/orders/$id',
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final jsonData = jsonDecode(response.body);
    return OrdenInspeccion.fromJson(jsonData);
  } else {
    throw Exception('Error al cargar la inspección $id');
  }
}

class OrdenInspeccion {
  final int id;
  final int inspectionTemplateId;
  final int modelId;
  final String? assignedTechEmail;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int workOrderId;
  final int estacion;

  final int templateId;
  final int templateVersion;

  final String machineSerial;
  final String? customerName;
  final String? siteAddress;
  final DateTime? scheduledAt;

  final String? diagnosticResult;
  final String? techSupport;
  final String? folioSai;
  final String? initialStatus;
  final String? comments;
  final int? extraPoints;
  final int? idReserva;
  final String? operadorProduccion;

  final String modelName;

  OrdenInspeccion({
    required this.id,
    required this.inspectionTemplateId,
    required this.modelId,
    required this.assignedTechEmail,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    required this.workOrderId,
    required this.estacion,
    required this.templateId,
    required this.templateVersion,
    required this.machineSerial,
    this.customerName,
    this.siteAddress,
    this.scheduledAt,
    this.diagnosticResult,
    this.techSupport,
    this.folioSai,
    this.initialStatus,
    this.comments,
    this.extraPoints,
    this.idReserva,
    required this.modelName,
    required this.operadorProduccion,
  });

  factory OrdenInspeccion.fromJson(Map<String, dynamic> json) {
    return OrdenInspeccion(
      id: json['id'],
      inspectionTemplateId: json['inspection_template_id'],
      modelId: json['model_id'],
      assignedTechEmail: json['assigned_tech_email'],
      status: json['status'] ?? 'UNKNOWN',
      createdAt: DateTime.parse(json['created_at']),
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'])
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.tryParse(json['finished_at'])
          : null,
      workOrderId: json['work_order_id'],
      estacion: json['estacion'] ?? 0,
      templateId: json['template_id'],
      templateVersion: json['template_version'],
      machineSerial: json['machine_serial'] ?? 'N/A',
      customerName: json['customer_name'],
      siteAddress: json['site_address'],
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.tryParse(json['scheduled_at'])
          : null,
      diagnosticResult: json['diagnostic_result'],
      techSupport: json['tech_support'],
      folioSai: json['folio_sai'],
      initialStatus: json['initial_status'],
      comments: json['comments'],
      extraPoints: json['extra_points'],
      idReserva: json['id_reserva'],
      modelName: json['model_name'] ?? 'Sin modelo',
      operadorProduccion: json['operador_produccion'],
    );
  }
}
