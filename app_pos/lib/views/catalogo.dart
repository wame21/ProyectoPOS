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
              IconButton(icon: const Icon(Icons.settings), onPressed: controller.isConnected ? () => _mostrarPanelConfig(context) : null),
              IconButton(icon: Icon(Icons.cloud_upload, color: controller.sincronizando ? Colors.orange : Colors.white), 
                         onPressed: controller.isConnected ? () => controller.sincronizarConNube() : null),
              IconButton(icon: const Icon(Icons.bar_chart), onPressed: () { controller.solicitarReporte(); _mostrarReportes(context); }),
              IconButton(icon: Icon(controller.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled), 
                         onPressed: controller.escanearYConectar),
            ],
          ),
          body: Column(
            children: [
              Container(width: double.infinity, color: Colors.black87, padding: const EdgeInsets.all(8),
                        child: Text(">_ ${controller.logMensaje}", style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace'))),
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
        // Encabezado estético del ticket
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: Colors.green[50],
          child: Row(
            children: [
              Icon(Icons.receipt_long, color: Colors.green[800]),
              const SizedBox(width: 8),
              Text(
                "TICKET ACTUAL",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[800],
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        // Lista de productos en el carrito
        Expanded(
          child: ListView.builder(
            itemCount: controller.carrito.length,
            itemBuilder: (context, i) {
              final producto = controller.carrito[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.green[100],
                  child: Text(producto.emoji),
                ),
                title: Text(producto.nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(producto.variedad),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "\$${producto.precioSaco}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(width: 4),
                    // BOTÓN DE ELIMINAR INDIVIDUAL
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                      onPressed: () => controller.eliminarDelCarrito(i),
                      tooltip: "Quitar producto",
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const Divider(height: 1, thickness: 1),

        // Sección de Totales y Acción
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL A PAGAR", style: TextStyle(fontSize: 16, color: Colors.grey)),
                  Text(
                    "\$${controller.totalCarrito.toStringAsFixed(2)}",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              
              // BOTÓN PRINCIPAL DE VENTA (RESTAURADO)
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: controller.carrito.isNotEmpty ? () => controller.procesarVenta() : null,
                  icon: const Icon(Icons.sd_storage), // Icono que representa guardar en memoria local
                  label: const Text(
                    "GUARDAR VENTA LOCAL",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "La venta se guardará en el Nodo de Niebla",
                style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
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
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
        itemCount: catalogo.length,
        itemBuilder: (context, i) => Card(
          child: InkWell(
            onTap: () => controller.agregarAlCarrito(catalogo[i]),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, 
                           children: [Text(catalogo[i].emoji, style: const TextStyle(fontSize: 30)), 
                                      Text(catalogo[i].nombre, style: const TextStyle(fontWeight: FontWeight.bold))]),
          ),
        ),
      ),
    );
  }

  void _mostrarReportes(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("📊 Ventas en la Nube"),
        content: SizedBox(
          width: 400, height: 500,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              if (controller.cargandoReporte) return const Center(child: CircularProgressIndicator());
              return ListView.builder(
                itemCount: controller.listaReportes.length,
                itemBuilder: (context, i) {
                  final v = controller.listaReportes[i];
                  return ListTile(
                    title: Text("Venta: \$${v['total']}"),
                    subtitle: Text("ID: ${v['id'].toString().substring(0,8)}"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () { controller.solicitarDetallesVenta(v['id']); _mostrarDetalles(context); },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _mostrarDetalles(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Detalles de Venta"),
        content: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            if (controller.cargandoDetalles) return const CircularProgressIndicator();
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: controller.detallesVentaActual.map((d) => Text("Producto: ${d['producto_id']} - Cant: ${d['cantidad']}")).toList(),
            );
          },
        ),
      ),
    );
  }

  void _mostrarPanelConfig(BuildContext context) {
    final ssid = TextEditingController(); final pass = TextEditingController();
    final url = TextEditingController(); final key = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Configurar Nodo"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: ssid, decoration: const InputDecoration(labelText: "SSID Wi-Fi")),
          TextField(controller: pass, decoration: const InputDecoration(labelText: "Password"), obscureText: true),
          TextField(controller: url, decoration: const InputDecoration(labelText: "Supabase URL")),
          TextField(controller: key, decoration: const InputDecoration(labelText: "Anon Key")),
        ]),
        actions: [ElevatedButton(onPressed: () { controller.configurarNodo(ssid.text, pass.text, url.text, key.text); Navigator.pop(context); }, child: const Text("GUARDAR"))],
      ),
    );
  }
}