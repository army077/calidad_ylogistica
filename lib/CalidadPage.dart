// lib/CalidadPage.dart

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
                MaterialPageRoute(builder: (_) => const ProcesoInspeccion()),
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
              label: 'Proceso de liberación de embarque',
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

class _MenuTile extends StatelessWidget {
  final String imagePath;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;

  const _MenuTile({
    required this.imagePath,
    required this.label,
    required this.onTap,
    this.backgroundColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Image.asset(imagePath, width: 500),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
            ),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
