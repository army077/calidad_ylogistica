// //pedidos.dart

// // ignore_for_file: use_build_context_synchronously

// import 'dart:convert';

// import 'package:sistema_rastreabilidad/pages/gps.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class OrdenEntregaPage extends StatefulWidget {
//   final List<PedidoData> pedidos;
//   final Function(String) onDistanceChanged;

//   const OrdenEntregaPage(
//       {Key? key, required this.pedidos, required this.onDistanceChanged})
//       : super(key: key);

//   @override
//   _OrdenEntregaPageState createState() => _OrdenEntregaPageState();
// }

// class _OrdenEntregaPageState extends State<OrdenEntregaPage> {
//   late List<bool> _isExpandedList;

//   @override
//   void initState() {
//     super.initState();
//     _isExpandedList = List.filled(widget.pedidos.length, false);
//   }

//   void _toggleExpansion(int index) {
//     setState(() {
//       _isExpandedList[index] = !_isExpandedList[index];
//     });
//   }

//   String _formatDuration(double duration) {
//     if (duration > 60) {
//       int hours = duration ~/ 60;
//       int minutes = (duration % 60).round();
//       return '$hours hrs $minutes min';
//     } else {
//       return '${duration.round()} min';
//     }
//   }

//   void _showFolioDialog() {
//     TextEditingController folioController = TextEditingController();

