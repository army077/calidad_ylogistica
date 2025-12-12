import 'dart:convert';
import 'dart:io';
// import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_rastreabilidad/entities/orden.dart';
// import 'package:todo_app/functions/generate_pdf_function.dart';
import 'package:sistema_rastreabilidad/services/auth_service.dart';
import 'package:flutter/services.dart';
// import 'package:todo_app/shared/form_ensamble.dart';
import '../entities/tareas.dart';
// import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ActividadesInspeccion extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const ActividadesInspeccion({Key? key, required this.arguments})
      : super(key: key);

  @override
  _ActividadesInspeccion createState() => _ActividadesInspeccion();
}

final user = FirebaseAuth.instance.currentUser;

class _ActividadesInspeccion extends State<ActividadesInspeccion>
    with WidgetsBindingObserver {
  late Future<List<Tarea>> futureTareas;
  final AuthService _authService = AuthService();
  List<Tarea> tareas = [];
  List<File> fotosPendientes = [];
  List<File> fotosPendientesEvidencia = [];

  bool _isLoading = false; // Variable de estado para el indicador de carga
  DateTime? startedAt;
  OrdenInspeccion? ordenSeleccionada;

  final TextEditingController _timeController = TextEditingController();
  late final int idReal;

  @override
  void initState() {
    super.initState();
    print("=== ARGUMENTOS RECIBIDOS EN ACTIVIDADES ===");
    print(widget.arguments);

    if (widget.arguments['id_tabla'] != null) {
      idReal = widget.arguments['id_tabla'] is int
          ? widget.arguments['id_tabla']
          : int.parse(widget.arguments['id_tabla'].toString());
    } else {
      throw Exception("❌ No se recibió id_tabla en ActividadesInspeccion");
    }
    startedAt = DateTime.now();
    _reloadTareas(); // Aquí inicializas la lista
    _loadOrdenSeleccionada(idReal);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _timeController.dispose();

    WidgetsBinding.instance.removeObserver(this); // Quitamos el observer
    super.dispose();
  }

  Future<void> _loadOrdenSeleccionada(int idReal) async {
    try {
      final orden = await fetchInspectionOrder(idReal);

      setState(() {
        ordenSeleccionada = orden; // Suponiendo que es OrdenInspeccion?
      });
    } catch (e) {
      print('❌ Error cargando orden de inspección: $e');
      // aquí si quieres pones un SnackBar o algo
    }
  }

  Future<List<Tarea>> _loadTareas(int idReal, int idTabla) async {
    print(
        'Llamando a _loadTareas con ID de actividades: $idReal y ID de orden agendada: $idTabla');
    try {
      final url = Uri.parse(
          'https://desarrollotecnologicoar.com/api10/quality/$idTabla/inspection_tasks');
      final response = await HttpClient().getUrl(url);
      final result = await response.close();
      if (result.statusCode == 200) {
        final jsonString = await result.transform(utf8.decoder).join();

        final List<dynamic> jsonList = json.decode(jsonString);
        List<Tarea> tareasList =
            jsonList.map((json) => Tarea.fromJson(json)).toList();

        return tareasList;
      } else {
        print(
            'Error al cargar las tareas. Código de error: ${result.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error al cargar las tareas: $e');
      return [];
    }
  }

  Future<void> _signOutWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    await _signOutWithGoogle();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login', // cambia al nombre real de tu ruta
      (route) => false,
    );
  }

  int conteoCompletados = 0;
  int conteoTotal = 0;

  Future<void> sendTasksToGeneratePdfWithLoading() async {
    setState(() {
      _isLoading = true; // Activa el indicador de carga
    });

    try {
      final int idReal = widget.arguments['id_real']!;

      final orden = await fetchInspectionOrder(idReal);

      // Aquí ya tienes la orden correcta, no hace falta filtrar nada
      OrdenInspeccion ordenSeleccionada = orden;

      // Ejemplo de uso:
      // await sendTasksToGeneratePdf(
      //   context,
      //   tareas,
      //   ordenSeleccionada.customerName ?? "",
      //   ordenSeleccionada,
      // );
    } catch (e) {
      print("Error al obtener la orden de inspección: $e");
    } finally {
      setState(() {
        _isLoading = false; // Desactiva el indicador de carga
      });
    }
  }

  Future<void> _clearPreferences() async {
    // final prefs = await SharedPreferences.getInstance();
    final idReal = widget.arguments['id_real']!;
    final idTabla = widget.arguments['id_tabla']!;
    final cacheKey = 'tareas_${idReal}_$idTabla';
    try {
      final url = Uri.parse(
          'https://desarrollotecnologicoar.com/api10/quality/$idTabla/restart_stavance');
      final payload = {
        "work_order_id": ordenSeleccionada?.workOrderId,
      };
      final req = await HttpClient().putUrl(url)
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(payload));

      final resultado = await req.close();

      if (resultado.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Formulario limpio... (se reiniciaron todas tus actividades)')),
        );
        await _reloadTareas(); // Recarga las tareas para reflejar los cambios
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Error al reiniciar las actividades, intenta de nuevo')),
        );
      }
    } catch (e) {
      print('Error al mandar tus datos: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Ocurrió un error al intentar reiniciar las actividades.')),
      );
    }

    // print('Caché limpiado para ID real: $idReal y tabla: $idTabla');
  }

  Future<void> _confirmarReinicio() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "¿Reiniciar inspección?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Esto borrará todo tu progreso en esta inspección, incluyendo "
            "las tareas completadas y los tiempos registrados.\n\n"
            "¿Seguro que quieres continuar?",
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Sí, reiniciar"),
            )
          ],
        );
      },
    );

    if (confirmar == true) {
      // Segunda confirmación más dura
      final confirmar2 = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              "Última oportunidad",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              "Esta acción NO se puede deshacer.\n\n"
              "¿Realmente quieres reiniciar TODA la inspección?",
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("No"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Sí, estoy seguro"),
              )
            ],
          );
        },
      );

      if (confirmar2 == true) {
        await _clearPreferences();
      }
    }
  }

  void _verificarSeccionesCompletas(Tarea tarea) async {
    if (tareas.isEmpty) return;

    // agrupa por sección
    final Map<String, List<Tarea>> porSeccion = {};

    for (var t in tareas) {
      porSeccion.putIfAbsent(t.sectionTitle, () => []);
      porSeccion[t.sectionTitle]!.add(t);
    }

    // recorre cada sección
    porSeccion.forEach((seccion, listaTareas) async {
      final todasCompletas = listaTareas.every((t) => t.completada);

      if (todasCompletas) {
        // evita mostrar 500 modales si build se repite
        if (_seccionesCompletadas.contains(seccion)) return;

        _seccionesCompletadas.add(seccion);

        // muestra aviso
        await _mostrarModalSeccionTerminada(seccion, tarea);
      }
    });
  }

  Future<void> _mostrarModalSeccionTerminada(
      String seccion, Tarea tarea) async {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sección completada',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Has completado todas las actividades de la sección.\n\n'
          'Si presionas aceptar se le liberará la actividad "$seccion" al operador de producción.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                {Navigator.pop(context), _markAsCompleted(tarea, false)},
            child: const Text("Cancelar"),
            style: TextButton.styleFrom(
              foregroundColor: const Color.fromARGB(255, 0, 0, 0),
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          TextButton(
            onPressed: () =>
                {_completarTareaProduccion(seccion), Navigator.pop(context)},
            child: const Text("Aceptar"),
            style: TextButton.styleFrom(
              foregroundColor: const Color.fromARGB(255, 0, 126, 21),
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completarTareaProduccion(String seccion) async {
    final idWO = ordenSeleccionada?.workOrderId;

    if (idWO == null) {
      print("⚠️ No hay workOrderId");
      return;
    }

    // 1️⃣ Filtrar solo tareas de la sección actual
    final tareasSeccion =
        tareas.where((t) => t.sectionTitle == seccion).toList();

    if (tareasSeccion.isEmpty) {
      print("⚠️ No existen tareas en la sección $seccion");
      return;
    }

    // 2️⃣ Encontrar el started_at más viejo (inicio real de la sección)
    tareasSeccion.removeWhere((t) => t.startedAt == null);
    if (tareasSeccion.isEmpty) {
      print("⚠️ No hay startedAt válidos en la sección");
      return;
    }

    tareasSeccion.sort((a, b) => a.startedAt!.compareTo(b.startedAt!));
    final DateTime primerStarted = tareasSeccion.first.startedAt!;
    print("Primer started en sección '$seccion': $primerStarted");

    // 3️⃣ finished_at debe ser ahora
    final DateTime finishedNow = DateTime.now();
    print("Finished at ahora: $finishedNow");

    // 4️⃣ Calcular minutos reales
    final int actualMinutes = finishedNow.difference(primerStarted).inMinutes;

    final payload = {
      "section_title": seccion,
      "started_at": primerStarted.toIso8601String(),
      "finished_at": finishedNow.toIso8601String(),
      "actual_minutes": actualMinutes,
    };

    try {
      final url = Uri.parse(
        "https://desarrollotecnologicoar.com/api10/quality/liberar_orden/$idWO",
      );

      final req = await HttpClient().putUrl(url)
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(payload));

      final res = await req.close();

      if (res.statusCode == 200) {
        print("✅ Sección '$seccion' liberada correctamente en producción.");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sección '$seccion' liberada en producción ✅"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        print("❌ Error liberando sección: ${res.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Error liberando sección '$seccion' (${res.statusCode})"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("❌ Error en _completarTareaProduccion: $e");
    }
  }

// Para evitar duplicados
  final Set<String> _seccionesCompletadas = {};

  void _actualizarConteo() {
    setState(() {
      conteoTotal = tareas.length;
      conteoCompletados = tareas.where((t) => t.completada).length;
    });
  }

  Future<void> _reloadTareas() async {
    final idReal = widget.arguments['id_real']!;
    final idTabla = widget.arguments['id_tabla']!;

    List<Tarea> nuevasTareas = await _loadTareas(idReal, idTabla);

    setState(() {
      tareas = nuevasTareas;
    });

    _actualizarConteo();
  }

  Future<List<Map<String, dynamic>>> _fetchCustomizations(
      int workOrderId) async {
    final url = Uri.parse(
        'https://desarrollotecnologicoar.com/api10/customs/workorder/$workOrderId');

    try {
      final request = await HttpClient().getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> data = jsonDecode(body);
        return data
            .map((item) => {
                  'id': item['id'],
                  'work_order_id': item['work_order_id'],
                  'custom_title': item['custom_title'] ?? 'Sin título',
                })
            .toList();
      } else {
        print('⚠️ Error al obtener customizaciones: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error en _fetchCustomizations: $e');
      return [];
    }
  }

  // void _showInspectionModal(Tarea tarea) {
  //   final TextEditingController stationController = TextEditingController();
  //   String? tipoInspeccion;
  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.white,
  //     constraints: BoxConstraints(
  //       minHeight: MediaQuery.of(context).size.height * 0.45,
  //       maxHeight: MediaQuery.of(context).size.height * 0.90,
  //     ),
  //     shape: const RoundedRectangleBorder(
  //       borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  //     ),
  //     builder: (context) {
  //       return Padding(
  //         padding: EdgeInsets.only(
  //           bottom: MediaQuery.of(context).viewInsets.bottom + 24,
  //           left: 16,
  //           right: 16,
  //           top: 50,
  //         ),
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Center(
  //               child: Column(
  //                 children: [
  //                   Container(
  //                     width: 50,
  //                     height: 4,
  //                     decoration: BoxDecoration(
  //                       color: Colors.grey[300],
  //                       borderRadius: BorderRadius.circular(2),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 12),
  //                   Text(
  //                     "Inspección requerida",
  //                     style: const TextStyle(
  //                       fontSize: 20,
  //                       fontWeight: FontWeight.bold,
  //                       color: Color(0xFF8B0000),
  //                     ),
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Text(
  //                     'Tarea: ${tarea.revisionPoint}',
  //                     style: const TextStyle(color: Colors.black54),
  //                     textAlign: TextAlign.center,
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             const SizedBox(height: 24),
  //             TextField(
  //               controller: stationController,
  //               keyboardType: TextInputType.number,
  //               decoration: InputDecoration(
  //                 labelText: 'Número de estación',
  //                 border: OutlineInputBorder(
  //                   borderRadius: BorderRadius.circular(12),
  //                 ),
  //                 filled: true,
  //                 fillColor: Colors.grey[100],
  //               ),
  //             ),
  //             const SizedBox(height: 24),
  //             Row(
  //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //               children: [
  //                 OutlinedButton.icon(
  //                   onPressed: () => Navigator.pop(context),
  //                   icon: const Icon(Icons.close, color: Colors.black54),
  //                   label: const Text('Cerrar'),
  //                   style: OutlinedButton.styleFrom(
  //                     foregroundColor: Colors.black87,
  //                     side: const BorderSide(color: Colors.black26),
  //                     padding: const EdgeInsets.symmetric(
  //                         horizontal: 24, vertical: 14),
  //                     shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(30)),
  //                   ),
  //                 ),
  //                 ElevatedButton.icon(
  //                   onPressed: () async {
  //                     if (stationController.text.isEmpty) {
  //                       ScaffoldMessenger.of(context).showSnackBar(
  //                         const SnackBar(
  //                           content:
  //                               Text('Por favor ingresa número de estación.'),
  //                           backgroundColor: Colors.redAccent,
  //                         ),
  //                       );
  //                       return;
  //                     }
  //                     final payload = {
  //                       "work_order_id": widget.arguments['id_tabla'],
  //                       "estacion": stationController.text.trim(),
  //                       "assigned_tech_email": user?.email ?? "desconocido",
  //                       "comments": "Inspección solicitada desde app móvil"
  //                     };
  //                     try {
  //                       final url = Uri.parse(
  //                           'https://desarrollotecnologicoar.com/api10/quality/inspection/request');
  //                       final request = await HttpClient().postUrl(url)
  //                         ..headers.contentType = ContentType.json
  //                         ..write(jsonEncode(payload));
  //                       final response = await request.close();
  //                       if (response.statusCode == 200 ||
  //                           response.statusCode == 201) {
  //                         Navigator.pop(context);
  //                         ScaffoldMessenger.of(context).showSnackBar(
  //                           const SnackBar(
  //                             content: Text(
  //                                 'Inspección solicitada correctamente 📝'),
  //                             backgroundColor: Colors.green,
  //                           ),
  //                         );
  //                       } else if (response.statusCode == 409) {
  //                         Navigator.pop(context);
  //                         ScaffoldMessenger.of(context).showSnackBar(
  //                           const SnackBar(
  //                             content: Text(
  //                                 'Ya existe una inspección pendiente para esta orden.'),
  //                             backgroundColor: Colors.orange,
  //                           ),
  //                         );
  //                       } else {
  //                         print(
  //                             '❌ Error al registrar inspección: ${response.statusCode}');
  //                         Navigator.pop(context);
  //                         ScaffoldMessenger.of(context).showSnackBar(
  //                           SnackBar(
  //                             content: Text(
  //                                 'Error al solicitar inspección (${response.statusCode})'),
  //                             backgroundColor: Colors.redAccent,
  //                           ),
  //                         );
  //                       }
  //                     } catch (e) {
  //                       print('❌ Error al registrar inspección: $e');
  //                       ScaffoldMessenger.of(context).showSnackBar(
  //                         const SnackBar(
  //                           content: Text(
  //                               'Error de conexión al solicitar inspección.'),
  //                           backgroundColor: Colors.redAccent,
  //                         ),
  //                       );
  //                     }
  //                   },
  //                   icon: const Icon(Icons.assignment_turned_in),
  //                   label: const Text('Registrar inspección'),
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: const Color(0xFF8B0000),
  //                     foregroundColor: Colors.white,
  //                     padding: const EdgeInsets.symmetric(
  //                         horizontal: 24, vertical: 14),
  //                     shape: RoundedRectangleBorder(
  //                         borderRadius: BorderRadius.circular(30)),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //         ),
  //       );
  //     },
  //   );
  // }

  Future<List<String>> subirFotosPendientes() async {
    final machine = ordenSeleccionada?.machineSerial ?? "sin_serie";
    final carpeta = '$machine/proceso_inspeccion';

    List<String> urls = [];

    for (final foto in fotosPendientes) {
      final nombre = '$carpeta/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(nombre);

      await ref.putFile(foto);
      final url = await ref.getDownloadURL();

      urls.add(url);
    }

    return urls;
  }

  Future<bool> _registrarDesviacion({
    required Tarea tarea,
    required OrdenInspeccion orden,
    required String? parteAfectada,
    required String? causaRaiz,
    required String? clasificacionDefecto,
    required String? tipoDefecto,
    required String? clasificacionDefectivo,
    required String comentarios,
  }) async {
    try {
      // 1. Subir fotos SOLO cuando ya vas a registrar la desviación
      final List<String> urls = await subirFotosPendientes();

      // 2. Limpiar lista local
      setState(() {
        fotosPendientes.clear();
      });

      final url = Uri.parse(
        "https://desarrollotecnologicoar.com/api10/quality/desviaciones",
      );

      final tecnico = FirebaseAuth.instance.currentUser;

      final body = {
        "id_actividad": tarea.id,
        "correo": tecnico?.email ?? "",
        "usuario": tecnico?.displayName ?? "",
        "serial_number": orden.machineSerial,
        "afected_machine": orden.modelName,
        "num_revision": orden.templateVersion.toString(),
        "nombre_tecnico": orden.operadorProduccion,
        "parte_afectada": parteAfectada,
        "causa_raiz": causaRaiz,
        "clasificacion_defecto": clasificacionDefecto,
        "tipo_defectivo": tipoDefecto,
        "clasificacion_defectivo": clasificacionDefectivo,
        "comentarios": comentarios,
        "evidencias": urls, // 🔥 AQUI MANDAMOS LAS FOTOS
      };

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Desviación registrada")),
        );
        return true;
      } else {
        print("❌ ERROR: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al registrar desviación")),
        );
        return false;
      }
    } catch (e) {
      print("❌ Error registrando desviación: $e");
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchDesviaciones(int idActividad) async {
    final url = Uri.parse(
      'https://desarrollotecnologicoar.com/api10/quality/desviaciones/$idActividad',
    );

    try {
      final client = HttpClient();
      final request = await client.getUrl(url);
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final List<dynamic> data = jsonDecode(body);

        return data
            .map((item) => {
                  'id': item['id'],
                  'id_actividad': item['id_actividad'],
                  'correo': item['correo'],
                  'usuario': item['usuario'],
                  'created_at': item['created_at'],
                  'serial_number': item['serial_number'],
                  'afected_machine': item['afected_machine'],
                  'num_revision': item['num_revision'],
                  'nombre_tecnico': item['nombre_tecnico'],
                  'parte_afectada': item['parte_afectada'],
                  'causa_raiz': item['causa_raiz'],
                  'clasificacion_defecto': item['clasificacion_defecto'],
                  'tipo_defectivo': item['tipo_defectivo'],
                  'clasificacion_defectivo': item['clasificacion_defectivo'],
                  'comentarios': item['comentarios'],
                })
            .toList();
      } else {
        print('⚠️ Error HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error en fetchDesviaciones: $e');
      return [];
    }
  }

  void _showListaDesviaciones(List<Map<String, dynamic>> desviaciones) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: desviaciones.length,
              itemBuilder: (_, index) {
                final d = desviaciones[index];

                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Desviación #${d['id']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text("Parte afectada: ${d['parte_afectada']}"),
                        Text("Causa raíz: ${d['causa_raiz']}"),
                        Text("Clasificación: ${d['clasificacion_defecto']}"),
                        Text("Tipo defectivo: ${d['tipo_defectivo']}"),
                        Text("Defectivo: ${d['clasificacion_defectivo']}"),
                        const SizedBox(height: 10),
                        Text(
                          "Comentarios:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(d['comentarios'] ?? "Sin comentarios"),
                        const SizedBox(height: 10),
                        Text(
                          "Registrado por ${d['usuario']} el ${d['created_at']}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _infoDialog() async {
    final idReal = widget.arguments['id_real']!;
    List<Map<String, dynamic>> customizations = [];

    // Mostrar indicador mientras carga la info
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    // 🔹 Cargar customizaciones desde la API
    customizations = await _fetchCustomizations(ordenSeleccionada!.workOrderId);

    // Cerrar el loading dialog
    Navigator.of(context).pop();

    // Mostrar el diálogo final con info general + customizaciones
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF8B0000), size: 26),
              SizedBox(width: 8),
              Text(
                'Detalles de la Inspección',
                style: TextStyle(
                  color: Color.fromARGB(255, 37, 37, 37),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👋 Saludo
                Text(
                  'Hola, ${user?.displayName ?? 'Analista'} 👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(),

                // 🧾 Información general
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text(
                      'Máquina en estación',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(
                        '${ordenSeleccionada?.estacion ?? "N/A"}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: const Color(0xFF8B0000),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(),

                const Text(
                  'Información general:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),

                _infoRow(
                  Icons.person,
                  'Operador de ensamble',
                  ordenSeleccionada?.operadorProduccion != null
                      ? ordenSeleccionada!.operadorProduccion!
                          .replaceAll('@asiarobotica.com', '')
                          .replaceAll('.', ' ')
                      : 'N/A',
                ),
                _infoRow(Icons.precision_manufacturing, 'Equipo',
                    ordenSeleccionada?.modelName),
                _infoRow(
                    Icons.comment, 'Comentarios', ordenSeleccionada?.comments),
                _infoRow(Icons.qr_code, 'Número de Serie',
                    ordenSeleccionada?.machineSerial),

                const SizedBox(height: 8),
                _infoRow(
                  Icons.access_time,
                  'Fecha de creación',
                  ordenSeleccionada != null
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format(ordenSeleccionada!.createdAt)
                      : 'N/A',
                ),

                const SizedBox(height: 20),

                // 🔍 Estado general
                const Text(
                  'Estado actual:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Chip(
                    backgroundColor: ordenSeleccionada?.status == 'FINISHED'
                        ? Colors.green[100]
                        : Colors.orange[100],
                    avatar: Icon(
                      ordenSeleccionada?.status == 'FINISHED'
                          ? Icons.check_circle
                          : Icons.timelapse,
                      color: ordenSeleccionada?.status == 'FINISHED'
                          ? Colors.green[700]
                          : Colors.orange[700],
                    ),
                    label: Text(
                      ordenSeleccionada?.status ?? 'Desconocido',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ordenSeleccionada?.status == 'FINISHED'
                            ? Colors.green[800]
                            : Colors.orange[800],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),

                // 🧩 Customizaciones
                const Text(
                  'Customizaciones de la Orden:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),

                if (customizations.isEmpty)
                  const Text(
                    'Sin personalizaciones registradas.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: customizations.map((c) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.build_circle,
                                color: Color(0xFF8B0000), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                c['custom_title'] ?? 'Sin título',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.close, color: Color(0xFF8B0000)),
              label: const Text(
                'Cerrar',
                style: TextStyle(
                  color: Color(0xFF8B0000),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

// 🔹 Función auxiliar para filas limpias
  Widget _infoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF8B0000), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '$label: ',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: value?.isNotEmpty == true ? value : 'N/A',
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1.0),
      child: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline, color: Colors.white),
              onPressed:
                  _infoDialog, // Llama a la función para ver los detalles de la orden
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              onPressed:
                  _confirmarReinicio, // Llama a la función para limpiar el formulario
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _cerrarSesion,
            ),
          ],
          title: Text(
            'Estación ${ordenSeleccionada?.estacion ?? ''}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color.fromRGBO(22, 23, 24, 0.8),
        ),
        body: tareas.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _reloadTareas,
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    if (tareas.any((t) => t.completada)) ...[
                      _buildSectionTitle('Puntos de inspección completados',
                          Icons.check_circle),
                      ..._buildTaskList(
                        tareas.where((t) => t.completada).toList(),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (tareas.any((t) => !t.completada)) ...[
                      _buildSectionTitle('Puntos de inspección pendientes',
                          Icons.pending_actions),
                      ..._buildTaskList(
                        tareas.where((t) => !t.completada).toList(),
                      ),
                    ]
                  ],
                ),
              ),
        floatingActionButton: conteoTotal > 0 &&
                conteoCompletados == conteoTotal
            ? FloatingActionButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final bool pinValid = await _requestPinFinalized();
                        if (!pinValid) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('PIN inválido o acción cancelada.')),
                          );
                          return; // Salir sin actualizar el estado
                        }
                        // 1. Generar PDF
                        // await sendTasksToGeneratePdfWithLoading();
                        // 2. Luego Finalizar orden
                        await _finalizarOrdenAgendada();
                      },
                backgroundColor: const Color.fromARGB(255, 46, 46, 46),
                foregroundColor: Colors.white,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.send),
              )
            : null,
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildTaskList(List<Tarea> tareas) {
    return tareas.map((tarea) {
      return ListTile(
        leading: SizedBox(
          width: 46, // Define un ancho para que el contenido no desborde
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(
                getIconForCategory(tarea.category),
                size: 22,
              ),
              const SizedBox(width: 3), // Espacio entre el ícono y el texto
              Text("${tarea.position}."),
            ],
          ),
        ),
        title: Text(tarea.revisionPoint),
        trailing: tarea.status.contains('LIB')
            ? const Icon(Icons.lock_outline, color: Colors.grey)
            : Checkbox(
                value: tarea.completada,
                onChanged: (bool? value) {
                  if (tarea.completada) {
                    _markAsCompleted(tarea, false);
                  } else {
                    _showTaskDetails(tarea);
                  }
                },
              ),
        onTap: () {
          if (tarea.completada) return; // No hacer nada si ya está completada
          _showTaskDetails(tarea);
        },
      );
    }).toList();
  }

  void _showTaskDetails(Tarea tarea) async {
    final commentController = TextEditingController();

    // Estados individuales
    String? parteAfectada;
    String? causaRaiz;
    String? clasificacionDefecto;
    String? tipoDefecto;
    String? clasificacionDefectivo;

    bool mostrarFormulario = false;

    final desviaciones = await fetchDesviaciones(tarea.id);

    final partesAfectadas = [
      'Funcionalidad',
      'Gabinete de la mesa',
      'Gabinete',
      'Mesa parte laterales',
      'Mesa parte frontal',
      'Puente y brazos',
      'Mesa área de trabajo',
      'Patas y Ruedas',
      'Cabezal',
      'Área de trabajo',
      'Equipo parte laterales',
      'Cadena de Y y base',
      'Equipo parte frontal',
      'Bomba de vacío',
      'Chiller',
      'Colector de polvo',
      'Generador plasma',
      'Extractor de emisiones',
      'Pedestal',
      'Controlador',
      'Equipo parte trasera',
      'Lentes, ventanas o herramentales',
      'Rodillos',
      'Alimentador de aporte',
      'Pistola',
    ];
    final causasRaiz = [
      'Operador negligente',
      'Operador mal capacitado',
      'Desviación del proceso autorizada',
      'Operador en entrenamiento',
      'Máquina o equipo (proveedor)',
      'Mal resguardo',
      'Mala manipulación de traslado',
    ];
    final clasificacionesDefecto = ['Menor', 'Mayor', 'Crítico'];
    final tiposDefecto = ['Funcional', 'Estético', 'Configuración'];
    final clasificacionesDefectivo = [
      'Falta de componente',
      'Limpieza deficiente',
      'Tornillería mal ajustada',
      'Componente dañado',
      'Componente fuera de especificación',
      'Equipo con daños en zona A',
      'Mala aplicación de pintura cara C',
      'Mal etiquetado',
      'Equipo mal configurado o parametrizado',
      'Conexiones eléctricas mal ajustadas',
      'Equipo con daños en zona B',
      'Mala instalación de piezas',
      'Defecto de proveedor',
      'Conexiones neumáticas mal ajustadas',
      'Paro de emergencia dañado',
      'Transmisión con falla',
      'Liberación sin pruebas de calidad',
      'Mal surtido de almacén',
      'Diseño de proveedor',
      'Mesa descuadrada',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                    left: 16,
                    right: 16,
                    top: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle superior
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Encabezado
                      Center(
                        child: Column(
                          children: [
                            Text(
                              tarea.revisionPoint,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B0000),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "Id de la tarea: ${tarea.id} • Sección: ${tarea.sectionTitle}",
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.yellow[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber, width: 1),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.info,
                                      color: Colors.amber, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    "Especificaciones",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.amber,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tarea.specs ?? "Sin especificaciones",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.blueAccent, width: 1),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.lightbulb,
                                      color: Colors.blueAccent, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    "Sugerencias",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tarea.suggestions ?? "Sin sugerencias",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(),

                      if (tarea.comments != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          "Comentarios previos: ${tarea.comments}",
                          style: const TextStyle(
                              fontSize: 15, color: Colors.black54),
                        ),
                      ],

                      const SizedBox(height: 25),

                      // BOTÓN QUE DESPLIEGA EL FORMULARIO
                      Center(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setModalState(() {
                              mostrarFormulario = !mostrarFormulario;
                            });
                          },
                          icon: const Icon(Icons.access_time),
                          label: Text(
                            mostrarFormulario
                                ? "Ocultar formulario de desviación"
                                : "Registrar desviación",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B0000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                      ),

                      if (desviaciones.isNotEmpty && !mostrarFormulario) ...[
                        const SizedBox(height: 20),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showListaDesviaciones(desviaciones);
                            },
                            icon: const Icon(Icons.list_alt),
                            label: Text(
                                "Ver desviaciones (${desviaciones.length})"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black87,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ANIMACIÓN SUAVE PARA EL FORMULARIO
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: mostrarFormulario
                            ? Column(
                                key: const ValueKey("formulario"),
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    child: _selector(
                                      label: "Parte afectada",
                                      value: parteAfectada,
                                      items: partesAfectadas,
                                      onChanged: (v) => setModalState(() {
                                        parteAfectada = v;
                                      }),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  SizedBox(
                                    width: double.infinity,
                                    child: _selector(
                                      label: "Causa raíz",
                                      value: causaRaiz,
                                      items: causasRaiz,
                                      onChanged: (v) =>
                                          setModalState(() => causaRaiz = v),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  SizedBox(
                                    width: double.infinity,
                                    child: _selector(
                                      label: "Clasificación del defecto",
                                      value: clasificacionDefecto,
                                      items: clasificacionesDefecto,
                                      onChanged: (v) => setModalState(
                                          () => clasificacionDefecto = v),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  SizedBox(
                                    width: double.infinity,
                                    child: _selector(
                                      label: "Tipo de defecto",
                                      value: tipoDefecto,
                                      items: tiposDefecto,
                                      onChanged: (v) =>
                                          setModalState(() => tipoDefecto = v),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: _selector(
                                      label: "Clasificación del defectivo",
                                      value: clasificacionDefectivo,
                                      items: clasificacionesDefectivo,
                                      onChanged: (v) => setModalState(
                                          () => clasificacionDefectivo = v),
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  TextField(
                                    controller: commentController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      labelText: "Comentarios adicionales",
                                      filled: true,
                                      fillColor: Colors.grey[100],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // BOTONES DEL FORMULARIO
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.black87,
                                            side: const BorderSide(
                                                color: Colors.grey),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                          child: const Text("Cancelar"),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            if (parteAfectada == null ||
                                                causaRaiz == null ||
                                                clasificacionDefecto == null ||
                                                tipoDefecto == null ||
                                                clasificacionDefectivo ==
                                                    null) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          "Completa todos los campos")));
                                              return;
                                            }

                                            final ok =
                                                await _registrarDesviacion(
                                              tarea: tarea,
                                              orden: ordenSeleccionada!,
                                              parteAfectada: parteAfectada,
                                              causaRaiz: causaRaiz,
                                              clasificacionDefecto:
                                                  clasificacionDefecto,
                                              tipoDefecto: tipoDefecto,
                                              clasificacionDefectivo:
                                                  clasificacionDefectivo,
                                              comentarios:
                                                  commentController.text.trim(),
                                            );

                                            if (ok && mounted) {
                                              Navigator.pop(context);
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF8B0000),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                          child: const Text("Guardar"),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      IconButton(
                                        icon: const Icon(Icons.camera_alt,
                                            color: Color.fromARGB(
                                                255, 54, 54, 54)),
                                        onPressed: () async {
                                          _tomarFoto();
                                        },
                                      ),
                                      if (fotosPendientes.isNotEmpty)
                                        Text(
                                          "Fotos agregadas: ${fotosPendientes.length}",
                                          style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      // SizedBox(
                                      //   height: 80,
                                      //   child: ListView(
                                      //     scrollDirection: Axis.horizontal,
                                      //     children: fotosPendientes
                                      //         .map((f) => Padding(
                                      //               padding:
                                      //                   const EdgeInsets.all(
                                      //                       4.0),
                                      //               child: Image.file(f,
                                      //                   width: 80,
                                      //                   height: 80,
                                      //                   fit: BoxFit.cover),
                                      //             ))
                                      //         .toList(),
                                      //   ),
                                      // ),
                                    ],
                                  ),
                                ],
                              )
                            : const SizedBox(height: 1),
                      ),

                      // BOTÓN INSPECCIÓN COMPLETADA
                      !mostrarFormulario
                          ? Center(
                              child: OutlinedButton.icon(
                                onPressed: () => {
                                  _markAsCompleted(tarea, true),
                                  Navigator.pop(context),
                                },
                                icon: const Icon(Icons.check,
                                    color: Colors.green),
                                label: const Text("Inspección completada"),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  foregroundColor: Colors.green,
                                  backgroundColor:
                                      Colors.lightGreen.withOpacity(0.1),
                                  side: const BorderSide(color: Colors.green),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(height: 1),

                      const SizedBox(height: 25),

                      !mostrarFormulario
                          ? Center(
                              child: OutlinedButton.icon(
                                onPressed: () => {
                                  _tomarFotoEvidencial(tarea.revisionPoint),
                                },
                                icon: const Icon(Icons.photo_camera_rounded,
                                    color: Color.fromARGB(255, 0, 0, 0)),
                                label: const Text("Registrar evidencia"),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 14),
                                  foregroundColor:
                                      const Color.fromARGB(255, 0, 0, 0),
                                  backgroundColor:
                                      const Color.fromARGB(255, 0, 140, 255)
                                          .withOpacity(0.1),
                                  side: const BorderSide(
                                      color: Color.fromARGB(255, 0, 0, 0)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox(height: 1),

                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _selector({
    required String label,
    required String? value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth,
          ),
          child: DropdownButtonFormField<String>(
            isExpanded: true, // IMPORTANTE
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            value: value,
            onChanged: onChanged,
            items: items
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
          ),
        );
      },
    );
  }

  void _sanearSecciones() {
    final seccionesActuales = <String>{};

    for (var t in tareas) {
      if (!t.completada) {
        _seccionesCompletadas.remove(t.sectionTitle);
      }
    }
  }

  void _markAsCompleted(Tarea tarea, bool isCompleted) async {
    final int tareaId = tarea.id;
    // Definir hora actual
    final now = DateTime.now();
    // Buscar última tarea completada (para saber cuándo empezó esta)
    final tareasCompletadas = tareas.where((t) => t.completada).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    DateTime startedAt;
    if (tareasCompletadas.isEmpty) {
      // Si es la primera tarea completada, inicia desde el inicio de la orden o ahora
      startedAt =
          ordenSeleccionada?.createdAt ?? ordenSeleccionada?.createdAt ?? now;
    } else {
      // Si ya hay tareas, usar el último finished_at
      final ultima = tareasCompletadas.last;

      startedAt = ultima.finishedAt ?? now;
    }
    DateTime finishedAt = now;
    int actualMinutes = finishedAt.difference(startedAt).inMinutes;
    // Actualizar visualmente el estado
    setState(() {
      tarea.completada = isCompleted;
    });
    final payload = {
      "status": isCompleted ? "DONE" : "PENDING",
      "started_at": startedAt.toIso8601String(),
      "finished_at": finishedAt.toIso8601String(),
      "actual_minutes": isCompleted ? actualMinutes : null,
    };

    try {
      final url = Uri.parse(
          'https://desarrollotecnologicoar.com/api10/quality/$tareaId/stavance');
      final request = await HttpClient().putUrl(url)
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(payload));

      final response = await request.close();

      if (response.statusCode == 200) {
        print('✅ Inspección ${tarea.revisionPoint} marcada como completada.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCompleted
                ? 'Tarea "${tarea.revisionPoint}" completada ✅'
                : 'Tarea "${tarea.revisionPoint}" marcada como pendiente.'),
            backgroundColor: isCompleted ? Colors.green : Colors.orangeAccent,
            duration: const Duration(seconds: 2),
          ),
        );
        if (isCompleted) {
          tarea.startedAt = startedAt;
          tarea.finishedAt = finishedAt;
          tarea.actualMinutes = actualMinutes;
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.click);
        }
      } else {
        print('⚠️ Error al actualizar tarea. Código: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al actualizar progreso: $e');
    }

    // actualizar conteos y verificar secciones
    _actualizarConteo();
    _sanearSecciones();
    _verificarSeccionesCompletas(tarea);
  }

  // Future<bool> _requestPin() async {
  //   String correctPin = "82469173";
  //   String? enteredPin = await showDialog<String>(
  //     context: context,
  //     builder: (BuildContext context) {
  //       TextEditingController pinController = TextEditingController();
  //       return AlertDialog(
  //         title: const Text('Ingrese el PIN'),
  //         content: TextField(
  //           controller: pinController,
  //           obscureText: true,
  //           keyboardType: TextInputType.number,
  //           decoration: const InputDecoration(
  //             labelText: 'PIN',
  //             hintText: 'Ingrese el PIN para completar esta tarea',
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context, null),
  //             child: const Text('Cancelar'),
  //           ),
  //           TextButton(
  //             onPressed: () =>
  //                 Navigator.pop(context, pinController.text.trim()),
  //             child: const Text('Confirmar'),
  //           ),
  //         ],
  //       );
  //     },
  //   );

  //   return enteredPin == correctPin;
  // }

  Future<bool> _requestPinFinalized() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('¿Finalizar inspección?'),
          content: const Text(
            '¿Estás seguro que deseas finalizar la inspección? Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );
    return confirmar == true;
  }

  Future<void> _finalizarOrdenAgendada() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final int idTabla = widget.arguments['id_tabla']!;
      final startedAt =
          widget.arguments['started_at'] ?? DateTime.now().toIso8601String();

      final url = Uri.parse(
        'https://desarrollotecnologicoar.com/api10/quality/$idTabla/insp_end',
      );

      final request = await HttpClient().putUrl(url)
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({"started_at": startedAt}));

      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Orden finalizada exitosamente ✅'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        HapticFeedback.heavyImpact();

        await Future.delayed(const Duration(seconds: 1));

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/procesoInspeccion');
        }
      } else if (response.statusCode == 404) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Orden no encontrada ⚠️'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Error al finalizar la orden (${response.statusCode})'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      print('❌ Error al finalizar orden: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error de conexión al finalizar la orden ❌'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();

    final XFile? foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (foto == null) return;

    final file = File(foto.path);

    setState(() {
      fotosPendientes.add(file);
    });
  }

  Future<void> _tomarFotoEvidencial(revisionPoint) async {
    final picker = ImagePicker();

    final XFile? foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (foto == null) return;

    final file = File(foto.path);

    setState(() {
      fotosPendientesEvidencia.add(file);
    });

    if (fotosPendientesEvidencia.length > 0 && mounted) {
      try {
        final urls = await subirFotosPendientesEvidencia(revisionPoint);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Evidencia subida correctamente (${urls.length} fotos) ✅'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        setState(() {
          fotosPendientesEvidencia.clear();
        });
      } catch (e) {
        print('❌ Error al subir evidencia: $e');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al subir evidencia ❌'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

Future<List<String>> subirFotosPendientesEvidencia(String puntoRevision) async {
  final machine = ordenSeleccionada?.machineSerial ?? "sin_serie";
  final carpeta = '$machine/evidencia/$puntoRevision';

  List<String> urls = [];

  for (final foto in fotosPendientesEvidencia) {
    final nombre = '$carpeta/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref().child(nombre);

    await ref.putFile(foto);
    final url = await ref.getDownloadURL();
    urls.add(url);
  }

  if (urls.isEmpty) return urls;

  try {
    final endpoint = Uri.parse(
      "https://desarrollotecnologicoar.com/api10/quality/inspection/orders/${idReal}/add_evidence"
    );

    final payload = {
      "nuevas_fotos": urls,
    };

    final req = await HttpClient().putUrl(endpoint)
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));

    final res = await req.close();

    if (res.statusCode == 200) {
      print("✅ Evidencias agregadas correctamente");

      setState(() {
        fotosPendientesEvidencia.clear();
      });

      return urls;
    } else {
      print("❌ Error HTTP ${res.statusCode} para la orden ${idReal}");
    }

  } catch (e) {
    print("❌ Error al subir evidencias: $e");
  }

  return urls;
}


}

IconData getIconForCategory(String category) {
  switch (category.toLowerCase()) {
    case 'mecanica':
      return Icons.build;
    case 'electrica':
      return Icons.electrical_services;
    case 'limpieza':
      return Icons.cleaning_services;
    case 'estética':
      return Icons.design_services;
    default:
      return Icons.task_alt;
  }
}
