class Tarea {
  final int id;
  final int inspectionOrderId;
  final int templateTaskInspectionId;
  final String revisionPoint;
  final String specs;
  final String suggestions;
  final String status;
  DateTime? startedAt;
  DateTime? finishedAt;
  int? actualMinutes;
  final String? comments;
  final String sectionTitle;
  final int position;
  final String category;

  bool completada; // útil para UI

  Tarea({
    required this.id,
    required this.inspectionOrderId,
    required this.templateTaskInspectionId,
    required this.revisionPoint,
    required this.specs,
    required this.suggestions,
    required this.status,
    required this.sectionTitle,
    required this.position,
    required this.category,
    this.startedAt,
    this.finishedAt,
    this.actualMinutes,
    this.comments,
    this.completada = false,
  });

  factory Tarea.fromJson(Map<String, dynamic> json) {
    return Tarea(
      id: json['id'],
      inspectionOrderId: json['inspection_order_id'],
      templateTaskInspectionId: json['template_task_inspection_id'],
      revisionPoint: json['revision_point'] ?? '',
      specs: json['specs'] ?? '',
      suggestions: json['suggestions'] ?? '',
      status: json['status'] ?? 'PENDING',
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at']).toUtc()
          : null,
      finishedAt: json['finished_at'] != null
          ? DateTime.parse(json['finished_at']).toUtc()
          : null,
      actualMinutes: json['actual_minutes'],
      comments: json['comments'],
      sectionTitle: json['section_title'] ?? '',
      position: json['position'] ?? 0,
      category: json['category'] ?? '',

      // si viene DONE lo marcamos como completada
      completada: json['status'] == 'DONE',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "inspection_order_id": inspectionOrderId,
      "template_task_inspection_id": templateTaskInspectionId,
      "revision_point": revisionPoint,
      "specs": specs,
      "suggestions": suggestions,
      "status": status,
      "started_at": startedAt?.toIso8601String(),
      "finished_at": finishedAt?.toIso8601String(),
      "actual_minutes": actualMinutes,
      "comments": comments,
      "section_title": sectionTitle,
      "position": position,
      "category": category,
    };
  }
}
