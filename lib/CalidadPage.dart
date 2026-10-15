// lib/CalidadPage.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:sistema_rastreabilidad/pages/incoming.dart';
import 'package:sistema_rastreabilidad/pages/procesoInspeccion.dart';
import 'package:sistema_rastreabilidad/pages/procesoLiberacion.dart';
import 'package:sistema_rastreabilidad/pages/liberacion_empaque.dart';
import 'package:sistema_rastreabilidad/pages/Enbarque.dart';
import 'package:flutter/material.dart';

/// Formularios disponibles en el navigation drawer del home.
List<MenuItem> calidadMenuItems(BuildContext context) {
  void go(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  return <MenuItem>[
    MenuItem(
      icon: Icons.move_to_inbox_rounded,
      title: 'Incoming',
      subtitle: 'Recepción de material',
      onTap: () => go(const Incoming()),
    ),
    MenuItem(
      icon: Icons.search_rounded,
      title: 'Procesos de inspección',
      subtitle: 'Inspección durante el proceso',
      onTap: () => go(ProcesoInspeccion(
        tecnicoEmail: FirebaseAuth.instance.currentUser?.email ?? '',
      )),
    ),
    MenuItem(
      icon: Icons.verified_rounded,
      title: 'Procesos de liberación',
      subtitle: 'Liberación de producto',
      onTap: () => go(const ProcesoLiberacion()),
    ),
    MenuItem(
      icon: Icons.inventory_2_rounded,
      title: 'Pre-Embarque',
      subtitle: 'Revisión previa al embarque',
      onTap: () => go(const Embarque()),
    ),
    MenuItem(
      icon: Icons.local_shipping_rounded,
      title: 'Liberación de embarque',
      subtitle: 'Liberación de empaque',
      onTap: () => go(const LiberacionEmpaque()),
    ),
  ];
}

class MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
