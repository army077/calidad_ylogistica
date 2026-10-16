import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const _api = 'https://desarrollotecnologicoar.com';

/// Máquinas actualmente en ensamble (plantel de producción).
class ProduccionEnsamble extends StatefulWidget {
  const ProduccionEnsamble({super.key});

  @override
  State<ProduccionEnsamble> createState() => _ProduccionEnsambleState();
}

class _Maquina {
  final int id;
  final String plantilla;
  final String modelo;
  final String tecnico;
  final String estado;
  final DateTime? programada;
  final int avance;

  _Maquina({
    required this.id,
    required this.plantilla,
    required this.modelo,
    required this.tecnico,
    required this.estado,
    required this.programada,
    required this.avance,
  });
}

class _ProduccionEnsambleState extends State<ProduccionEnsamble> {
  late Future<List<_Maquina>> _future;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _getList(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final json = jsonDecode(res.body);
    return json is List ? json : (json['data'] as List? ?? []);
  }

  Future<List<_Maquina>> _load() async {
    final results = await Future.wait([
      _getList('$_api/api10/work-orders?include=tasks'),
      _getList('$_api/api10/templates'),
      _getList('$_api/api10/machine-models'),
      _getList('$_api/api5/tecnicos'),
    ]);
    final orders = results[0];
    final templates = {for (final t in results[1]) t['id']: t};
    final models = {for (final m in results[2]) m['id']: m};
    final techs = {
      for (final t in results[3])
        if ((t['estatus'] ?? '').toString().toLowerCase() == 'activo')
          t['correo_tecnico']: t
    };

    final out = <_Maquina>[];
    for (final w in orders) {
      final tpl = templates[w['template_id']];
      final tech = techs[w['assigned_tech_email']];
      if (tpl == null || tpl['template_type'] != 'ENSAMBLE') continue;
      if (tech == null || tech['puesto'] != 'Operador de producción') continue;
      final status = (w['status'] ?? '').toString();
      if (status != 'OPEN' && status != 'IN_PROGRESS') continue;

      final tasks = (w['tasks'] as List?) ?? [];
      final done = tasks.where((t) => t['status'] == 'DONE').length;
      out.add(_Maquina(
        id: w['id'],
        plantilla: (tpl['name'] ?? '').toString(),
        modelo: (models[w['model_id']]?['name'] ?? '—').toString(),
        tecnico: (tech['nombre_tecnico'] ?? '—').toString(),
        estado: status,
        programada: w['scheduled_at'] == null
            ? null
            : DateTime.tryParse(w['scheduled_at'].toString())?.toLocal(),
        avance: tasks.isEmpty ? 0 : ((done / tasks.length) * 100).round(),
      ));
    }
    out.sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future.catchError((_) => <_Maquina>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_Maquina>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('No se pudo cargar la producción'),
                const SizedBox(height: 8),
                FilledButton(onPressed: _refresh, child: const Text('Reintentar')),
              ],
            ),
          );
        }
        final needle = _search.text.trim().toLowerCase();
        final items = (snap.data ?? [])
            .where((m) =>
                needle.isEmpty ||
                '${m.id} ${m.plantilla} ${m.modelo} ${m.tecnico}'
                    .toLowerCase()
                    .contains(needle))
            .toList();

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i == 0) {
                return TextField(
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar máquina, modelo o técnico',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: Text('No hay máquinas en ensamble')),
                );
              }
              return _MaquinaCard(m: items[i - 1]);
            },
          ),
        );
      },
    );
  }
}

class _MaquinaCard extends StatelessWidget {
  final _Maquina m;
  const _MaquinaCard({required this.m});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fecha = m.programada == null
        ? '—'
        : '${m.programada!.day.toString().padLeft(2, '0')}/'
            '${m.programada!.month.toString().padLeft(2, '0')}/'
            '${m.programada!.year}';

    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(m.plantilla,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                Chip(
                  label: Text(
                      m.estado == 'IN_PROGRESS' ? 'En proceso' : 'Abierta'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Modelo: ${m.modelo}', style: tt.bodySmall),
            Text('Técnico: ${m.tecnico}', style: tt.bodySmall),
            Text('Programada: $fecha', style: tt.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: m.avance / 100, minHeight: 10),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${m.avance}%',
                    style: tt.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
