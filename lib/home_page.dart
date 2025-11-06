import 'package:sistema_rastreabilidad/CalidadPage.dart';
import 'package:sistema_rastreabilidad/LogisticaPage.dart';
import 'package:sistema_rastreabilidad/pages/maquinas_screen.dart';
import 'package:sistema_rastreabilidad/pages/usuarios_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final User? user = FirebaseAuth.instance.currentUser;

  // Correos para los que MOSTRAREMOS "Máquinas" y "Colaboradores"
  final List<String> _showTabsFor = [
    'maximiliano.martinez@bladecsi.com',
    'jaime.flores@asiarobotica.com',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOutWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    await googleSignIn.signOut();
  }

  void _cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
    await _signOutWithGoogle();
  }

  @override
  Widget build(BuildContext context) {
    final email = user?.email?.toLowerCase() ?? '';
    // Mostramos pestañas extra solo si el correo está en la lista
    final showExtraTabs = _showTabsFor.contains(email);

    // Páginas (mantener mismo orden que los BottomNavigationBarItem)
    final pages = <Widget>[
      CalidadPage(),
      LogisticaPage(),
      if (showExtraTabs) MaquinasScreen(),
      if (showExtraTabs) UsuariosScreen(),
    ];

    // Items del BottomNavigationBar
    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.verified),
        label: 'Calidad',
        backgroundColor: Colors.black,
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.local_shipping),
        label: 'Logística',
        backgroundColor: Colors.black,
      ),
      if (showExtraTabs)
        const BottomNavigationBarItem(
          icon: Icon(Icons.precision_manufacturing),
          label: 'Máquinas',
          backgroundColor: Colors.black,
        ),
      if (showExtraTabs)
        const BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: 'Colaboradores',
          backgroundColor: Colors.black,
        ),
    ];

    // Aseguramos un índice válido
    final safeIndex = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
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
                'Inicio',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: _cerrarSesion,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Center(
                  child: Text(
                    'Salir',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: pages[safeIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: navItems,
        currentIndex: safeIndex,
        selectedItemColor: const Color.fromARGB(255, 240, 5, 5),
        onTap: _onItemTapped,
      ),
    );
  }
}
