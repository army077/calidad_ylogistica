import 'package:sistema_rastreabilidad/auth_page.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/procesoInspeccion.dart';
import 'pages/actividadesInspeccion.dart';

Future<void> subscribeToOperadoresTopic() async {
  await FirebaseMessaging.instance.subscribeToTopic('operadores');
  print('✅ Suscrito al topic operadores');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  await subscribeToOperadoresTopic();

  // 🔄 Inicializar listeners de token
  _listenToTokenRefresh();

  runApp(const MyApp());
}

/// 🔹 Actualiza el token actual en Firestore
Future<void> _updateToken() async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    final user = FirebaseAuth.instance.currentUser;

    if (user != null && token != null) {
      await FirebaseFirestore.instance
          .collection('operadoresTokens')
          .doc(user.uid)
          .set({
        'email': user.email,
        'fcmTokens': FieldValue.arrayUnion([token]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint("✅ Token actualizado manualmente: $token");
    }
  } catch (e) {
    debugPrint("❌ Error en _updateToken: $e");
  }
}

/// 🔹 Escucha cambios del token FCM y los sincroniza
void _listenToTokenRefresh() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('operadoresTokens')
            .doc(user.uid)
            .set({
          'email': user.email,
          'fcmTokens': FieldValue.arrayUnion([newToken]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        debugPrint("🔄 Token refrescado y guardado: $newToken");
      }
    } catch (e) {
      debugPrint("❌ Error guardando token refrescado: $e");
    }
  }).onError((error) {
    debugPrint("❌ Error en onTokenRefresh: $error");
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 🔔 Cada vez que se construye la app, intenta actualizar token
    _updateToken();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthPage(),
      onGenerateRoute: (settings) {
        final currentUser = FirebaseAuth.instance.currentUser;

        switch (settings.name) {
          case '/procesoInspeccion':
            return MaterialPageRoute(
              builder: (_) => ProcesoInspeccion(
                tecnicoEmail: currentUser?.email ?? 'sin-email',
              ),
            );

          case '/actividadesInspeccion':
            if (settings.arguments == null ||
                settings.arguments is! Map<String, dynamic>) {
              return _errorRoute(
                  "Argumentos inválidos en actividadesInspeccion");
            }

            final args = settings.arguments as Map<String, dynamic>;

            debugPrint("=== DEBUG ROUTE ARGS ===");
            debugPrint(settings.arguments.runtimeType.toString());
            debugPrint(settings.arguments.toString());

            return MaterialPageRoute(
              builder: (_) => ActividadesInspeccion(
                arguments: args,
              ),
            );

          default:
            return null;
        }
      },
      routes: {
        '/login': (context) => AuthPage(),
      },
    );
  }
}

MaterialPageRoute _errorRoute(String msg) {
  return MaterialPageRoute(
    builder: (_) => Scaffold(
      body: Center(child: Text(msg)),
    ),
  );
}
