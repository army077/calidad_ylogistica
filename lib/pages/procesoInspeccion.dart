// ignore_for_file: library_private_types_in_public_api, unused_element, unnecessary_null_comparison, use_build_context_synchronously, avoid_print, file_names

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import './actividadesInspeccion.dart';

List<String> _maquinasList = [];
bool _isLoadingMachines = true;

List<String> _operadoresList = [];
bool _isLoadingOperadores = true;

class ProcesoInspeccion extends StatefulWidget {
  final String tecnicoEmail;
  const ProcesoInspeccion({Key? key, required this.tecnicoEmail})
      : super(key: key);

  @override
  _ProcesoInspeccionState createState() => _ProcesoInspeccionState();
}

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

class Operador {
  final int? id;
  final String nombre;

  Operador({
    this.id,
    required this.nombre,
  });

  factory Operador.fromJson(Map<String, dynamic> json) {
    return Operador(
      id: json['id'] as int?,
      nombre: (json['nombre'] as String).trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre': nombre,
    };
  }
}

class _ProcesoInspeccionState extends State<ProcesoInspeccion> {
  int? selectedId;
  bool isLoading = true;
  bool hasError = false;
  bool _isButtonDisabled = false;
  bool _isSending = false; // Para controlar el estado del envío
  List<Maquina> maquinas = [];
  List<Map<String, dynamic>> ordenes = [];
  List<Map<String, dynamic>> openOrdenes = [];

  Color _buttonColor = const Color.fromARGB(235, 209, 4, 4);
  final List<Uint8List> _compressedImages = [];
  final User? user = FirebaseAuth.instance.currentUser;
  String correo = "";
  String usuario = "";
  String fase = "Proceso de Inspeccion";
  final _numSerie = TextEditingController();
  String? _equipos;
  String version = "v11";
  String? _accesorio;
  String? _numRevision;
  String? _responsable;
  String? _problema;
  String? _arearesponsable;
  String? _clasificacionDefecto;
  String? _parteAfectada;
  String? _tipoDefectivo;
  String? _condicionEquipo; // "Nuevo" o "Refurbished"
  // String? _dispositivoDefectivo;
  String? _clasificacionDefectivo;
  final _descripcion = TextEditingController();
  final _desviacion = TextEditingController();
  final _folioDesviacion = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    _fetchMachines();
    _fetchOperadores();
    fetchOrdenes();

