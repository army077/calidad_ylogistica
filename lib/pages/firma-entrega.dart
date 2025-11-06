// ignore_for_file: library_private_types_in_public_api, unused_element, unnecessary_null_comparison, use_build_context_synchronously, avoid_print, file_names

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';

import 'firma-entrega-registros/registros-entrega.dart';

class Firmaentregas extends StatefulWidget {
  const 
  Firmaentregas({Key? key}) : super(key: key);

  @override
  _FirmaentregasState createState() => _FirmaentregasState();
}

class _FirmaentregasState extends State<Firmaentregas> {
  final List<Uint8List> _compressedImages = [];
  bool _isButtonDisabled = false;
  bool _isSending = false; // Para controlar el estado del envío
  Color _buttonColor = const Color.fromARGB(235, 209, 4, 4);

  final User? user = FirebaseAuth.instance.currentUser;
  String fase = "EntregaEquipos";
  String version = "v5";
  String correo = "";
  String usuario = "";
  String? _equipos;
  String? _chofer;
  String? _instalara;
  // ignore: unused_field
  bool _imagesAdded = false;
  bool _signatureAdded = false;
  final _formKey = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  final _pedido = TextEditingController();
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  Future<void> _pickImage(ImageSource source) async {
    if (_compressedImages.length >= 15) {
      Flushbar(
        message: 'No se pueden enviar más de 15 imágenes.',
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
        if (_compressedImages.length < 15) {
          _compressedImages.add(compressedImage);
          _imagesAdded = true; // Imágenes agregadas
        }
      });
    }
  }

  // Función para obtener la posición del dispositivo
  Future<Position> getPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si los servicios de ubicación están habilitados
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Los servicios de ubicación no están habilitados, maneja el caso adecuadamente
      return Future.error('Los servicios de ubicación están deshabilitados');
    }

    // Verificar el estado de los permisos de ubicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Los permisos de ubicación están denegados, solicítalos al usuario
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Los permisos de ubicación siguen denegados, maneja el caso adecuadamente
        return Future.error('Los permisos de ubicación están denegados');
      }
    }

    // Verificar si los permisos de ubicación están permanentemente denegados
    if (permission == LocationPermission.deniedForever) {
      // Los permisos de ubicación están permanentemente denegados, maneja el caso adecuadamente
      return Future.error(
          'Los permisos de ubicación están permanentemente denegados');
    }

    // Obtener la posición actual del dispositivo
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy:
          LocationAccuracy.best, // Otra opción: LocationAccuracy.high
    );

    return position;
  }

  Future<void> _pickImages() async {
    if (_compressedImages.length >= 15) {
      Flushbar(
        message: 'No se pueden enviar más de 15 imágenes.',
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
      int remainingSlots = 15 - _compressedImages.length;

      for (var i = 0; i < pickedImages.length && i < remainingSlots; i++) {
        File imageFile = File(pickedImages[i].path);
        Uint8List? compressedImage = await _compressImage(imageFile);

        if (compressedImage != null) {
          setState(() {
            _compressedImages.add(compressedImage);
            _imagesAdded = true;
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      setState(() {
        _signatureAdded = _controller.isNotEmpty; // Firma agregada
      });
    });
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
      _imagesAdded = _hasImages(); // Actualiza _imagesAdded después de eliminar
    });
  }

  Future<String> _convertImageToBase64(Uint8List imageBytes) async {
    String base64Image = base64Encode(imageBytes);
    return base64Image;
  }

  Future<void> _showConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible:
          false, // Evita que el usuario cierre el diálogo tocando fuera
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Registro enviado correctamente',
            style: TextStyle(
              color: Colors.green, // Cambia el color del título a verde
            ),
          ),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('¿Qué deseas hacer a continuación?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Ir a mis registros'),
              onPressed: () {
                Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (context) => const Registroentregas(),
                ));
              },
            ),
            TextButton(
              child: const Text('Llenar otra entrega'),
              onPressed: () {
                Navigator.of(context).pop(); // Cierra el diálogo
              },
            ),
          ],
        );
      },
    );
  }

  bool _hasImages() {
    return _compressedImages.isNotEmpty;
  }

  void resetFields() {
    setState(() {
      _compressedImages.clear();
      _controller.clear();
      _descripcion.clear();
      _descripcion.clear();
      _instalara = null;
    });
  }

  Future<void> _enviarDatos() async {
    if (!_formKey.currentState!.validate() || _isButtonDisabled || _isSending) {
      return;
    } else if (!_hasImages()) {
      // Mostrar mensaje porque no se han agregado imágenes
      Flushbar(
        message: 'Por favor agrega al menos una imagen.',
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(20),
        flushbarPosition: FlushbarPosition.TOP,
        dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      ).show(context);
      return;
    } else if (!_signatureAdded) {
      // Mostrar mensaje porque no se ha agregado una firma
      Flushbar(
        message: 'Por favor agrega tu firma antes de enviar.',
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(20),
        flushbarPosition: FlushbarPosition.TOP,
        dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      ).show(context);
      return;
    }

    setState(() {
      _isButtonDisabled = true;
      _isSending = true; // Cambia el estado del envío
      _buttonColor = const Color.fromARGB(204, 175, 76, 76);
    });

    var base64Results = await Future.wait([
      _controller.toPngBytes().then((signature) => base64Encode(signature!)),
    ]);

    List<String> base64Images = [];

    for (var imageBytes in _compressedImages) {
      String base64Image = await _convertImageToBase64(imageBytes);
      base64Images.add(base64Image);
    }
    Position position = await getPosition();
    double latitude = position.latitude;
    double longitude = position.longitude;

    final descripcion = _descripcion.text;
    var data = {
      'fase': fase,
      'signature': base64Results[0],
      'imagenes': base64Images,
      'correo': correo,
      'equipos': _equipos,
      'chofer': _chofer,
      'latitude': latitude,
      'longitude': longitude,
      'instalara': _instalara,
      'version': version,
      'usuario': usuario,
      'pedido': _pedido.text,
      'descripcion': descripcion,
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
    await _showConfirmationDialog();

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
              const Text(
                'Firma-entregas',
                style: TextStyle(
                  // fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
                Icons.assignment), // Cambia el icono según tu preferencia
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const Registroentregas()),
              );
            },
          ),
        ],
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
                  controller: _pedido,
                  decoration: InputDecoration(
                    labelText: 'Pedido',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  keyboardType: TextInputType
                      .number, // Mostrará el teclado numérico en dispositivos móviles
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter
                        .digitsOnly // Permite solo dígitos
                  ],
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese el pedido';
                    }
                    // Puedes agregar más validaciones aquí si es necesario
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Equipo',
                          labelStyle: GoogleFonts.roboto(fontSize: 15),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        value: _equipos,
                        isExpanded: true,
                        items: <String>[
                       "ATC BOSS 1325 (ATC5 1325)",
                        "ATC BOSS 1325 Z300 (ATC5 1325 Z300)",
                        "ATC BOSS 1325R  (ATC5 1325R)",
                        "ATC BOSS X2 1325 TT (ATC5 X2 1325 TT)",
                        "ATC BOSS X2 1325 4 BOMBAS",
                        "LIFTWORX",
                        "CREATOR 0704",
                        "CREATOR X2 1309",
                        "CREATOR 1325",
                        "CREATOR 1409",
                        "CREATOR 1610",
                        "FIBERBLADE X0",
                        "FIBERBLADE X3",
                        "FIBERGRAVER (MFL 220)  50W",
                        "FIBERGRAVER (MFL 220) 30W",
                        "MAKER 0609 NM",
                        "MULTIHEAD 1525",
                        "MULTIHEAD 1325",
                        "PLASMABLADE 1330",
                        "PLASMABLADE 1850",
                        "SAAP 10HP",
                        "SAAP 15HP",
                        "SHOP 1325",
                        "SHOP 1330 PR",
                        "SHOP 1836 PR",
                        "SHOP PRO 1325",
                        "STONE 1325",
                        "WORKS 1325",
                        "WORKS B 1325",
                        "WORKS 1830",
                        "WELDWORX",
                        "WELDWORX NM",
                        "BENDWORX 50T",
                        "BENDWORX 125T",
                        "BENDWORX 160T",
                        "FIBERBLADE X0 NM",
                        "FIBERBLADE X0 R3 NM",
                        "FIBERBLADE X0 R6 NM",
                        "WELDBOT",
                        "LIFTWORX 360",
                        "T6L",
                        "FIBERBLADE X4",
                        "SHOP PRO HQD 1325",
                        "FIB-AIR 20HP",
                        "FIB-AIR 30HP",
                        "ATC BOSS 1325 C",
                        "BENDWORX 63T",
                        "BENDWORX 200T",
                        "FILT-AIR",
                        "TECHSTYLE",
                        "CREATOR 1309",
                        "FIBERGRAVER DT",
                        "MULTIHEAD ADV6",

                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Tooltip(
                              message: value,
                              child:
                                  Text(value, overflow: TextOverflow.ellipsis),
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
                    labelText: 'Chofer',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _chofer,
                  items: <String>[
                    'Octavio Naranjo Salas',
                    'Moisés Moreno Ruelas',
                    'Juan Manuel Oceguera Valadez',
                    'Christian Ramos Hernández',
                    'Arturo Acosta Becerra',
                    'Ricardo Ramirez Garcilazo',
                    'Daniel Eduardo Garcia Blanco',
                    'Fernando Ortíz Ramos',
                    'Otro',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _chofer = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione el cohfer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: '¿El lugar es permanente?',
                    labelStyle: GoogleFonts.roboto(fontSize: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  value: _instalara,
                  items: <String>[
                    'Si',
                    'No',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _instalara = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor seleccione el campo';
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
                    labelText: 'Observaciones',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text: 'IMPORTANTE: ',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.bold, // Texto "Importante" en negrita
                          color: Colors.grey,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      TextSpan(
                        text: 'subir INE, Proforma y Paquete',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
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
                  ],
                ),
                const SizedBox(height: 30),
                Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('lib/images/firma3.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.black,
                        width: 1.0,
                      ),
                    ),
                    child: Signature(
                      controller: _controller,
                      height: 300,
                      backgroundColor: const Color.fromARGB(
                          0, 224, 221, 221), // Establece el fondo transparente
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _controller.clear(); // Restablece la firma
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color.fromRGBO(
                        22, 23, 24, 0.8), // Color del texto
                  ),
                  child: const Text('Limpiar firma'),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      // onPressed: _clearImages,
                      onPressed: _enviarDatos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSending
                            ? Colors.grey
                            : _buttonColor, // Color de fondo del botón
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(20), // Bordes redondeados
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 10), // Espaciado interno
                        elevation: 15, // Elevación para un efecto de sombra
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
