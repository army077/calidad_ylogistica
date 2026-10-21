// ignore_for_file: library_private_types_in_public_api, unused_element, unnecessary_null_comparison, use_build_context_synchronously, avoid_print, file_names

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:signature/signature.dart';

import '../services/logistica_delivery_service.dart';
import '../services/logistica_delivery_attempt_store.dart';
import 'firma-entrega-registros/registros-entrega.dart';

class Firmaentregas extends StatefulWidget {
  const Firmaentregas({super.key});

  @override
  _FirmaentregasState createState() => _FirmaentregasState();
}

class _FirmaentregasState extends State<Firmaentregas> {
  final List<Uint8List> _compressedImages = [];
  bool _isButtonDisabled = false;
  bool _isSending = false; // Para controlar el estado del envío
  Color _buttonColor = const Color.fromARGB(235, 209, 4, 4);

  final String version = 'v5';
  bool _isPickingImages = false;
  String _progressText = '';
  DeliveryAttempt? _deliveryAttempt;
  final _attemptStore = LogisticaDeliveryAttemptStore();
  bool _restoringAttempt = true;
  String? _recoveryError;
  String? _attemptUid;
  late final _deliveryService = LogisticaDeliveryService(
    tokenProvider: () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.uid != _attemptUid) {
        throw const DeliveryApiException(
          'La sesión cambió. Inicia sesión con el usuario del intento pendiente.',
          statusCode: 401,
        );
      }
      final token = await user.getIdToken();
      return token;
    },
  );
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

  bool get _editingLocked =>
      _restoringAttempt ||
      _recoveryError != null ||
      _isSending ||
      _isPickingImages ||
      _deliveryAttempt != null;

  Future<void> _pickImage(ImageSource source) => _selectImages(source: source);

  Future<void> _selectImages({
    ImageSource source = ImageSource.gallery,
    bool multiple = false,
  }) async {
    if (_editingLocked) return;
    if (_compressedImages.length >= 15) {
      _showDeliveryError('No se pueden enviar más de 15 imágenes.');
      return;
    }
    setState(() => _isPickingImages = true);
    try {
      final List<XFile> picked;
      if (multiple) {
        picked = await ImagePicker().pickMultiImage();
      } else {
        final image = await ImagePicker().pickImage(source: source);
        picked = image == null ? [] : [image];
      }
      for (final image in picked) {
        if (!mounted || _compressedImages.length >= 15) break;
        final compressed = await _compressImage(File(image.path));
        if (!mounted) return;
        setState(() {
          _compressedImages.add(compressed);
          _imagesAdded = true;
        });
      }
    } on DeliveryApiException catch (error) {
      _showDeliveryError(error.message);
    } catch (_) {
      _showDeliveryError(
          'No se pudo preparar la imagen. Vuelve a seleccionarla.');
    } finally {
      if (mounted) setState(() => _isPickingImages = false);
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
      throw const DeliveryApiException(
        'Activa los servicios de ubicación para enviar la entrega.',
      );
    }

    // Verificar el estado de los permisos de ubicación
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Los permisos de ubicación están denegados, solicítalos al usuario
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Los permisos de ubicación siguen denegados, maneja el caso adecuadamente
        throw const DeliveryApiException(
          'Se necesita permiso de ubicación para enviar la entrega.',
        );
      }
    }

    // Verificar si los permisos de ubicación están permanentemente denegados
    if (permission == LocationPermission.deniedForever) {
      // Los permisos de ubicación están permanentemente denegados, maneja el caso adecuadamente
      throw const DeliveryApiException(
        'Habilita el permiso de ubicación en Ajustes para enviar la entrega.',
      );
    }

    // Obtener la posición actual del dispositivo
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy:
          LocationAccuracy.best, // Otra opción: LocationAccuracy.high
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw const DeliveryApiException(
        'No se pudo obtener GPS a tiempo. Reintenta antes de enviar la entrega.',
      ),
    );

    return position;
  }

  Future<void> _pickImages() => _selectImages(multiple: true);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onSignatureChanged);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _restorePendingAttempt());
  }

  void _applyRecoveredAttempt(DeliveryAttempt attempt) {
    _deliveryAttempt = attempt;
    _pedido.text = attempt.creationPayload['pedido'] as String;
    _descripcion.text = attempt.creationPayload['observaciones'] as String;
    _equipos = attempt.creationPayload['equipos'] as String;
    _chofer = attempt.creationPayload['chofer'] as String;
    _instalara = attempt.creationPayload['instalara'] as String;
    _compressedImages
      ..clear()
      ..addAll(attempt.evidences
          .where((e) => e.type == 'PHOTO')
          .map((e) => e.bytes));
    _imagesAdded = true;
    _signatureAdded = true;
  }

  Future<void> _restorePendingAttempt() async {
    if (_isSending || !mounted) return;
    setState(() => _restoringAttempt = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw const DeliveryAttemptStoreException(
          'Inicia sesión para revisar el intento pendiente antes de enviar.',
        );
      }
      final attempt = await _attemptStore.runExclusive(
        () => _attemptStore.load(
          firebaseUid: uid,
          apiBaseUrl: logisticaApi10BaseUrl,
          cleanupCompleted: true,
        ),
      );
      if (!mounted) return;
      setState(() {
        _recoveryError = null;
        _attemptUid = uid;
        _deliveryAttempt = attempt;
        if (attempt != null) _applyRecoveredAttempt(attempt);
      });
    } on DeliveryAttemptStoreException catch (error) {
      if (mounted) setState(() => _recoveryError = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _recoveryError =
            'No se pudo revisar el pendiente local. Reintenta antes de enviar.');
      }
    } finally {
      if (mounted) setState(() => _restoringAttempt = false);
    }
  }

  void _onSignatureChanged() {
    if (mounted) {
      setState(() => _signatureAdded = _controller.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onSignatureChanged);
    _controller.dispose();
    _descripcion.dispose();
    _pedido.dispose();
    super.dispose();
  }

  Future<Uint8List> _compressImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minHeight: 800,
      minWidth: 800,
      quality: 30,
      format: CompressFormat.jpeg,
    );
    if (compressed.isEmpty || compressed.length > deliveryPhotoMaxBytes) {
      throw const DeliveryApiException(
        'La foto comprimida supera 10 MiB o está vacía. Selecciona otra imagen.',
      );
    }
    return Uint8List.fromList(compressed);
  }

  void _removeImage(int index) {
    if (_editingLocked) return;
    setState(() {
      _compressedImages.removeAt(index);
      _imagesAdded = _hasImages(); // Actualiza _imagesAdded después de eliminar
    });
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
      _deliveryAttempt = null;
      _progressText = '';
      _compressedImages.clear();
      _controller.clear();
      _descripcion.clear();
      _instalara = null;
    });
  }

  void _showDeliveryError(String message) {
    if (!mounted) return;
    Flushbar(
      message: message,
      backgroundColor: Colors.orange,
      duration: const Duration(seconds: 6),
      margin: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(20),
      flushbarPosition: FlushbarPosition.TOP,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
    ).show(context);
  }

  void _setProgress(String message) {
    if (mounted) setState(() => _progressText = message);
  }

  Future<void> _enviarDatos() async {
    if (_isSending ||
        _isButtonDisabled ||
        _isPickingImages ||
        _restoringAttempt) {
      return;
    }
    if (_recoveryError != null) {
      await _restorePendingAttempt();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isButtonDisabled = true;
      _isSending = true;
      _progressText = 'Preparando entrega...';
      _buttonColor = const Color.fromARGB(204, 175, 76, 76);
    });

    try {
      await _attemptStore.runExclusive(() async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null || (_attemptUid != null && uid != _attemptUid)) {
          throw const DeliveryAttemptStoreException(
            'La sesión cambió. Recupera el pendiente con su usuario original; no se borró.',
          );
        }
        _attemptUid = uid;
        if (_deliveryAttempt == null) {
          // Recheck under the shared lock before freezing any new UUID.
          final saved = await _attemptStore.load(
            firebaseUid: uid,
            apiBaseUrl: logisticaApi10BaseUrl,
            cleanupCompleted: true,
          );
          if (!mounted) return;
          if (saved != null) {
            setState(() => _applyRecoveredAttempt(saved));
          }
        }
        if (_deliveryAttempt == null) {
          if (!_formKey.currentState!.validate()) return;
          if (!_hasImages()) {
            _showDeliveryError('Por favor agrega al menos una imagen.');
            return;
          }
          if (!_signatureAdded) {
            _showDeliveryError('Por favor agrega tu firma antes de enviar.');
            return;
          }
          final position = await getPosition();
          if (!mounted) return;
          final signature = await _controller.toPngBytes();
          if (!mounted) return;
          if (signature == null || signature.isEmpty) {
            throw const DeliveryApiException(
              'No se pudo exportar la firma. Vuelve a firmar.',
            );
          }
          _deliveryAttempt = DeliveryAttempt.freeze(
            pedido: _pedido.text,
            equipos: _equipos!,
            chofer: _chofer!,
            observaciones: _descripcion.text,
            instalara: _instalara!,
            latitude: position.latitude,
            longitude: position.longitude,
            appVersion: version,
            photos: _compressedImages,
            signature: signature,
          );
        }

        final attempt = _deliveryAttempt!;
        await _deliveryService.send(
          attempt,
          onProgress: _setProgress,
          persist: (value) => _attemptStore.save(
            value,
            firebaseUid: uid,
            apiBaseUrl: logisticaApi10BaseUrl,
          ),
        );
        if (!attempt.completed) {
          throw const DeliveryApiException(
              'La entrega aún no está finalizada.');
        }
        // COMPLETED has already been persisted. Cleanup also runs if UI was closed.
        await _attemptStore.cleanup(
          firebaseUid: uid,
          apiBaseUrl: logisticaApi10BaseUrl,
          clientRequestId: attempt.clientRequestId,
        );
        if (!mounted) return;
        resetFields();
        await _showConfirmationDialog();
      });
    } on DeliveryAttemptStoreException catch (error) {
      _showDeliveryError(error.message);
    } on DeliveryApiException catch (error) {
      _showDeliveryError(error.message);
    } on FirebaseAuthException {
      _showDeliveryError(
        'No se pudo validar la sesión. Inicia sesión y reintenta el envío.',
      );
    } on TimeoutException {
      _showDeliveryError(
        'No se obtuvo respuesta a tiempo. Reintenta; tus datos se conservaron.',
      );
    } catch (_) {
      _showDeliveryError(
        'No se pudo completar el envío. Tus datos se conservaron para reintentar.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isButtonDisabled = false;
          _isSending = false;
          _buttonColor = const Color.fromARGB(235, 209, 4, 4);
        });
      }
    }
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
                  readOnly: _editingLocked,
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
                        onChanged: _editingLocked
                            ? null
                            : (String? newValue) {
                                if (_editingLocked) return;
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
                  onChanged: _editingLocked
                      ? null
                      : (String? newValue) {
                          if (_editingLocked) return;
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
                  onChanged: _editingLocked
                      ? null
                      : (String? newValue) {
                          if (_editingLocked) return;
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
                  readOnly: _editingLocked,
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
                      onPressed: _editingLocked ? null : _pickImages,
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
                      onPressed: _editingLocked
                          ? null
                          : () => _pickImage(ImageSource.camera),
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
                    child: IgnorePointer(
                      ignoring: _editingLocked,
                      child: _deliveryAttempt != null
                          ? Image.memory(_deliveryAttempt!.evidences.last.bytes,
                              height: 300)
                          : Signature(
                              controller: _controller,
                              height: 300,
                              backgroundColor: const Color.fromARGB(0, 224, 221,
                                  221), // Establece el fondo transparente
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    if (_editingLocked) return;
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
                if (_restoringAttempt)
                  const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Revisando pendiente local...')),
                if (_recoveryError != null)
                  Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(_recoveryError!)),
                if (_isSending)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_progressText),
                  ),
                if (!_isSending && _deliveryAttempt != null)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Envío pendiente: Reintentar envío conserva los mismos datos.',
                    ),
                  ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      // onPressed: _clearImages,
                      onPressed:
                          _restoringAttempt || _isSending || _isPickingImages
                              ? null
                              : _enviarDatos,
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
                      child: Text(
                        _isSending
                            ? 'Enviando...'
                            : _recoveryError != null
                                ? 'Revisar pendiente'
                                : _deliveryAttempt != null
                                    ? 'Reintentar envío'
                                    : 'Enviar',
                        style: const TextStyle(
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
