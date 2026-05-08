import bluetooth
import struct
import time
import json
import network
import urequests as requests
import os
import machine

# ==========================================
# 1. GESTIÓN DE CONFIGURACIÓN (PERSISTENCIA)
# ==========================================
CONFIG_FILE = "config.json"
DB_LOCAL = "ventas_locales.json"

def cargar_config():
    if CONFIG_FILE in os.listdir():
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    return None

def guardar_config(nuevos_datos):
    try:
        with open(CONFIG_FILE, "w") as f:
            json.dump(nuevos_datos, f)
        return True
    except Exception as e:
        print(f"❌ Error guardando config: {e}")
        return False

config = cargar_config()
WIFI_SSID = config.get("ssid", "") if config else ""
WIFI_PASS = config.get("pass", "") if config else ""
SUPABASE_URL = config.get("url", "") if config else ""
SUPABASE_KEY = config.get("key", "") if config else ""

# ==========================================
# 2. IDENTIFICADORES BLUETOOTH
# ==========================================
_UART_UUID = bluetooth.UUID('6E400001-B5A3-F393-E0A9-E50E24DCCA9E')
_UART_TX   = (bluetooth.UUID('6E400003-B5A3-F393-E0A9-E50E24DCCA9E'), bluetooth.FLAG_NOTIFY)
_UART_RX   = (bluetooth.UUID('6E400002-B5A3-F393-E0A9-E50E24DCCA9E'), bluetooth.FLAG_WRITE | bluetooth.FLAG_WRITE_NO_RESPONSE)
_UART_SERVICE = (_UART_UUID, (_UART_TX, _UART_RX))

# ==========================================
# 3. FUNCIONES DEL FOG COMPUTING (LOCAL)
# ==========================================
def guardar_venta_local(datos):
    try:
        with open(DB_LOCAL, "a") as f:
            # Forzamos el salto de línea al final de cada JSON
            f.write(json.dumps(datos) + "\n")
        return True
    except Exception as e:
        print(f"❌ Error al escribir: {e}")
        return False
    
def contar_ventas_locales():
    try:
        if not DB_LOCAL in os.listdir(): return 0
        with open(DB_LOCAL, "r") as f:
            return len([l for l in f.readlines() if l.strip()])
    except:
        return 0

# ==========================================
# 4. LÓGICA DE RED Y NUBE (CORTE DE TURNO)
# ==========================================
def conectar_wifi():
    if not WIFI_SSID: return False
    
    wlan = network.WLAN(network.STA_IF)
    wlan.active(False) # Forzamos el apagado previo
    time.sleep(0.5)
    wlan.active(True)  # Encendido limpio
    
    if not wlan.isconnected():
        print(f"\n[Wi-Fi] 📡 Intentando conectar a '{WIFI_SSID}'...")
        wlan.connect(WIFI_SSID, WIFI_PASS)
        
        # Espera extendida a 20 segundos
        timeout = 20
        while not wlan.isconnected() and timeout > 0:
            time.sleep(1)
            timeout -= 1
            print(".", end="")
            
    if wlan.isconnected():
        print(f"\n[Wi-Fi] ✅ Conectado. IP: {wlan.ifconfig()[0]}")
        return True
    else:
        # Si falla, imprimimos el estado de error de la antena
        print(f"\n[Wi-Fi] ❌ Error. Estado: {wlan.status()}")
        return False
