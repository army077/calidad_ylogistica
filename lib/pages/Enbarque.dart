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

class Embarque extends StatefulWidget {
  const Embarque({Key? key}) : super(key: key);

  @override
  _EmbarqueState createState() => _EmbarqueState();
}

class _EmbarqueState extends State<Embarque> {
  bool _isButtonDisabled = false;
  bool _isSending = false; // Para controlar el estado del envío
  Color _buttonColor = const Color.fromARGB(235, 209, 4, 4);
  final List<Uint8List> _compressedImages = [];
  final User? user = FirebaseAuth.instance.currentUser;
  String correo = "";
  String usuario = "";
  String fase = "Embarque";
  String version = "v11";
  final _numSerie = TextEditingController();
  String? _equipos;
  String? _accesorio;
  final _cliente = TextEditingController();
  final _numPedido = TextEditingController();
  final _numSerieAsignado = TextEditingController();
  final _descripcion = TextEditingController();
  final _numSereModulo = TextEditingController();
  final _desviacion = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<String> _maquinasList = [];
  bool _isLoadingMachines = true;

  @override
  void initState() {
    super.initState();
    _fetchMachines();
  }

  Future<void> _fetchMachines() async {
    try {
      final response = await http.get(
        Uri.parse('https://desarrollotecnologicoar.com/api10/machine-models/'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _maquinasList =
              data.map<String>((item) => item['name'].toString()).toList();
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
      _numSereModulo.clear();
      _desviacion.clear();
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
    final numSereModulo = _numSereModulo.text;
    final desviacion = _desviacion.text;

    final numSerieAsignado = _numSerieAsignado.text;
    final numPedido = _numPedido.text;
    final cliente = _cliente.text;
    List<String> base64Images = [];
    for (var imageBytes in _compressedImages) {
      String base64Image = await _convertImageToBase64(imageBytes);
      base64Images.add(base64Image);
    }
    print(fase);
    print(version);
    print(correo);
    print(usuario);
    print(cliente);
    print(numPedido);
    print(numSerieAsignado);
    print(numSerie);
    print(_equipos);
    print(_accesorio);
    print(descripcion);
    print(desviacion);
    var data = {
      'fase': fase,
      'version': version,
      'correo': correo,
      'usuario': usuario,
      'numSerie': numSerie,
      'equipos': _equipos,
      'accesorio': _accesorio,
      'descripcion': descripcion,
      'imagenes': base64Images,
      'desviacion': desviacion,
      'numSerieAsignado': numSerieAsignado,
      'numPedido': numPedido,
      'cliente': cliente,
      'numSereModulo': numSereModulo,
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
              const Text(
                'Pre-Embarque',
                style: TextStyle(
                  // fontSize: 20,
                  color: Colors.white,
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
                  controller: _cliente,
                  decoration: InputDecoration(
                    labelText: 'Cliente',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese el cliente';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _numPedido,
                  decoration: InputDecoration(
                    labelText: 'Número de pedido',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese el número de pedido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _numSerieAsignado,
                  decoration: InputDecoration(
                    labelText: 'Número de serie asignado',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese el número de serie asignado';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _numSerie,
                  decoration: InputDecoration(
                    labelText: 'Número de serie origen',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Por favor ingrese el número de serie origen';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _isLoadingMachines
                          ? const Center(child: CircularProgressIndicator())
                          : Autocomplete<String>(
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return _maquinasList;
                                }
                                return _maquinasList.where((String option) {
                                  return option.toLowerCase().contains(
                                      textEditingValue.text.toLowerCase());
                                });
                              },
                              displayStringForOption: (option) => option,
                              fieldViewBuilder: (context, controller, focusNode,
                                  onFieldSubmitted) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  readOnly: false,
                                  decoration: InputDecoration(
                                    labelText: 'Equipo afectado',
                                    labelStyle:
                                        GoogleFonts.roboto(fontSize: 15),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.arrow_drop_down),
                                      onPressed: focusNode.requestFocus,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Por favor seleccione un equipo afectado';
                                    }
                                    return null;
                                  },
                                );
                              },
                              onSelected: (String selection) {
                                setState(() {
                                  _equipos = selection;
                                });
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 6,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.85,
                                      constraints:
                                          const BoxConstraints(maxHeight: 250),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: options.length,
                                        itemBuilder: (context, index) {
                                          final option =
                                              options.elementAt(index);
                                          return InkWell(
                                            onTap: () => onSelected(option),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12),
                                              child: Text(
                                                option,
                                                style: const TextStyle(
                                                    fontSize: 15),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                              initialValue:
                                  TextEditingValue(text: _equipos ?? ''),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
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
                const SizedBox(height: 20),
                TextFormField(
                  controller: _descripcion,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Comentarios',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _numSereModulo,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Número de serie de Modulo o Generador',
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
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _pickImages,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromRGBO(22, 23, 24, 0.8),
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
                          backgroundColor:
                              const Color.fromRGBO(22, 23, 24, 0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          elevation: 15,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
