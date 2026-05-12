import 'package:flutter/material.dart';
import '../models/producto.dart';
import '../controllers/ventas.controller.dart';

class CatalogoView extends StatelessWidget {
  final VentasController controller;
  CatalogoView({super.key, required this.controller});

  final List<ProductoAgricola> catalogo = [
    ProductoAgricola(id: 101, nombre: "Maíz Blanco", variedad: "Pioneer 3015", precioSaco: 2400.0, emoji: "🌽"),
    ProductoAgricola(id: 102, nombre: "Maíz Amarillo", variedad: "Dekalb", precioSaco: 2200.0, emoji: "🌽"),
    ProductoAgricola(id: 103, nombre: "Frijol", variedad: "Azufrado Higuera", precioSaco: 1850.0, emoji: "🫘"),
    ProductoAgricola(id: 104, nombre: "Garbanzo", variedad: "Blanco Sinaloa", precioSaco: 3100.0, emoji: "🌾"),
    ProductoAgricola(id: 105, nombre: "Sorgo", variedad: "Grano Rojo", precioSaco: 1100.0, emoji: "🌾"),
    ProductoAgricola(id: 106, nombre: "Trigo", variedad: "Cristalino", precioSaco: 950.0, emoji: "🍞"),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Agrícola del Valle - POS'),
            backgroundColor: Colors.green[800],
            foregroundColor: Colors.white,
            actions: [
              // Icono de Configuración (Solo si hay red)
              IconButton(
                icon: const Icon(Icons.settings), 
                onPressed: controller.isConnected ? () => _mostrarPanelConfig(context) : null
              ),
              // Botón de Corte de Turno (Sincronización)
              IconButton(
                icon: Icon(Icons.cloud_upload, 
                color: controller.sincronizando ? Colors.orange : Colors.white), 
                onPressed: controller.isConnected ? () => controller.sincronizarConNube() : null
              ),
              // Botón de Reportes / IA
              IconButton(
                icon: const Icon(Icons.auto_graph), // Icono más orientado a IA/Gráficas
                onPressed: () { /* Aquí podrías llamar a un reporte de IA */ }
              ),
              // INDICADOR DE ESTADO MQTT (Reemplaza al de Bluetooth)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  controller.isConnected ? Icons.language : Icons.language_outlined,
                  color: controller.isConnected ? Colors.lightGreenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Terminal de Log
              Container(
                width: double.infinity, 
                color: Colors.black87, 
                padding: const EdgeInsets.all(8),
                child: Text(
                  ">_ ${controller.logMensaje}", 
                  style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12)
                )
              ),
              Expanded(
                child: Row(
                  children: [
                    _buildTicket(context),
                    const VerticalDivider(width: 1),
                    _buildCatalogo(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTicket(BuildContext context) {
    return Expanded(
      flex: 4,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.green[50],
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.green[800]),
                const SizedBox(width: 8),
                const Text("TICKET ACTUAL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: controller.carrito.length,
              itemBuilder: (context, i) {
                final producto = controller.carrito[i];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.green[100], child: Text(producto.emoji)),
                  title: Text(producto.nombre),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                    onPressed: () => controller.eliminarDelCarrito(i),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("TOTAL", style: TextStyle(color: Colors.grey)),
                    Text("\$${controller.totalCarrito.toStringAsFixed(2)}", 
                         style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    // Se habilita solo si el carrito tiene items Y hay conexión MQTT
                    onPressed: (controller.carrito.isNotEmpty && controller.isConnected) 
                                ? () => controller.procesarVenta() : null,
                    icon: const Icon(Icons.send_and_archive),
                    label: const Text("GUARDAR VENTA (FOG)"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogo() {
    return Expanded(
      flex: 6,
      child: GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10
        ),
        itemCount: catalogo.length,
        itemBuilder: (context, i) => Card(
          elevation: 2,
          child: InkWell(
            onTap: () => controller.agregarAlCarrito(catalogo[i]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Text(catalogo[i].emoji, style: const TextStyle(fontSize: 40)), 
                const SizedBox(height: 10),
                Text(catalogo[i].nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text("\$${catalogo[i].precioSaco}", style: TextStyle(color: Colors.green[800])),
              ]
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarPanelConfig(BuildContext context) {
    final ssid = TextEditingController(); 
    final pass = TextEditingController();
    final url = TextEditingController(); 
    final key = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("⚙️ Configurar Nodo vía MQTT"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ssid, decoration: const InputDecoration(labelText: "SSID Wi-Fi")),
            TextField(controller: pass, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
            TextField(controller: url, decoration: const InputDecoration(labelText: "Supabase URL")),
            TextField(controller: key, decoration: const InputDecoration(labelText: "Anon Key")),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
          ElevatedButton(
            onPressed: () { 
              // Envia la config al ESP32 por el tópico de comando
              controller.configurarNodo(ssid.text, pass.text, url.text, key.text); 
              Navigator.pop(context); 
            }, 
            child: const Text("ENVIAR AL NODO")
          )
        ],
      ),
    );
  }
}