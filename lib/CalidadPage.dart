// lib/CalidadPage.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:sistema_rastreabilidad/pages/incoming.dart';
import 'package:sistema_rastreabilidad/pages/procesoInspeccion.dart';
import 'package:sistema_rastreabilidad/pages/procesoLiberacion.dart';
import 'package:sistema_rastreabilidad/pages/liberacion_empaque.dart';
import 'package:sistema_rastreabilidad/pages/Enbarque.dart';
import 'package:flutter/material.dart';

class CalidadPage extends StatelessWidget {
  const CalidadPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 14),
            // --- Incoming ---
            _MenuTile(
              imagePath: 'lib/images/incoming.png',
              label: 'Incoming',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Incoming()),
              ),
            ),

            const SizedBox(height: 14),

            // --- Proceso de Inspección ---
            _MenuTile(
              imagePath: 'lib/images/procesosInspeccion.png',
              label: 'Procesos de inspección',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProcesoInspeccion(
                    tecnicoEmail:
                        FirebaseAuth.instance.currentUser?.email ?? '',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // --- Proceso de Liberación ---
            _MenuTile(
              imagePath: 'lib/images/procesoliberacion.png',
              label: 'Procesos de liberación',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProcesoLiberacion()),
              ),
            ),

            const SizedBox(height: 14),

            // --- Pre-Embarque ---
            _MenuTile(
              imagePath: 'lib/images/embarques.png',
              label: 'Pre-Embarque',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Embarque()),
              ),
            ),

            _MenuTile(
              imagePath: 'lib/images/proceso_embarque2.png',
              label: 'Liberación de embarque',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LiberacionEmpaque()),
              ),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
class _MenuTile extends StatefulWidget {
  final String imagePath;
  final String label;
  final VoidCallback onTap;

  const _MenuTile({
    required this.imagePath,
    required this.label,
    required this.onTap,
  });

  @override
  State<_MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<_MenuTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: _hover ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 180, 180, 180),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 146, 146, 146).withOpacity(_hover ? 0.6 : 0.3),
                blurRadius: _hover ? 18 : 10,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: _hover ? Colors.redAccent : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: Image.asset(
                  widget.imagePath,
                  width: 520,
                  fit: BoxFit.cover,
                ),
              ),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ElevatedButton(
                  onPressed: widget.onTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 82, 82, 82),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}


 