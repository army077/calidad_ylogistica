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

List<String> _maquinasList = [];
bool _isLoadingMachines = true;

List<String> _operadoresList = [];
bool _isLoadingOperadores = true;

class ProcesoInspeccion extends StatefulWidget {
  const ProcesoInspeccion({Key? key}) : super(key: key);

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
  bool _isButtonDisabled = false;
  bool _isSending = false; // Para controlar el estado del envío
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
                  'Procesos de inspeccion',
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
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 10),
                TextFormField(
                  controller: _numSerie,
                  decoration: InputDecoration(
                    labelText: 'Número de serie',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese el número de serie';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _isLoadingMachines
                          ? const Center(child: CircularProgressIndicator())
                          : DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                labelText: 'Equipo afectado',
                                labelStyle: GoogleFonts.roboto(fontSize: 15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              value: _equipos,
                              isExpanded: true,
                              items: _maquinasList
                                  .map<DropdownMenuItem<String>>(
                                      (String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Tooltip(
                                    message: value,
                                    child: Text(value,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _equipos = newValue;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Por favor seleccione un equipo afectado';
                                }
                                return null;
                              },
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Accesorio',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _accesorio,
                  items: <String>[
                    'Rotativo',
                    'Sistema de lubricacion',
                    'Doble tubo',
                    'Doble bomba',
                    'Doble cabezal',
                    'Rodillos',
                    'N/A'
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _accesorio = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione el accesorio';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Numero de revisión',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _numRevision,
                  items: <String>['1', '2', '3', '4', '5']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _numRevision = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione el numero de revisión';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                _isLoadingOperadores
                    ? Center(child: CircularProgressIndicator())
                    : DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Responsable',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        value: _responsable,
                        isExpanded: true,
                        items: _operadoresList.map((nombre) {
                          return DropdownMenuItem<String>(
                            value: nombre,
                            child:
                                Text(nombre, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _responsable = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor seleccione un responsable';
                          }
                          return null;
                        },
                      ),

                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Parte afectada',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _parteAfectada,
                  items: <String>[
                    'Área de trabajo',
                    'Equipo parte laterales',
                    'Equipo parte frontal',
                    'Gabinete de la mesa',
                    'Gabinete',
                    'Puente y brazos',
                    'Cabezal',
                    'Colector de polvo',
                    'Extractor de emisiones',
                    'Bomba de vacío',
                    'Chiller',
                    'Generador plasma',
                    'Pedestal',
                    'Cadena de Y y base',
                    'Alimentador de aporte',
                    'Patas y Ruedas',
                    'Rodillos',
                    'Funcionalidad',
                    'Lentes, ventanas o herramentales',
                    'Pistola',
                    'Equipo parte trasera',
                    'Controlador',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _parteAfectada = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione la parte afectada';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Area responsable',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _arearesponsable,
                  items: <String>[
                    'PRODUCCIÓN',
                    'CALIDAD',
                    'ALMACÉN',
                    'LOGÍSTICA',
                    'SOPORTE TÉCNICO',
                    'CLIENTE',
                    'PROVEEDOR',
                    'SUB ENSAMBLE',
                    'LOG/INTERNA',
                    'PLANEACIÓN',
                    'NPI',
                    'N/A',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _arearesponsable = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione la causa raiz del problema';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '¿Cuál fue la causa raíz del problema?',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _problema,
                  items: <String>[
                    'Maquina o equipo (Proveedor)',
                    'Operador en entrenamiento',
                    'Operador mal capacitado',
                    'Operador negligente',
                    'Desviación del proceso Autorizada',
                    'Mal resguardo',
                    'Mala manipulación de traslado'
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _problema = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione la causa raiz del problema';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Clasificación del defecto/incidente',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _clasificacionDefecto,
                  items: <String>['Crítico', 'Mayor', 'Menor']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _clasificacionDefecto = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione la clasificacion del defecto';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Tipo de defectivo',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _tipoDefectivo,
                  items: <String>['Funcional', 'Estético', 'Configuración']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _tipoDefectivo = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione el tipo de defectivo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                // DropdownButtonFormField<String>(
                //   decoration: InputDecoration(
                //     labelText: '¿Disposición del defectivo?',
                //     labelStyle: GoogleFonts.roboto(fontSize: 15),
                //     border: OutlineInputBorder(
                //       borderRadius: BorderRadius.circular(10),
                //     ),
                //   ),
                //   value: _dispositivoDefectivo,
                //   items: <String>[
                //     'Retrabajo',
                //     'Calibración',
                //     'Ajuste',
                //     'Limpieza',
                //     'Aplicación de pintura',
                //     'Canibaleo',
                //     'Reemplazo',
                //     'Colocar pieza',
                //     'Configurar',
                //     'Otro (Poner en descripcion)'
                //   ].map<DropdownMenuItem<String>>((String value) {
                //     return DropdownMenuItem<String>(
                //       value: value,
                //       child: Text(value),
                //     );
                //   }).toList(),
                //   onChanged: (String? newValue) {
                //     setState(() {
                //       _dispositivoDefectivo = newValue;
                //     });
                //   },
                //   validator: (value) {
                //     if (value == null || value.isEmpty) {
                //       return 'Por favor seleccione el disposición del defectivo';
                //     }
                //     return null;
                //   },
                // ),
                // const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Clasificacion de defectivo',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                  value: _clasificacionDefectivo,
                  items: <String>[
                    "Mala Instalación, error en el armado de piezas",
                    "Falta de componente",
                    "Limpieza deficiente",
                    "Equipo mal configurado o parametrizado",
                    "Tornillería mal ajustada",
                    "Mala aplicación de pintura cara B",
                    "Equipo con daños en zona A",
                    "Componente dañado",
                    "Equipo con daños en zona B",
                    "Mala aplicación de pintura cara A",
                    "Defecto de proveedor",
                    "Componente fuera de especificación",
                    "Equipo con daños en zona C",
                    "Conexiones eléctricas mal ajustadas",
                    "Mal surtido de almacén",
                    "Liberación sin pruebas de calidad",
                    "Mala aplicación de pintura cara C",
                    "Mal nivelado o escuadrado",
                    "Piezas Oxidadas",
                    "Mal etiquetado",
                    "Conexiones neumáticas mal ajustadas",
                    "Envio de equipo o refacción equivocada",
                    "Diseño de proveedor",
                    "Canibaleo interno",
                    "Manguera dañada",
                    "Transmisión con falla",
                    "Daño postventa",
                    "Error de conectividad a la red (Wi-Fi o Red)",
                    "Pulsos",
                    "Deficiencia del grabado",
                    "Amperaje fuera de rango",
                    "Deficiencia del corte",
                    "Mesa descuadrado",
                    "Compresor dañado o fuera de espec",
                    "Ventilador dañado o con mal funcionamiento",
                    "Requerimiento extraordinario del cliente",
                    "Baleros dañados",
                    "Error en base de mesa",
                    "Paro de emergencia dañado",
                    "Puerto USB dañado o con mal funcionamiento",
                    "Scan",
                    "Sensor dañado",
                    "Tubo laser dañado",
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _clasificacionDefectivo = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione la clasificacion de defectivo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                    controller: _descripcion,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Por favor ingrese la descripción';
                      }
                      return null;
                    }),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _desviacion,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Desviacion',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _folioDesviacion,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Folio Desviacion',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics:
                      const NeverScrollableScrollPhysics(), // Deshabilita el scroll del GridView
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: _compressedImages.length,
                  itemBuilder: (context, index) {
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () {
                            _showImageDialog(_compressedImages[index]);
                          },
                          child: Image.memory(_compressedImages[index]),
                        ),
                        Positioned(
                          top: -10,
                          right: 24,
                          child: IconButton(
                            onPressed: () {
                              _removeImage(index);
                            },
                            icon: const Icon(Icons.delete,
                                color: Color.fromARGB(255, 128, 10, 2)),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 10),
                FormField<String>(
                  initialValue: _condicionEquipo,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor selecciona la condición';
                    }
                    return null;
                  },
                  builder: (FormFieldState<String> field) {
                    return InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Condición del equipo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        errorText: field.errorText, // ¡aquí aparece el mensaje!
                      ),
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            title: const Text('Nuevo'),
                            value: 'Nuevo',
                            groupValue: field.value,
                            onChanged: (value) {
                              field.didChange(value);
                              setState(() => _condicionEquipo = value);
                            },
                          ),
                          RadioListTile<String>(
                            title: const Text('Refurbished'),
                            value: 'Refurbished',
                            groupValue: field.value,
                            onChanged: (value) {
                              field.didChange(value);
                              setState(() => _condicionEquipo = value);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // ElevatedButton(
                    //   onPressed: () => _pickImage(ImageSource.gallery),
                    //   style: ElevatedButton.styleFrom(
                    //     backgroundColor: const Color.fromRGBO(
                    //         22, 23, 24, 0.8), // Color de fondo del botón
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius:
                    //           BorderRadius.circular(20), // Bordes redondeados
                    //     ),
                    //     padding: const EdgeInsets.symmetric(
                    //         horizontal: 20, vertical: 10), // Espaciado interno
                    //     elevation: 15, // Elevación para un efecto de sombra
                    //   ),
                    //   child: const Text(
                    //     'Galería',
                    //     style: TextStyle(
                    //       color: Colors.white,
                    //       fontSize: 16,
                    //       fontWeight: FontWeight.bold,
                    //     ),
                    //   ),
                    // ),
                    ElevatedButton(
                      onPressed: _pickImages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(22, 23, 24, 0.8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        elevation: 15,
                      ),
                      child: const Text(
                        'Galería',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _pickImage(ImageSource.camera),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(
                            22, 23, 24, 0.8), // Color de fondo del botón
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(20), // Bordes redondeados
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10), // Espaciado interno
                        elevation: 15, // Elevación para un efecto de sombra
                      ),
                      child: const Text(
                        'Cámara',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: _enviarDatos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isSending ? Colors.grey : _buttonColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10),
                        elevation: 15,
                      ),
                      child: const Text(
                        'Enviar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
