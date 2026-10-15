import 'package:sistema_rastreabilidad/CalidadPage.dart';
import 'package:sistema_rastreabilidad/pages/produccion_ensamble.dart';
// import 'package:sistema_rastreabilidad/LogisticaPage.dart';
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
    'jorge.morales@asiarobotica.com',
    'bernardo.ramirez@asiarobotica.com',
    'kevin.sanchez@asiarobotica.com'
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
      const ProduccionEnsamble(),
      if (showExtraTabs) UsuariosScreen(),
    ];

    // Items del BottomNavigationBar
    final navItems = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.verified),
        label: 'Calidad',
        backgroundColor: Color.fromARGB(255, 36, 36, 36),
      ),
      if (showExtraTabs)
        const BottomNavigationBarItem(
          icon: Icon(Icons.precision_manufacturing),
          label: 'Máquinas',
          backgroundColor: Colors.black,
        ),

    ];

    // Aseguramos un índice válido
    final safeIndex = _selectedIndex.clamp(0, pages.length - 1);

    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: Builder(builder: (drawerContext) {
            final cs = Theme.of(drawerContext).colorScheme;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    'Formularios',
                    style: Theme.of(drawerContext).textTheme.titleLarge,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    user?.email ?? '',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final item in calidadMenuItems(context))
                        ListTile(
                          leading: Icon(item.icon, color: cs.primary),
                          title: Text(item.title),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onTap: () {
                            Navigator.pop(drawerContext);
                            item.onTap();
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout_rounded),
                  title: const Text('Cerrar sesión'),
                  onTap: _cerrarSesion,
                ),
              ],
            );
          }),
        ),
      ),
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: Colors.white,
                child: Image.asset('lib/images/ar_inicio.png', height: 40),
              ),
            ),
            const SizedBox(width: 12),
            const Text('Inicio'),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Salir'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: pages[safeIndex],
      // bottomNavigationBar: BottomNavigationBar(
      //   items: navItems,
      //   currentIndex: safeIndex,
      //   selectedItemColor: const Color.fromARGB(255, 240, 5, 5),
      //   onTap: _onItemTapped,
      // ),
    );
  }
}
