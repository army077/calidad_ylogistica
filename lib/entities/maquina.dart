class Maquina {
  final int? id;
  final String maquina;

  Maquina({
    this.id,
    required this.maquina,
  });

  factory Maquina.fromJson(Map<String, dynamic> json) {
    return Maquina(
      id: json['id'] as int?,
      maquina: (json['maquina'] as String).trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maquina': maquina,
    };
  }
}