    print('🚀 ProcesoInspeccion initialized for ${widget.tecnicoEmail}');
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_compressedImages.length >= 20) {
      Flushbar(
        message: 'No se pueden enviar más de 20 imágenes.',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(20),
        flushbarPosition: FlushbarPosition.TOP,
        dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      ).show(context);
      return;
    }

    final pickedImage = await ImagePicker().pickImage(source: source);
    if (pickedImage == null) return;

    File imageFile = File(pickedImage.path);
    Uint8List? compressedImage = await _compressImage(imageFile);

    if (compressedImage != null) {
      setState(() {
        if (_compressedImages.length < 20) {
          _compressedImages.add(compressedImage);
        }
      });
    }
  }

  Future<void> _fetchMachines() async {
    try {
      final response = await http.get(
        Uri.parse('https://desarrollotecnologicoar.com/api2/maquinas/'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _maquinasList =
              data.map<String>((item) => item['maquina'].toString()).toList();
          _isLoadingMachines = false;
        });
      } else {
        setState(() {
          _isLoadingMachines = false;
        });
        throw Exception('Failed to load machines');
      }
    } catch (e) {
      setState(() {
        _isLoadingMachines = false;
      });
      print('Error fetching machines: $e');
      // Optionally show an error message to the user
      Flushbar(
        message: 'Error al cargar las máquinas. Intente nuevamente.',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ).show(context);
    }
  }

  Future<void> _fetchOperadores() async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://desarrollotecnologicoar.com/api2/operadores_logistica/'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _operadoresList =
              data.map<String>((item) => item['nombre'].toString()).toList();
          _isLoadingOperadores = false;
        });
      } else {
        setState(() {
          _isLoadingOperadores = false;
        });
        throw Exception('Failed to load machines');
      }
    } catch (e) {
      setState(() {
        _isLoadingMachines = false;
      });
      print('Error fetching machines: $e');
      // Optionally show an error message to the user
      Flushbar(
        message: 'Error al cargar las máquinas. Intente nuevamente.',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ).show(context);
    }
  }

  Future<void> _pickImages() async {
    if (_compressedImages.length >= 20) {
      Flushbar(
        message: 'No se pueden enviar más de 20 imágenes.',
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(20),
        flushbarPosition: FlushbarPosition.TOP,
        dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      ).show(context);
      return;
    }

    List<XFile>? pickedImages = await ImagePicker().pickMultiImage();

    if (pickedImages != null && pickedImages.isNotEmpty) {
      int remainingSlots = 20 - _compressedImages.length;

      for (var i = 0; i < pickedImages.length && i < remainingSlots; i++) {
        File imageFile = File(pickedImages[i].path);
        Uint8List? compressedImage = await _compressImage(imageFile);

        if (compressedImage != null) {
          setState(() {
            _compressedImages.add(compressedImage);
          });
        }
      }
    }
  }

  Future<Uint8List?> _compressImage(File imageFile) async {
    List<int> imageBytes = await imageFile.readAsBytes();

    List<int> compressedBytes = await FlutterImageCompress.compressWithList(
      Uint8List.fromList(imageBytes),
      minHeight: 800,
      minWidth: 800,
      quality: 30,
    );

    return Uint8List.fromList(compressedBytes);
  }

  void _removeImage(int index) {
    setState(() {
      _compressedImages.removeAt(index);
    });
  }

  Future<String> _convertImageToBase64(Uint8List imageBytes) async {
    String base64Image = base64Encode(imageBytes);
    return base64Image;
  }

  void resetFields() {
    setState(() {
      _compressedImages.clear();
      _descripcion.clear();
      _desviacion.clear();
      _parteAfectada = null;
      // _problema = null;
      _arearesponsable = null;
      // _clasificacionDefecto = null;
      // _tipoDefectivo = null;
      // _dispositivoDefectivo = null;
      _clasificacionDefectivo = null;
      _descripcion.clear();
      _folioDesviacion.clear();
    });
  }

  Future<void> _enviarDatos() async {
    if (!_formKey.currentState!.validate() || _isButtonDisabled || _isSending) {
      return;
    }

    setState(() {
      _isButtonDisabled = true;
      _isSending = true; // Cambia el estado del envío
      _buttonColor = const Color.fromARGB(204, 175, 76, 76);
    });

    final numSerie = _numSerie.text;
    final descripcion = _descripcion.text;
    final desviacion = _desviacion.text;
    final folioDesviacion = _folioDesviacion.text;
    List<String> base64Images = [];

    for (var imageBytes in _compressedImages) {
      String base64Image = await _convertImageToBase64(imageBytes);
      base64Images.add(base64Image);
    }

    var data = {
      'fase': fase,
      'version': version,
      'correo': correo,
      'usuario': usuario,
      'numSerie': numSerie,
      'equipos': _equipos,
      'accesorio': _accesorio,
      'descripcion': descripcion,
      'numRevision': _numRevision,
      'responsable': _responsable,
      'problema': _problema,
      'arearesponsable': _arearesponsable,
      'clasificacionDefecto': _clasificacionDefecto,
      'parteAfectada': _parteAfectada,
      'tipoDefectivo': _tipoDefectivo,
      'clasificacionDefectivo': _clasificacionDefectivo,
      'desviacion': desviacion,
      'folioDesviacion': folioDesviacion,
      'condicionEquipo': _condicionEquipo,
      'imagenes': base64Images, // Agregar las imágenes en formato base64
    };
    print("Datos a enviar: $data");
    Flushbar(
      message: 'Enviando',
      backgroundColor: const Color.fromARGB(255, 59, 199, 255),
      duration: const Duration(seconds: 17),
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(10),
      flushbarPosition: FlushbarPosition.BOTTOM,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    ).show(context);
    var response = await http.post(
      Uri.parse(
          'https://script.google.com/macros/s/AKfycbxCFuQiO6sLdZQDFQ366MSnwbWHZ6SceTtpS9Q2kVZtRcWvKcvFLTtz94bREft7nhCO/exec'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(data),
    );
    print('Response status: ${response.statusCode}');
    resetFields();
    Flushbar(
      message: 'Enviado Correctamente ',
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 5),
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(10),
      flushbarPosition: FlushbarPosition.TOP,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    ).show(context);

    setState(() {
      _isButtonDisabled = false;
      _isSending = false; // Restaura el estado del envío
      _buttonColor = const Color.fromARGB(
          235, 209, 4, 4); // Restaura el color original del botón
    });
  }

  void _showImageDialog(Uint8List imageBytes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Image.memory(imageBytes),
          ),
        );
      },
    );
  }

  Future<void> fetchOrdenes() async {
    
    final String url =
        'https://desarrollotecnologicoar.com/api10/quality/inspection/orders?email=${widget.tecnicoEmail}';

    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      print("🔄 Fetching órdenes from: $url");
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        // final filteredData =
        //     data.where((orden) => orden['status'] == 'OPEN').toList();
        setState(() {
          ordenes = data
              .map<Map<String, dynamic>>((orden) => {
                    'id': orden['id'],
                    'id_real': orden['id'],
                    'titulo': orden["titulo"] ?? 'Título no disponible',
                    'status': orden['status'], // ✅ importante
                    'assigned_tech_email': orden['assigned_tech_email'],
                    'inspection_type': orden['inspection_type'],
                  })
              .toList();

          openOrdenes = ordenes.where((orden) => orden['status'] == 'OPEN' || orden['status'] == 'PENDING' || orden['status'] == 'IN_PROGRESS').toList();
          if (openOrdenes.isNotEmpty) selectedId = openOrdenes.first['id'];

          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  Future<bool> _verificarAsignacionYContinuar(
      Map<String, dynamic> orden) async {
    final String? assigned = orden['assigned_tech_email'];
    final String userEmail = widget.tecnicoEmail;

    // Caso 1: Ya está asignada al usuario
    if (assigned == userEmail) {
      return true; // permitir continuar
    }

    // Caso 2: Está asignada a otro técnico
    if (assigned != null && assigned != userEmail && assigned.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Esta inspección ya fue asignada a $assigned'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    // Caso 3: assigned == null
    // Preguntar si quiere asignarse
    final confirmar = await _mostrarDialogoAsignacion();

    if (!confirmar) return false;

    // Ejecutar PUT para asignar
    final ok = await _asignarOrden(orden['id'], userEmail);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo asignar la inspección.'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    // Asignación exitosa
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Orden asignada correctamente.'),
        backgroundColor: Colors.green,
      ),
    );

    return true;
  }

  Future<bool> _mostrarDialogoAsignacion() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Asignar inspección"),
        content: const Text(
            "Esta orden no tiene técnico asignado.\n¿Desea asignarse esta inspección?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.grey,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sí, asignarme"),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color.fromARGB(255, 18, 156, 0),
            ),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<bool> _asignarOrden(int inspectionOrderId, String email) async {
    try {
      final url = Uri.parse(
          'https://desarrollotecnologicoar.com/api10/quality/inspection/orders/$inspectionOrderId/assign');

      final req = await HttpClient().putUrl(url)
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({"email": email}));

      final res = await req.close();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se te ha asignado la orden #$inspectionOrderId'),
          backgroundColor: const Color.fromARGB(255, 0, 155, 8),
        ),
      );

      return res.statusCode == 200;
    } catch (e) {
      print("❌ Error asignando orden: $e");
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    correo = user?.email ?? ' ';
    usuario = user?.displayName ?? ' ';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(22, 23, 24, 0.8),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              Container(
                color: Colors.white,
                child: Image.asset(
                  'lib/images/ar_inicio.png',
                  height: 44,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Proceso de inspeccion',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        // Llama a la función para refrescar los datos
        onRefresh: fetchOrdenes,
        child: Stack(
          children: [
            // Fondo degradado
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromARGB(255, 136, 135, 135),
                    Color.fromARGB(255, 255, 255, 255)
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Si estamos cargando, muestra un CircularProgressIndicator en el centro
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            // Si hubo error, muestra el mensaje de error
            else if (hasError)
              const Center(
                child: Text(
                  'Error al cargar las órdenes. Intente nuevamente.',
                  style: TextStyle(
                      fontSize: 16, color: Color.fromARGB(255, 0, 0, 0)),
                ),
              )
            else
              // AQUÍ VIENE LO IMPORTANTE: Usamos ListView siempre,
              // aun si la lista está vacía, para que funcione el "pull-to-refresh"
              ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Título
                  const SizedBox(height: 20),
                  const Text(
                    'Selecciona una orden para inspeccionar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Verificamos si la lista está vacía
                  if (openOrdenes.isEmpty) ...[
                    const Center(
                      child: Text(
                        'No hay órdenes asignadas.',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ] else ...[
                    // Contenedor principal (Card) con Dropdown
                    Card(
                      color: Colors.white,
                      elevation: 20,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Selecciona una orden para cargar el proceso de inspección:',
                              style: TextStyle(fontSize: 18),
                            ),
                            const SizedBox(height: 20),

                            // Dropdown para elegir la orden
                            DropdownButton<int>(
                              value: selectedId,
                              isExpanded: true,
                              items: openOrdenes.map((orden) {
                                final String titulo =
                                    orden['titulo']?.toString() ?? '';
                                final String tipo = orden['inspection_type']?.toString().toLowerCase() ?? '';
                                final String tipoTexto = tipo.contains('pintura')
                                  ? 'Pintura'
                                  : 'Ensamble';
                                final String text = '#: ${orden['id']} - '
                                  '${titulo.isEmpty ? "Orden no.${orden['id']}" : titulo} - '
                                  '$tipoTexto';
                                return DropdownMenuItem<int>(
                                  value: orden['id'],
                                  child: Text(
                                    text,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                                })
                                .toList()
                                ..sort((a, b) {
                                final ordenA = openOrdenes.firstWhere((orden) => orden['id'] == a.value, orElse: () => {});
                                final ordenB = openOrdenes.firstWhere((orden) => orden['id'] == b.value, orElse: () => {});
                                final fechaA = DateTime.tryParse(ordenA['created_at'] ?? '') ?? DateTime(1970);
                                final fechaB = DateTime.tryParse(ordenB['created_at'] ?? '') ?? DateTime(1970);
                                return fechaB.compareTo(fechaA); // Más recientes primero
                                }),
                              onChanged: (int? value) {
                                setState(() {
                                  selectedId = value;
                                });
                              },
                            ),
                            const SizedBox(height: 20),

                            // Botón para navegar a la siguiente pantalla
                            ElevatedButton(
                              onPressed: selectedId != null
                                  ? () async {
                                      // 1) Buscar la orden seleccionada
                                      final ordenSeleccionada =
                                          ordenes.firstWhere(
                                        (orden) =>
                                            orden['id'].toString() ==
                                            selectedId.toString(),
                                        orElse: () => {},
                                      );

                                      if (ordenSeleccionada.isEmpty) {
                                        print(
                                            "❌ No se encontró la orden seleccionada.");
                                        return;
                                      }

                                      print(
                                          "🔎 Orden seleccionada: $ordenSeleccionada");

                                      // 2) Verificar y/o asignar la orden antes de continuar
                                      final puedeContinuar =
                                          await _verificarAsignacionYContinuar(
                                              ordenSeleccionada);

                                      if (!puedeContinuar) {
                                        print(
                                            "⛔ No se puede continuar. La orden no está asignada.");
                                        return;
                                      }

                                      // 3) Si sí puede continuar, abrimos la pantalla de inspección
                                      final idReal = ordenSeleccionada['id'];
                                      print({'id_real': idReal, 'id_tabla': idReal});
                                      Navigator.of(context).pushNamed(
                                        '/actividadesInspeccion',
                                        arguments: {
                                          'id_tabla': idReal,
                                          'id_real':idReal, // si necesitas ambos
                                        },
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color.fromRGBO(22, 23, 24, 0.8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Ir a Orden de Inspección',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Algo de espacio final
                  const SizedBox(height: 30),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