//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Ingresar Folio de Orden de Entrega'),
//           content: TextField(
//             controller: folioController,
//             decoration:
//                 const InputDecoration(hintText: "Folio de Orden de Entrega"),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: const Text('Cancelar'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//               },
//             ),
//             TextButton(
//               child: const Text('Confirmar'),
//               onPressed: () {
//                 Navigator.of(context).pop();
//                 _showConfirmationDialog(folioController.text);
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   double _safeParseDouble(String? value) {
//     if (value == null || value.isEmpty) {
//       return 0.0;
//     }
//     try {
//       return double.parse(value);
//     } catch (e) {
//       return 0.0;
//     }
//   }

//   void _showConfirmationDialog(folio) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           title: const Text('Confirmación'),
//           content: const Text('Orden de entrega activada satisfactoriamente'),
//           actions: <Widget>[
//             TextButton(
//               child: const Text('OK'),
//               onPressed: () async {
//                 List<Map<String, dynamic>> pedidosData =
//                     widget.pedidos.map((pedido) {
//                   return {
//                     'pedido': pedido.pedido,
//                     'cliente': pedido.cliente,
//                     'maquina': pedido.maquina,
//                     'destino': pedido.destination,
//                     'folio': folio,
//                     'distancia': pedido.distance,
//                     'duracion': pedido.duration,
//                     'ciudad': pedido.city,
//                     'state_province': pedido.stateProvince,
//                     'id_orden_entrega': pedido.idOrdenEntrega,
//                   };
//                 }).toList();

//                 // Convertir pedidosData a JSON y luego imprimir
//                 String pedidosDataJson = jsonEncode(pedidosData);
//                 debugPrint('Datos a enviar: $pedidosDataJson');

//                 final url =
//                     Uri.parse('https://teknia.app/api9/bitacora_logistica');
//                 final response = await http.post(
//                   url,
//                   headers: {
//                     'Content-Type': 'application/json',
//                   },
//                   body: pedidosDataJson,
//                 );

//                 if (response.statusCode == 201) {
//                   final responseData = jsonDecode(response.body);
//                   debugPrint(
//                       'Bitácoras creadas exitosamente: ${responseData['ids']}');
//                 } else {
//                   debugPrint(
//                       'Error al crear las bitácoras: ${response.statusCode}');
//                 }

//                 widget.onDistanceChanged("0"); // Actualiza la distancia
//                 Navigator.of(context)
//                     .pop(); // Cerrar el diálogo de confirmación
//                 Navigator.of(context).pop(); // Volver a la página anterior
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // void _showConfirmationDialog(folio) {
//   //   showDialog(
//   //     context: context,
//   //     builder: (BuildContext context) {
//   //       return AlertDialog(
//   //         title: const Text('Confirmación'),
//   //         content: const Text('Orden de entrega activada satisfactoriamente'),
//   //         actions: <Widget>[
//   //           TextButton(
//   //             child: const Text('OK'),
//   //             onPressed: () {
//   //               for (PedidoData pedido in widget.pedidos) {
//   //                 debugPrint('Pedido: ${pedido.pedido}');
//   //                 debugPrint('Cliente: ${pedido.cliente}');
//   //                 debugPrint('Máquina: ${pedido.maquina}');
//   //                 debugPrint('Destino: ${pedido.destination}');
//   //                 debugPrint('Distancia: ${pedido.distance} km');
//   //                 debugPrint('Duración: ${pedido.duration} min');
//   //                 debugPrint('Ciudad: ${pedido.city}');
//   //                 debugPrint('Estado/Provincia: ${pedido.stateProvince}');
//   //               }
//   //               debugPrint('Folio: $folio');

//   //               widget.onDistanceChanged("0"); // Actualiza la distancia
//   //               Navigator.of(context)
//   //                   .pop(); // Cerrar el diálogo de confirmación
//   //               Navigator.of(context).pop(); // Volver a la página anterior
//   //             },
//   //           ),
//   //         ],
//   //       );
//   //     },
//   //   );
//   // }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: const Color.fromRGBO(22, 23, 24, 0.8),
//         title: ClipRRect(
//           borderRadius: BorderRadius.circular(4),
//           child: Row(
//             children: [
//               Container(
//                 color: Colors.white,
//                 child: Image.asset(
//                   'lib/images/ar_inicio.png',
//                   height: 44,
//                 ),
//               ),
//               const SizedBox(width: 20),
//               const Text(
//                 'Orden de Entrega',
//                 style: TextStyle(
//                   // fontSize: 20,
//                   color: Colors.white,
//                 ),
//               ),
//             ],
//           ),
//         ),
//         // actions: [
//         //   IconButton(
//         //     icon: const Icon(
//         //         Icons.assignment), // Cambia el icono según tu preferencia
//         //     onPressed: () {
//         //       Navigator.push(
//         //         context,
//         //         MaterialPageRoute(
//         //             builder: (context) => const Registroentregas()),
//         //       );
//         //     },
//         //   ),
//         // ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.only(top: 16.0),
//         child: Column(
//           children: [
//             Expanded(
//               child: ListView.builder(
//                 itemCount: widget.pedidos.length,
//                 itemBuilder: (context, index) {
//                   final pedido = widget.pedidos[index];
//                   return Column(
//                     children: [
//                       GestureDetector(
//                         onTap: () => _toggleExpansion(index),
//                         child: ExpansionTile(
//                           title: Row(
//                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                             children: [
//                               Flexible(
//                                 child: Tooltip(
//                                   message: pedido.pedido,
//                                   child: Column(
//                                     children: [
//                                       Row(
//                                         children: [
//                                           Text(
//                                             'Pedido: ${pedido.pedido} - ${pedido.cliente.length > 11 ? '${pedido.cliente.substring(0, 11)} ...' : pedido.cliente}',
//                                           ),
//                                         ],
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                           trailing: Icon(_isExpandedList[index]
//                               ? Icons.expand_less
//                               : Icons.expand_more),
//                           onExpansionChanged: (isExpanded) =>
//                               _toggleExpansion(index),
//                           children: <Widget>[
//                             Padding(
//                               padding: const EdgeInsets.all(16.0),
//                               child: Column(
//                                 children: [
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.start,
//                                     children: [
//                                       Expanded(
//                                         child: Column(
//                                           crossAxisAlignment:
//                                               CrossAxisAlignment.start,
//                                           children: [
//                                             Text(
//                                                 'Destino: ${pedido.destination.toUpperCase()}'),
//                                             Text('Máquina: ${pedido.maquina}'),
//                                             Text(
//                                                 'Distancia Al Punto: ${_safeParseDouble(pedido.distance).toStringAsFixed(2)} km'),
//                                             Text(
//                                                 'Duración Al Punto: ${_formatDuration(double.tryParse(pedido.duration) ?? 0.0)}'),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                   );
//                 },
//               ),
//             ),
//             Padding(
//               padding: const EdgeInsets.all(16.0),
//               child: ElevatedButton(
//                 onPressed: _showFolioDialog,
//                 child: const Text('Confirmar ruta de entrega'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
