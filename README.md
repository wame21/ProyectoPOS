# Programa POS 🚀
### Sistema de Punto de Venta con Arquitectura Fog-to-Cloud e Integración IoT

Este proyecto es un ecosistema distribuido de misión crítica diseñado para la eficiencia operativa en negocios agrícolas. Combina la potencia de la nube con la resiliencia del **Edge/Fog Computing** para garantizar que el negocio nunca se detenga, incluso en condiciones de conectividad inestable.

Stratum fue concebido para resolver la fragilidad de los sistemas POS tradicionales. Al implementar una arquitectura de estratos, logramos desacoplar la interfaz de la dependencia constante de la nube, utilizando el protocolo MQTT como el tejido conectivo de baja latencia entre el hardware y el software.

## 🎯 Visión del Proyecto
Desarrollado bajo una arquitectura modular, el sistema implementa un modelo de **Soporte de Decisiones (DSS)**. No solo procesa transacciones; utiliza nodos periféricos inteligentes para la captura de datos en tiempo real y su posterior análisis centralizado, permitiendo una escalabilidad agnóstica al modelo de negocio.

## 🏗️ Arquitectura del Sistema
El sistema opera en una jerarquía de tres niveles:

1.  **Capa de Aplicación (Frontend - Cloud):** Interfaz multiplataforma en **Flutter** para la gestión administrativa y visualización de analíticas.
2.  **Capa de Niebla (Fog Computing - Local):** Microcontroladores **ESP32 (MicroPython)** que actúan como servidores locales. Gestionan la persistencia inmediata de ventas y el control de periféricos (impresión térmica, básculas) sin depender de internet latente.
3.  **Infraestructura de Mensajería:** Comunicación bidireccional mediante **MQTT sobre TLS (Puerto 8883)** utilizando clusters de **HiveMQ Cloud**, garantizando seguridad bancaria en el intercambio de datos M2M.

## 🛠️ Stack Tecnológico
* **Frontend:** Flutter, Dart (State Management con Provider).
* **Backend & DB:** Supabase (PostgreSQL), RESTful APIs.
* **IoT & Edge:** ESP32, MicroPython v1.28+.
* **Protocolos:** MQTT con cifrado TLS 1.2, SSL/TLS Handshaking, WebSockets.
* **Infraestructura:** CachyOS (Entorno de desarrollo), HiveMQ Cloud (Broker).

## 🚀 Características Avanzadas
* **Resiliencia de Red (Offline-First):** Implementación de buffers locales en memoria Flash que permiten la operación total del punto de venta sin conexión a internet, sincronizando lotes de datos (**Batch Processing**) de forma asíncrona.
* **Optimización de Recursos Embebidos:** Gestión avanzada de memoria mediante **Garbage Collection (GC)** y optimización de payloads JSON para operar en dispositivos con RAM limitada.
* **Seguridad Industrial:** Conexiones IoT cifradas de extremo a extremo, evitando ataques de interceptación de datos en redes públicas o inestables.
* **Telemetría en Tiempo Real:** Latencia mínima en el envío de comandos desde la App hacia el hardware para acciones inmediatas (Corte de caja, impresión de tickets).

## 📖 Investigación e Ingeniería
Este proyecto constituye un caso de estudio sobre el **Impacto de los patrones de diseño secuenciales en la deuda técnica y la escalabilidad de sistemas concurrentes modernos**, explorando cómo la arquitectura de software mitiga las limitaciones físicas del hardware en entornos distribuidos.

---
**Ingeniería y Desarrollo:** [Wilver](https://github.com/wame21) - Software Engineer
*"Transformando datos agrícolas en inteligencia de negocio."*
