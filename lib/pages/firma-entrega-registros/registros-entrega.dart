// ignore_for_file: file_names

import 'package:sistema_rastreabilidad/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class Registroentregas extends StatefulWidget {
  const Registroentregas({Key? key}) : super(key: key);

  @override
  State<Registroentregas> createState() => _RegistroentregasState();
}

class _RegistroentregasState extends State<Registroentregas> {
  final User? user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> datos = [];
  List<Map<String, dynamic>> filteredDatos = [];
  bool isLoading = true;
  String correo = "";

  @override
  void initState() {
    super.initState();
    fetchDataFromSheet();
  }

  Future<void> fetchDataFromSheet() async {
    const url =
        'https://script.google.com/macros/s/AKfycbxFv3CcLdx0KNeRu7MbJmTqTGW89--jwFHdq11ytBr9Hodr8BRSMEf6kyCI7og2gCod7g/exec';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body);
      setState(() {
        datos = List<Map<String, dynamic>>.from(jsonData)
            .where((registro) => registro['CORREO'] == correo)
            .toList();
        datos.sort((a, b) {
          // Ordena los datos por la fecha en orden descendente
          final DateTime dateA = DateTime.parse(a['FECHA'] ?? '');
          final DateTime dateB = DateTime.parse(b['FECHA'] ?? '');
          return dateB.compareTo(dateA);
        });

        datos.sort((c, d) {
          // Ordena los datos por la hora en orden descendente
          final DateTime dateC = DateTime.parse(c['HORA'] ?? '');
          final DateTime dateD = DateTime.parse(d['HORA'] ?? '');
          return dateD.compareTo(dateC);
        });

        filteredDatos = datos;
        isLoading = false;
      });
    } else {
      throw Exception('Error fetching sheet data: ${response.statusCode}');
    }
  }

  String formatDateTime(String dateTimeString) {
    // ignore: unnecessary_null_comparison
    if (dateTimeString == null) return '';

    final dateTime = DateTime.parse(dateTimeString);
    final localDateTime = dateTime.toLocal();

    final adjustedDateTime =
        localDateTime.subtract(const Duration(minutes: 36, seconds: 36));

    final formattedTime = DateFormat('hh:mm:ss a').format(adjustedDateTime);

    return formattedTime;
  }

  void main() {
    initializeDateFormatting().then((_) {
      runApp(const MyApp());
    });
  }

  void filterPedidos(String query) {
    setState(() {
      if (query.isNotEmpty) {
        filteredDatos = datos
            .where((pedido) => pedido['PEDIDO']!.toString().contains(query))
            .toList();
      } else {
        filteredDatos = datos;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    correo = user?.email ?? ' ';
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
              const Text('entregas'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) => filterPedidos(value),
              decoration: InputDecoration(
                labelText: 'Buscar pedidos',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredDatos.isNotEmpty
                    ? ListView.builder(
                        itemCount: filteredDatos.length,
                        itemBuilder: (context, index) {
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ExpansionTile(
                              title: Text(
                                filteredDatos[index]['USUARIO'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              subtitle: Text(
                                'Pedido: ${filteredDatos[index]['PEDIDO'] ?? ''}',
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                              children: [
                                ListTile(
                                  title: Text(
                                    'Correo: ${filteredDatos[index]['CORREO'] ?? ''}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fecha: ${DateFormat('yyyy-MM-dd').format(DateTime.parse(filteredDatos[index]['FECHA'] ?? ''))}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        'Hora: ${formatDateTime(filteredDatos[index]['HORA'])}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      // Text(
                                      //   'Observaciones: ${filteredDatos[index]['OBSERVACIONES'] ?? 'Ninguna'}',
                                      //   style: const TextStyle(
                                      //     fontSize: 14,
                                      //   ),
                                      // ),
                                      // const SizedBox(height: 7),
                                      // Text(
                                      //   'Lugar donde se instalara: ${filteredDatos[index]['Lugar donde se instalara'] ?? ''}',
                                      //   style: const TextStyle(
                                      //     fontSize: 14,
                                      //   ),
                                      // ),
                                      // const SizedBox(height: 7),
                                      Text.rich(
                                        TextSpan(
                                          children: [
                                            const WidgetSpan(
                                              child: Icon(
                                                Icons.check_circle,
                                                size: 14, // Tamaño del icono
                                              ),
                                              baseline:
                                                  TextBaseline.ideographic,
                                              alignment:
                                                  PlaceholderAlignment.middle,
                                            ),
                                            TextSpan(
                                              text:
                                                  'Img Subidas: ${filteredDatos[index]['Cant.img.guardadas'] ?? 'Ninguna'}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                // Row(
                                //   children: [
                                //     Expanded(
                                //       child: ListTile(
                                //         leading: const Icon(Icons.check_circle),
                                //         title: Text(
                                //           'Img Subidas: ${filteredDatos[index]['Cant.img.guardadas'] ?? 'Ninguna'}',
                                //           style: const TextStyle(fontSize: 14),
                                //         ),
                                //       ),
                                //     ),
                                //   ],
                                // ),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Text(
                          'No se encontró el pedido',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
