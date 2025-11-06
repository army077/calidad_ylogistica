import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Maquina {
  final int id;
  final String maquina;

  Maquina({required this.id, required this.maquina});

  factory Maquina.fromJson(Map<String, dynamic> json) {
    return Maquina(
      id: json['id'] as int,
      maquina: json['maquina'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'maquina': maquina};
}

class MaquinasScreen extends StatefulWidget {
  const MaquinasScreen({Key? key}) : super(key: key);

  @override
  State<MaquinasScreen> createState() => _MaquinasScreenState();
}

class _MaquinasScreenState extends State<MaquinasScreen> {
  List<Maquina> _maquinas = [];
  bool _isLoading = true;

  // Endpoints
  final String _baseUrl   = 'https://desarrollotecnologicoar.com/api2/maquinas';
  final String _createUrl = 'https://desarrollotecnologicoar.com/api2/agregar_maquina/';

  @override
  void initState() {
    super.initState();
    _fetchMaquinas();
  }

  Future<void> _fetchMaquinas() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _maquinas = data.map((e) => Maquina.fromJson(e)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        debugPrint('Error al listar máquinas: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error de conexión al listar: $e');
    }
  }

  Future<void> _crearMaquina(String nombreMaquina) async {
    try {
      final resp = await http.post(
        Uri.parse(_createUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'maquina': nombreMaquina}),
      );
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _maquinas.add(
            Maquina(id: data['id'] as int, maquina: nombreMaquina),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máquina creada exitosamente')),
        );
      } else {
        debugPrint('Error al crear máquina: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error de conexión al crear: $e');
    }
  }

  Future<void> _editarMaquina(int id, String nuevoNombre) async {
    try {
      final resp = await http.put(
        Uri.parse('$_baseUrl/$id/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'maquina': nuevoNombre}),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          final index = _maquinas.indexWhere((m) => m.id == id);
          if (index != -1) {
            _maquinas[index] = Maquina(
              id: data['id'] as int,
              maquina: data['maquina'] as String,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máquina editada exitosamente')),
        );
      } else {
        debugPrint('Error al editar máquina: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error de conexión al editar: $e');
    }
  }

  Future<void> _eliminarMaquina(int id) async {
       final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Máquina'),
        content: const Text('¿Estás seguro de eliminar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final resp = await http.delete(
        Uri.parse('$_baseUrl/$id/'),
      );
      if (resp.statusCode == 200) {
        setState(() {
          _maquinas.removeWhere((m) => m.id == id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Máquina eliminada exitosamente')),
        );
      } else {
        debugPrint('Error al eliminar máquina: ${resp.statusCode} - ${resp.body}');
      }
    } catch (e) {
      debugPrint('Error de conexión al eliminar: $e');
    }
  }

  void _mostrarDialogo({Maquina? maquina}) {
    final controller = TextEditingController(text: maquina?.maquina ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(maquina == null ? 'Crear Máquina' : 'Editar Máquina'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nombre de máquina',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(maquina == null ? 'Crear' : 'Guardar'),
            onPressed: () async {
              final input = controller.text.trim();
              if (input.isEmpty) return;
              if (maquina == null) {
                await _crearMaquina(input);
              } else {
                await _editarMaquina(maquina.id, input);
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Máquinas'),
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear Máquina',
            onPressed: () => _mostrarDialogo(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _maquinas.isEmpty
              ? const Center(child: Text('No hay máquinas registradas'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  itemCount: _maquinas.length,
                  itemBuilder: (context, index) {
                    final m = _maquinas[index];
                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 16,
                        ),
                        title: Text(
                          m.maquina,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _mostrarDialogo(maquina: m),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _eliminarMaquina(m.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
