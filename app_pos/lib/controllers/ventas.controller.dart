import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'dart:async';
import '../models/producto.dart';

class VentasController extends ChangeNotifier {
  // === ESTADO DEL CARRITO ===
  List<ProductoAgricola> carrito = [];
  double get totalCarrito => carrito.fold(0, (sum, item) => sum + item.precioSaco);

  // === ESTADO DEL BLUETOOTH ===
  final String targetDeviceName = "Nodo_Ventas";
  final String rxUuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e"; 
  final String txUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e"; 
  
  String _bleBuffer = ""; 
  bool isConnected = false;
  bool isScanning = false;
  bool sincronizando = false;
  
  // Estados de Reportes
  bool cargandoReporte = false;
  List<dynamic> listaReportes = [];
  bool cargandoDetalles = false;
  List<dynamic> detallesVentaActual = [];
  
  String logMensaje = "Listo para conectar";
  BluetoothDevice? esp32Device;
  BluetoothCharacteristic? writeCharacteristic;

  // === MÉTODOS DE CARRITO ===
  void agregarAlCarrito(ProductoAgricola p) { carrito.add(p); notifyListeners(); }
  void eliminarDelCarrito(int index) {
  if (index >= 0 && index < carrito.length) {
    carrito.removeAt(index);
    notifyListeners(); // Esto redibuja la pantalla inmediatamente
  }
}
  void vaciarCarrito() { carrito.clear(); notifyListeners(); }

  // === GESTIÓN BLE ===
  Future<void> escanearYConectar() async {
    if (isScanning) return;
    isScanning = true; logMensaje = "Buscando Nodo BLE..."; notifyListeners();
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.advName == targetDeviceName || r.device.platformName == targetDeviceName) {
          FlutterBluePlus.stopScan(); _conectarDispositivo(r.device); break;
        }
      }
    });
  }

  Future<void> _conectarDispositivo(BluetoothDevice device) async {
    try {
      await device.connect(autoConnect: false, license: License.free);
      try { await device.requestMtu(512); } catch (e) { }
      esp32Device = device;
      List<BluetoothService> services = await device.discoverServices();
      for (var s in services) {
        for (var c in s.characteristics) {
          if (c.uuid.toString() == rxUuid) writeCharacteristic = c;
          if (c.uuid.toString() == txUuid) {
            await c.setNotifyValue(true);
            c.lastValueStream.listen(_procesarEntradaBLE);
          }
        }
      }
      isConnected = true; isScanning = false; logMensaje = "✅ Conectado al Nodo"; notifyListeners();
    } catch (e) { isConnected = false; isScanning = false; logMensaje = "❌ Error de conexión"; notifyListeners(); }
  }

void _procesarEntradaBLE(List<int> value) {
  _bleBuffer += utf8.decode(value);
  
  if (_bleBuffer.contains('\n')) {
    final mensajes = _bleBuffer.split('\n');
    _bleBuffer = mensajes.last; // Mantener el fragmento incompleto

    for (var i = 0; i < mensajes.length - 1; i++) {
      String raw = mensajes[i].trim();
      if (raw.isEmpty) continue;
      
      try {
        // Buscamos solo el primer JSON válido si vinieran pegados
        if (raw.contains('}{')) raw = raw.split('}{')[0] + '}';
        
        final data = jsonDecode(raw);
        if (data['tipo'] == 'sync') {
          sincronizando = false;
          logMensaje = data['status'] == 'exito' 
              ? "✅ Corte OK: ${data['enviadas']} enviadas" 
              : "❌ Error: ${data['mensaje']}";
        }
        notifyListeners();
      } catch (e) {
        print("Salto de fragmento corrupto: $raw");
      }
    }
  }
}
  // Helper para enviar JSONs grandes por pedazos
  Future<void> _enviarComandoFragmentado(Map<String, dynamic> payload) async {
    if (!isConnected || writeCharacteristic == null) return;
    List<int> bytes = utf8.encode(jsonEncode(payload));
    for (int i = 0; i < bytes.length; i += 200) {
      int end = (i + 200 < bytes.length) ? i + 200 : bytes.length;
      await writeCharacteristic!.write(bytes.sublist(i, end), withoutResponse: false);
      await Future.delayed(const Duration(milliseconds: 35));
    }
  }

  // === COMANDOS ===
  Future<void> procesarVenta() async {
    if (!isConnected || carrito.isEmpty) return;
    logMensaje = "Enviando ticket..."; notifyListeners();
    final ticket = {
      "ticket_id": "TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}", 
      "total": totalCarrito, 
      "articulos": carrito.map((p) => {"id": p.id, "nombre": p.nombre, "cantidad": 1, "precio_unitario": p.precioSaco, "subtotal": p.precioSaco}).toList()
    };
    await _enviarComandoFragmentado(ticket);
    vaciarCarrito();
  }

 Future<void> sincronizarConNube() async {
  if (!isConnected) {
    logMensaje = "⚠️ Error: Nodo no conectado";
    notifyListeners();
    return;
  }

  sincronizando = true;
  logMensaje = "🚀 Ejecutando Corte de Turno...";
  notifyListeners();

  try {
    // Enviamos el comando al ESP32 para que inicie la subida a Supabase
    await _enviarComandoFragmentado({"comando": "sincronizar_nube"});
    
    // El logMensaje se actualizará automáticamente cuando el ESP32 
    // responda a través del Stream de la característica TX
  } catch (e) {
    logMensaje = "❌ Error en el envío: $e";
    sincronizando = false;
    notifyListeners();
  }
}

  Future<void> solicitarReporte() async {
    cargandoReporte = true; listaReportes = []; notifyListeners();
    await _enviarComandoFragmentado({"comando": "obtener_reporte"});
  }

  Future<void> solicitarDetallesVenta(String idVenta) async {
    cargandoDetalles = true; detallesVentaActual = []; notifyListeners();
    await _enviarComandoFragmentado({"comando": "obtener_detalles", "venta_id": idVenta});
  }

  void configurarNodo(String ssid, String pass, String url, String key) async {
  if (!isConnected) {
    logMensaje = "⚠️ Conecta el Bluetooth primero";
    notifyListeners();
    return;
  }

  logMensaje = "⚙️ Enviando configuración...";
  notifyListeners();

  // El ESP32 espera un comando llamado 'configurar_nodo' 
  // y dentro una llave 'datos' con toda la info
  final mensajeConfig = {
    "comando": "configurar_nodo",
    "datos": {
      "ssid": ssid,
      "pass": pass,
      "url": url,
      "key": key,
    }
  };

  await _enviarComandoFragmentado(mensajeConfig);
}
}