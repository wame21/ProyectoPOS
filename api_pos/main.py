import time
import json
import network
import urequests as requests
import os
import machine
import gc
from umqtt.simple import MQTTClient

gc.enable()
# ==========================================
# 1. CONFIGURACIÓN Y PERSISTENCIA
# ==========================================
CONFIG_FILE = "config.json"
DB_LOCAL = "ventas_locales.json"

def cargar_config():
    if CONFIG_FILE in os.listdir():
        with open(CONFIG_FILE, "r") as f:
            return json.load(f)
    return {}

config = cargar_config()
WIFI_SSID = config.get("ssid", "")
WIFI_PASS = config.get("pass", "")
SUPABASE_URL = config.get("url", "").strip()
SUPABASE_KEY = config.get("key", "").strip()

# ==========================================
# 2. CONFIGURACIÓN MQTT (Protocolo de Red)
# ==========================================
MQTT_BROKER = "1be01d467a4748fc89b8512e0a268484.s1.eu.hivemq.cloud" 
MQTT_USER = "admin_pos"
MQTT_PASS = "CjFhReWZMppU9yS"
CLIENT_ID = "ESP_POS_NODE"
TOPIC_SUB = b"sys/guasave/comando"    
TOPIC_PUB = b"sys/guasave/respuesta"  

# ==========================================
# 3. LÓGICA DE FOG COMPUTING Y NUBE
# ==========================================
def guardar_venta_local(datos):
    try:
        with open(DB_LOCAL, "a") as f:
            f.write(json.dumps(datos) + "\n")
        return True
    except Exception as e:
        print(f"❌ Error Flash: {e}")
        return False

def contar_ventas_locales():
    try:
        if not DB_LOCAL in os.listdir(): return 0
        with open(DB_LOCAL, "r") as f:
            return len([l for l in f.readlines() if l.strip()])
    except: return 0

def realizar_corte_turno():
    print("[NUBE] 🚀 INICIANDO CORTE DE TURNO")
    gc.collect() # Limpiamos antes de empezar
    
    try:
        # 1. Verificar Wi-Fi
        wlan = network.WLAN(network.STA_IF)
        if not wlan.isconnected():
            return {"tipo": "sync", "status": "error", "mensaje": "Sin Wi-Fi"}
        
        if not DB_LOCAL in os.listdir():
            return {"tipo": "sync", "status": "exito", "enviadas": 0}

        # 2. Leer ventas locales
        with open(DB_LOCAL, "r") as f:
            lineas = [l.strip() for l in f.readlines() if l.strip()]

        headers = {
            "apikey": SUPABASE_KEY,
            "Authorization": "Bearer " + SUPABASE_KEY,
            "Content-Type": "application/json"
        }

        exitosas = 0
        for linea in lineas:
            try:
                venta = json.loads(linea)
                payload = {"total": venta.get("total"), "dispositivo_id": CLIENT_ID}
                
                # Aumentamos el timeout a 20 segundos por la latencia de red
                res = requests.post(SUPABASE_URL + "/rest/v1/ventas", 
                                    json=payload, 
                                    headers=headers, 
                                    timeout=20)
                
                if res.status_code in [200, 201]:
                    exitosas += 1
                
                res.close()
                gc.collect() # Liberar RAM tras cada envío exitoso
                time.sleep(0.2) # Pequeña pausa para no saturar el socket
                
            except Exception as e:
                print("⚠️ Falló un ticket, saltando al siguiente...")
                continue

        # 3. Finalizar
        if exitosas > 0:
            os.remove(DB_LOCAL) # Solo borramos si logramos subir algo
            
        return {"tipo": "sync", "status": "exito", "enviadas": exitosas}
        
    except Exception as e:
        gc.collect()
        return {"tipo": "sync", "status": "error", "mensaje": "Timeout de Red"}
    
# ==========================================
# 4. MANEJADOR MQTT
# ==========================================
def procesar_mensaje(topic, msg):
    # Forzamos limpieza de RAM antes de procesar un mensaje nuevo
    gc.collect() 
    
    payload = msg.decode('utf-8', 'ignore')
    print(f"📥 MQTT Recibido ({len(payload)} bytes)")
    
    try:
        tarea = json.loads(payload)
        
        # 1. Si es una venta (contiene ticket_id)
        if "ticket_id" in tarea:
            if guardar_venta_local(tarea):
                p = contar_ventas_locales()
                # Respondemos a la App para que sepa que se guardó en el Nodo
                client.publish(TOPIC_PUB, json.dumps({
                    "status": "exito", 
                    "pendientes": p,
                    "mensaje": "Venta guardada en Fog Node"
                }))
                print(f"✅ Venta {tarea['ticket_id']} guardada localmente.")
                del tarea
                gc.collect()
        
        # 2. Si es el comando de sincronización
        elif tarea.get("comando") == "sincronizar_nube":
            res = realizar_corte_turno()
            client.publish(TOPIC_PUB, json.dumps(res))
            
    except Exception as e:
        # Esto atrapará cualquier error y evitará que el programa se detenga
        print(f"❌ Error al procesar JSON: {e}")
# ==========================================
# 5. INICIALIZACIÓN Y BUCLE INFINITO
# ==========================================
def iniciar_sistema():
    gc.collect()
    print("\n" + "="*40 + "\nPOS AGRÍCOLA - SISTEMA DE RED\n" + "="*40)
    
    # 1. CONEXIÓN WI-FI ROBUSTA
    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)
    
    if not wlan.isconnected():
        print(f"📡 Intentando conectar a: {WIFI_SSID}")
        wlan.connect(WIFI_SSID, WIFI_PASS)
        
        # Espera máxima de 20 segundos con feedback visual
        intentos = 0
        while not wlan.isconnected() and intentos < 20:
            print(f"  . . . ({intentos}s)")
            time.sleep(1)
            intentos += 1
    
    if wlan.isconnected():
        print(f"✅ Wi-Fi Conectado! IP: {wlan.ifconfig()[0]}")
    else:
        print("❌ No se pudo establecer Wi-Fi. Reintentando...")
        time.sleep(5)
        machine.reset()

    # 2. CONEXIÓN MQTT CON SESIÓN LIMPIA
    global client
    try:
        gc.collect()
        # Cambiamos el CLIENT_ID ligeramente para "engañar" al broker y que nos deje entrar limpio
        NUEVO_ID = CLIENT_ID + "_" + str(machine.unique_id()[-2:])
        
        client = MQTTClient(
            NUEVO_ID, 
            MQTT_BROKER, 
            user=MQTT_USER, 
            password=MQTT_PASS, 
            port=8883, 
            ssl=True,
            ssl_params={'server_hostname': MQTT_BROKER},
            keepalive=60
        )
        
        client.set_callback(procesar_mensaje)
        
        print(f"🔐 Estableciendo túnel SSL con HiveMQ...")
        # clean_session=True es vital si el broker te está rechazando
        client.connect(clean_session=True)
        
        client.subscribe(TOPIC_SUB)
        print(f"🚀 SISTEMA ONLINE - Escuchando comandos")

        while True:
            gc.collect()
            client.check_msg()
            time.sleep(0.5)

    except Exception as e:
        # Si falla el SSL, imprimimos el error pero esperamos antes de resetear
        print(f"❌ Error de Protocolo: {e}")
        time.sleep(10)
        machine.reset()

# Ejecución automática al arrancar
iniciar_sistema()