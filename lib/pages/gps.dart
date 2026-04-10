// // ignore_for_file: use_build_context_synchronously

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:location/location.dart';

// class OpenStreetMapPage extends StatefulWidget {
//   final Function(String)? onDistanceChanged;

//   const OpenStreetMapPage({super.key, this.onDistanceChanged});

//   @override
//   State<OpenStreetMapPage> createState() => _OpenStreetMapPageState();
// }

// class _OpenStreetMapPageState extends State<OpenStreetMapPage> {
//   final Location locationController = Location();
//   final TextEditingController pedidoController = TextEditingController();
//   final TextEditingController clienteController = TextEditingController();
//   final TextEditingController destinationController = TextEditingController();

//   LatLng? currentPosition;
//   List<LatLng> polylineCoordinates = [];
//   final MapController mapController = MapController();
//   List<Marker> markers = [];
//   List<PedidoData> pedidos = [];

//   String? distance;
//   String? duration;

//   bool isLoading = false;
//   bool primeraVez = true;

//   StreamSubscription<LocationData>? locationSubscription;

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       await initializeMap();
//     });
//   }

//   @override
//   void dispose() {
//     locationSubscription?.cancel();
//     pedidoController.dispose();
//     clienteController.dispose();
//     destinationController.dispose();
//     super.dispose();
//   }

//   Future<void> initializeMap() async {
//     await fetchLocationUpdates();
//   }

//   Future<void> fetchLocationUpdates() async {
//     bool serviceEnabled;
//     PermissionStatus permissionGranted;

//     serviceEnabled = await locationController.serviceEnabled();
//     if (!serviceEnabled) {
//       serviceEnabled = await locationController.requestService();
//       if (!serviceEnabled) return;
//     }

//     permissionGranted = await locationController.hasPermission();
//     if (permissionGranted == PermissionStatus.denied) {
//       permissionGranted = await locationController.requestPermission();
//       if (permissionGranted != PermissionStatus.granted) {
//         return;
//       }
//     }

//     locationSubscription =
//         locationController.onLocationChanged.listen((currentLocation) {
//       if (currentLocation.latitude != null &&
//           currentLocation.longitude != null) {
//         setState(() {
//           currentPosition = LatLng(
//             currentLocation.latitude!,
//             currentLocation.longitude!,
//           );

//           if (primeraVez) {
//             markers.add(
//               Marker(
//                 point: currentPosition!,
//                 width: 40,
//                 height: 40,
//                 builder: (ctx) => const Icon(
//                   Icons.location_on,
//                   color: Colors.blue,
//                   size: 40.0,
//                 ),
//               ),
//             );
//             primeraVez = false;
//           }
//         });
//       }
//     });
//   }

//   void resetMap() {
//     setState(() {
//       primeraVez = true;
//       distance = null;
//       markers.clear();
//       polylineCoordinates.clear();
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Stack(
//         children: [
//           currentPosition == null
//               ? const Center(child: CircularProgressIndicator())
//               : FlutterMap(
//                   mapController: mapController,
//                   options: MapOptions(
//                     center: currentPosition!,
//                     zoom: 15,
//                   ),
//                   children: [
//                     TileLayer(
//                       urlTemplate:
//                           'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//                       subdomains: const ['a', 'b', 'c'],
//                     ),
//                     MarkerLayer(
//                       markers: markers,
//                     ),
//                   ],
//                 ),
//           Positioned(
//             bottom: 11,
//             right: 10,
//             child: ElevatedButton(
//               onPressed: resetMap,
//               style: ButtonStyle(
//                 backgroundColor: WidgetStateProperty.all<Color>(
//                   const Color.fromARGB(255, 17, 151, 62),
//                 ),
//               ),
//               child: const Text(
//                 'Borrar',
//                 style: TextStyle(color: Colors.white),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ✅ CLASE RESTAURADA: `PedidoData`
// class PedidoData {
//   final String pedido;
//   final String cliente;
//   final String maquina;
//   final String destination;
//   final String distance;
//   final String duration;
//   final String city;
//   final String stateProvince;
//   final String idOrdenEntrega;

//   PedidoData({
//     required this.pedido,
//     required this.cliente,
//     required this.maquina,
//     required this.destination,
//     required this.distance,
//     required this.duration,
//     required this.city,
//     required this.stateProvince,
//     required this.idOrdenEntrega,
//   });
// }