import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class Operador {
  final int id;
  final String nombre;

  Operador({required this.id, required this.nombre});

  factory Operador.fromJson(Map<String, dynamic> json) {
    return Operador(
      id: json['id'] as int,
      nombre: json['nombre'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'nombre': nombre};
}

class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({Key? key}) : super(key: key);

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<Operador> _operadores = [];
  bool _isLoading = true;

  final String _baseUrl =
      'https://desarrollotecnologicoar.com/api2/operadores_logistica';

  @override
  void initState() {
    super.initState();
    _fetchOperadores();
  }

  Future<void> _fetchOperadores() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse('$_baseUrl/'));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          _operadores = data
              .map((item) => Operador.fromJson(item as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al cargar operadores: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conexión fallida: $e')),
      );
    }
  }

  Future<void> _crearOperador(String nombre) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        setState(() {
          _operadores.add(Operador.fromJson(data));
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operador creado')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al crear operador: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conexión fallida: $e')),
      );
    }
  }

  Future<void> _editarOperador(int id, String nombre) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/$id/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre}),
      );
      if (response.statusCode == 200) {
        setState(() {
          final idx = _operadores.indexWhere((o) => o.id == id);
          if (idx != -1) {
            _operadores[idx] = Operador(id: id, nombre: nombre);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operador actualizado')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al editar operador: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conexión fallida: $e')),
      );
    }
  }

  Future<void> _eliminarOperador(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar Operador'),
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
      final response = await http.delete(
        Uri.parse('$_baseUrl/$id/'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() => _operadores.removeWhere((o) => o.id == id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Operador eliminado')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error al eliminar: ${response.statusCode}',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Conexión fallida: $e')),
      );
    }
  }

  void _mostrarFormulario({Operador? operador}) {
    final controller = TextEditingController(text: operador?.nombre ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(operador == null ? 'Crear Operador' : 'Editar Operador'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nombre = controller.text.trim();
              if (nombre.isEmpty) return;
              Navigator.pop(context);
              if (operador == null) {
                _crearOperador(nombre);
              } else {
                _editarOperador(operador.id!, nombre);
              }
            },
            child: Text(operador == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operadores'),
        actions: [
          IconButton(
            onPressed: () => _mostrarFormulario(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _operadores.isEmpty
              ? const Center(child: Text('No hay operadores'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _operadores.length,
                  itemBuilder: (ctx, i) {
                    final op = _operadores[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        title: Text(op.nombre),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _mostrarFormulario(operador: op),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _eliminarOperador(op.id!),
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