# Reemplaza la sección de realizar_corte_turno en tu main.py
def realizar_corte_turno():
    print("\n" + "="*50)
    print("[NUBE] 🚀 INICIANDO CORTE DE TURNO")
    print("="*50)

    if not DB_LOCAL in os.listdir():
        return {"tipo": "sync", "status": "exito", "mensaje": "Nada que sincronizar"}

    try:
        with open(DB_LOCAL, "r") as f:
            lineas = [l.strip() for l in f.readlines() if l.strip()]

        if not lineas:
            return {"tipo": "sync", "status": "exito", "mensaje": "Archivo vacio"}

        print(f"[NUBE] Encontradas {len(lineas)} ventas para subir.")
        
        headers = {
            "apikey": SUPABASE_KEY.strip(),
            "Authorization": f"Bearer {SUPABASE_KEY.strip()}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        }

        ventas_exitosas = 0
        for linea in lineas:
            venta = json.loads(linea)
            try:
                payload = {"total": venta.get("total"), "dispositivo_id": "ESP32_Caja_Sinaloa"}
                url_v = f"{SUPABASE_URL.strip()}/rest/v1/ventas"
                
                # Intentamos subir la cabecera
                res_v = requests.post(url_v, json=payload, headers=headers)
                
                if res_v.status_code in [200, 201]:
                    v_uuid = res_v.json()[0]['id']
                    
                    # Preparamos detalles
                    articulos = venta.get("articulos", [])
                    detalles = [{"venta_id": v_uuid, "producto_id": a['id'], "cantidad": a['cantidad'], "precio_unitario": a['precio_unitario']} for a in articulos]
                    
                    res_d = requests.post(f"{SUPABASE_URL.strip()}/rest/v1/venta_detalles", json=detalles, headers=headers)
                    if res_d.status_code in [200, 201]:
                        ventas_exitosas += 1
                    else:
                        print(f"❌ Error en detalles: {res_d.text}")
                    res_d.close()
                else:
                    # ESTO TE DIRA POR QUÉ DA 0
                    print(f"❌ Error en cabecera: {res_v.status_code} - {res_v.text}")
                res_v.close()
                
            except Exception as e:
                print(f"❌ Excepcion en el envio: {e}")

        # Solo borramos si al menos una fue exitosa para no perder datos
        if ventas_exitosas > 0:
            os.remove(DB_LOCAL)
            print(f"🎉 Corte completado. Enviadas: {ventas_exitosas}")
            return {"tipo": "sync", "status": "exito", "enviadas": ventas_exitosas}
        else:
            return {"tipo": "sync", "status": "error", "mensaje": "Fallo el envio a Supabase"}

    except Exception as e:
        print(f"❌ Error general: {e}")
        return {"tipo": "sync", "status": "error", "mensaje": str(e)}
    
def generar_reporte_supabase():
    print("\n[NUBE] 📊 Solicitando listado de ventas...")
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    try:
        # Nota: Ajustado para no pedir 'created_at' si no existe la columna en tu tabla
        res = requests.get(f"{SUPABASE_URL}/rest/v1/ventas?select=id,total&limit=15", headers=headers)
        if res.status_code == 200:
            ventas = res.json()
            res.close()
            return {"tipo": "reporte", "status": "exito", "ventas": ventas}
        res.close()
        return {"tipo": "reporte", "status": "error"}
    except:
        return {"tipo": "reporte", "status": "error"}

def obtener_detalles_venta(venta_id):
    headers = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    try:
        res = requests.get(f"{SUPABASE_URL}/rest/v1/venta_detalles?venta_id=eq.{venta_id}&select=cantidad,precio_unitario,producto_id", headers=headers)
        if res.status_code == 200:
            detalles = res.json()
            res.close()
            return {"tipo": "detalles_venta", "status": "exito", "detalles": detalles}
        res.close()
        return {"tipo": "detalles_venta", "status": "error"}
    except:
        return {"tipo": "detalles_venta", "status": "error"}

# ==========================================
# 5. SERVIDOR BLE (ASÍNCRONO - COLA DE TAREAS)
# ==========================================
class ServidorVentasBLE:
    def __init__(self, ble, nombre="Nodo_Ventas"):
        self._ble = ble
        self._ble.active(True)
        self._ble.irq(self._eventos_ble)
        ((self._handle_tx, self._handle_rx),) = self._ble.gatts_register_services((_UART_SERVICE,))
        self._ble.gatts_set_buffer(self._handle_rx, 512, True)
        self._ble.gatts_set_buffer(self._handle_tx, 512, True)
        self._rx_buffer = bytearray()
        self._conexiones = set()
        self.tareas_pendientes = [] # COLA DE TAREAS

        self._payload_adv = self._crear_publicidad(nombre)
        self._payload_resp = self._crear_respuesta_scan([_UART_UUID])
        self._anunciar()

    def _eventos_ble(self, evento, datos):
        if evento == 1:
            self._conexiones.add(datos[0])
            self._rx_buffer = bytearray()
            print("\n📱 APP VINCULADA")
        elif evento == 2:
            if datos[0] in self._conexiones: self._conexiones.remove(datos[0])
            self._anunciar()
        elif evento == 3:
            conn_handle, value_handle = datos
            if value_handle == self._handle_rx:
                self._rx_buffer += self._ble.gatts_read(self._handle_rx)
                try:
                    peticion = json.loads(self._rx_buffer.decode('utf-8'))
                    self._rx_buffer = bytearray()
                    # Anotamos en la libreta para procesar en el loop principal
                    self.tareas_pendientes.append(peticion)
                except:
                    pass # Mensaje incompleto

    def enviar_respuesta(self, datos):
        # Agregamos un try-except por si la terminal de PC falla al imprimir
        try:
            print(f"[BLE] -> Enviando respuesta a App...")
            datos_bytes = (datos + '\n').encode('utf-8')
            for conn_handle in self._conexiones:
                for i in range(0, len(datos_bytes), 20):
                    self._ble.gatts_notify(conn_handle, self._handle_tx, datos_bytes[i:i+20])
                    time.sleep(0.02)
        except Exception as e:
            print("! Error visual en consola PC")

    def _anunciar(self):
        self._ble.gap_advertise(500000, adv_data=self._payload_adv, resp_data=self._payload_resp)

    def _crear_publicidad(self, nombre):
        p = bytearray(); p += struct.pack("BB", 2, 0x01) + struct.pack("B", 0x06)
        p += struct.pack("BB", len(nombre)+1, 0x09) + nombre.encode(); return p

    def _crear_respuesta_scan(self, servs):
        p = bytearray()
        for s in servs: p += struct.pack("BB", len(bytes(s))+1, 0x07) + bytes(s); return p

# ==========================================
# 6. BUCLE PRINCIPAL (MANEJO DE TAREAS)
# ==========================================
if __name__ == "__main__":
    print("\n" + "#"*50 + "\n🌾 NODO DE NIEBLA AGRÍCOLA INICIANDO...\n" + "#"*50)
    if config: conectar_wifi()
    ble = bluetooth.BLE()
    nodo = ServidorVentasBLE(ble)
    
    while True:
        if len(nodo.tareas_pendientes) > 0:
            tarea = nodo.tareas_pendientes.pop(0)
            cmd = tarea.get("comando")

            if cmd == "sincronizar_nube":
                res = realizar_corte_turno()
                nodo.enviar_respuesta(json.dumps(res))
            elif cmd == "obtener_reporte":
                res = generar_reporte_supabase()
                nodo.enviar_respuesta(json.dumps(res))
            elif cmd == "obtener_detalles":
                res = obtener_detalles_venta(tarea.get("venta_id"))
                nodo.enviar_respuesta(json.dumps(res))
            elif cmd == "configurar_nodo":
                if guardar_config(tarea.get("datos")):
                    nodo.enviar_respuesta(json.dumps({"tipo": "config", "status": "exito"}))
                    time.sleep(2); machine.reset()
            elif "ticket_id" in tarea:
                t_id = tarea.get('ticket_id', 'S/N')
                print(f"\n🛒 Procesando Ticket: {t_id}")
                if guardar_venta_local(tarea):
                    p = contar_ventas_locales()
                    print(f"   ✅ Ticket {t_id} guardado. Pendientes: {p}")
                    nodo.enviar_respuesta(json.dumps({"status": "exito", "pendientes": p}))

        time.sleep(0.1)