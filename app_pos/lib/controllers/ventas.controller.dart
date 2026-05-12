import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import '../models/producto.dart';

class VentasController extends ChangeNotifier {
  // === CONFIGURACIÓN HIVEMQ CLOUD ===
  // Reemplaza con los datos de tu consola de HiveMQ
  final String broker = '1be01d467a4748fc89b8512e0a268484.s1.eu.hivemq.cloud';
  final String clienteId = 'FLUTTER_APP';
  final String usuario = 'admin_pos';
  final String password = 'CjFhReWZMppU9yS';

  // Tópicos (Deben coincidir con el ESP32)
  final String topicComando = 'sys/guasave/comando';
  final String topicRespuesta = 'sys/guasave/respuesta';

  // === ESTADO DE LA APLICACIÓN ===
  List<ProductoAgricola> carrito = [];
  double get totalCarrito =>
      carrito.fold(0, (sum, item) => sum + item.precioSaco);

  MqttServerClient? client;
  bool isConnected = false;
  bool sincronizando = false;
  String logMensaje = "Iniciando sistema...";

  // Listas para Reportes e IA
  List<dynamic> listaReportes = [];
  bool cargandoReporte = false;

  VentasController() {
    inicializarMQTT();
  }

  // === MÉTODOS DE CARRITO ===
  void agregarAlCarrito(ProductoAgricola p) {
    carrito.add(p);
    notifyListeners();
  }

  void eliminarDelCarrito(int index) {
    if (index >= 0 && index < carrito.length) {
      carrito.removeAt(index);
      notifyListeners();
    }
  }

  void vaciarCarrito() {
    carrito.clear();
    notifyListeners();
  }

  // === GESTIÓN MQTT ===
  Future<void> inicializarMQTT() async {
    client = MqttServerClient(broker, clienteId);
    client!.port = 8883;
    client!.secure = true; // HiveMQ Cloud lo requiere

    // ESTO ES CLAVE PARA LINUX/CACHYOS
    client!.onBadCertificate = (dynamic cert) => true;

    client!.logging(on: true); // Activa esto para ver el error real en consola
    client!.keepAlivePeriod = 20;
    client!.onDisconnected = onDisconnected;
    client!.onConnected = onConnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clienteId)
        .authenticateAs(usuario, password)
        .startClean(); // Eliminamos el 'withWill' para simplificar la conexión inicial

    client!.connectionMessage = connMess;

    try {
      logMensaje = "🌐 Conectando a HiveMQ Cloud...";
      notifyListeners();
      await client!.connect();
    } catch (e) {
      logMensaje = "❌ Fallo de Protocolo: $e";
      print("DEBUG MQTT: $e");
      isConnected = false;
      notifyListeners();
    }
  }

  void onConnected() {
    isConnected = true;
    logMensaje = "✅ Nodo en la Nube Vinculado";

    // Suscribirse a las respuestas del ESP32
    client!.subscribe(topicRespuesta, MqttQos.atMostOnce);

    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String pt = MqttPublishPayload.bytesToStringAsString(
        recMess.payload.message,
      );
      _procesarRespuestaMQTT(pt);
    });

    notifyListeners();
  }

  Future<void> configurarNodo(
    String ssid,
    String pass,
    String url,
    String key,
  ) async {
    if (!isConnected) {
      logMensaje = "⚠️ No hay conexión al Broker";
      notifyListeners();
      return;
    }

    logMensaje = "⚙️ Enviando configuración vía MQTT...";
    notifyListeners();

    final mensajeConfig = {
      "comando": "configurar_nodo",
      "datos": {"ssid": ssid, "pass": pass, "url": url, "key": key},
    };

    // Publicamos en el tópico de comando para que el ESP32 lo reciba
    _publicar(topicComando, jsonEncode(mensajeConfig));
  }

  void onDisconnected() {
    isConnected = false;
    logMensaje = "⚠️ Desconectado del Broker";
    notifyListeners();
  }

  void _procesarRespuestaMQTT(String payload) {
    try {
      final data = jsonDecode(payload);

      if (data['tipo'] == 'sync') {
        sincronizando = false;
        logMensaje = data['status'] == 'exito'
            ? "✅ Corte OK: ${data['enviadas']} ventas"
            : "❌ Error: ${data['mensaje']}";
      } else if (data['status'] == 'exito' && data.containsKey('pendientes')) {
        logMensaje = "✅ Venta registrada (Pendientes: ${data['pendientes']})";
      }

      notifyListeners();
    } catch (e) {
      print("Error parseando respuesta: $e");
    }
  }

  // === COMANDOS ENVIADOS AL ESP32 ===
  Future<void> procesarVenta() async {
    if (!isConnected || carrito.isEmpty) return;

    logMensaje = "Enviando ticket vía MQTT...";
    notifyListeners();

    // Busca la parte donde creas el 'ticket' para enviar:
    final ticket = {
      "ticket_id":
          "TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(9)}",
      "total": totalCarrito,
      "articulos": carrito
          .map(
            (p) => {
              "id": p.id,
              // "nombre": p.nombre,  <-- COMENTA O ELIMINA ESTO
              "cantidad": 1,
              "precio": p.precioSaco,
            },
          )
          .toList(),
    };
    _publicar(topicComando, jsonEncode(ticket));
    vaciarCarrito();
  }

  Future<void> sincronizarConNube() async {
    if (!isConnected) return;
    sincronizando = true;
    logMensaje = "🚀 Solicitando Corte de Turno...";
    notifyListeners();

    _publicar(topicComando, jsonEncode({"comando": "sincronizar_nube"}));
  }

  void _publicar(String topic, String mensaje) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(mensaje);
    client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }
}
