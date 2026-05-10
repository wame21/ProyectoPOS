# Programa POS 🚀
### Sistema de Punto de Venta Escalable con Integración IoT

Este proyecto es una solución integral de punto de venta diseñada para la eficiencia operativa en negocios agrícolas y comerciales. No es solo una aplicación de ventas; es un ecosistema distribuido que combina la potencia de la nube con la resiliencia del hardware local.

## 🎯 Visión del Proyecto
Desarrollado con una arquitectura modular, este sistema está diseñado para ser **agnóstico al modelo de negocio**, permitiendo su escalabilidad y adaptación a diversos sectores comerciales. El núcleo del proyecto reside en la sincronización inteligente entre nodos de hardware periféricos y una base de datos centralizada.

## 🏗️ Arquitectura del Sistema
El sistema se divide en tres capas fundamentales:

1.  **Capa de Aplicación (Frontend):** Desarrollada en **Flutter**, proporcionando una interfaz multiplataforma fluida para la gestión de inventarios, ventas y reportes en tiempo real.
2.  **Capa de Datos (Cloud):** Implementada sobre **Supabase**, gestionando la autenticación, base de datos relacional y almacenamiento de archivos de forma escalable.
3.  **Capa de Telemetría y Hardware (IoT / Edge Computing):** Utiliza microcontroladores **ESP32** programados con **MicroPython**. La comunicación bidireccional de baja latencia se logra mediante el protocolo **MQTT**, actuando como nodos locales rápidos para la impresión de tickets y captura de datos. Esto garantiza un flujo de información eficiente y resiliencia ante caídas de red, procesando decisiones en milisegundos antes de consolidar la información en la nube.

## 🛠️ Stack Tecnológico
* **Frontend:** Flutter, Dart.
* **Backend as a Service:** Supabase (PostgreSQL, Realtime).
* **Hardware & IoT:** ESP32, MicroPython.
* **Protocolos de Comunicación:** MQTT (Mensajería M2M), REST, WebSockets, ESC/POS (Impresoras Térmicas).

## 🚀 Características Principales
* **Sincronización Off-line:** Capacidad de procesar datos localmente y sincronizar con la nube automáticamente al detectar conexión.
* **Arquitectura Modular:** Fácil implementación de nuevos módulos de negocio.
* **Gestión IoT:** Control directo de periféricos de hardware mediante protocolos seriales y Wi-Fi.
* **Dashboard de Analíticas:** Visualización de métricas clave de rendimiento para la toma de decisiones.
* **Telemetría M2M (Machine-to-Machine):** Integración nativa con **MQTT** para un intercambio de mensajes ligero, permitiendo disparar eventos de hardware (como abrir cajas registradoras o imprimir) de forma instantánea y remota sin saturar el servidor principal.

## 📖 Investigación e Ingeniería
Este proyecto sirve como base para el estudio de la **Deuda Técnica** en sistemas concurrentes y cómo el diseño de software debe adaptarse a las limitaciones de los sistemas distribuidos modernos.

---
Desarrollado por [Wilver](https://github.com/wame21) - Líder Técnico del Proyecto.
