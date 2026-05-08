import 'package:flutter/material.dart';
import 'controllers/ventas.controller.dart';
import 'views/catalogo.dart';

void main() {
  // Inicializamos el Controlador Principal
  final controladorPrincipal = VentasController();
  
  runApp(MyApp(controller: controladorPrincipal));
}

class MyApp extends StatelessWidget {
  final VentasController controller;

  const MyApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Agrícola Fog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: CatalogoView(controller: controller),
      debugShowCheckedModeBanner: false,
    );
  }
}