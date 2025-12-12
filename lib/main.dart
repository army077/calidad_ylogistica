import 'package:sistema_rastreabilidad/auth_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'pages/procesoInspeccion.dart';
import 'pages/actividadesInspeccion.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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

            print("=== DEBUG ROUTE ARGS ===");
            print(settings.arguments.runtimeType);
            print(settings.arguments);

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
