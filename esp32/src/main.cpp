#include <WiFi.h>
#include <WebSocketsClient.h>
#include <DHT.h>
<<<<<<< HEAD
#include <time.h>  // ✅ Para obtener la hora NTP
=======
#include <WiFiClientSecure.h>

// ======= CONFIGURACIÓN DE PINES =======
>>>>>>> d895f240349bcce449c4e1ece083d170089e9c0b
#define LED_PIN 2
#define DHT_PIN 25
#define LDR_PIN 26
#define RELAY_PIN 17
<<<<<<< HEAD
const char* ssid = "MACRO_OLIVER";
const char* password = "1085323594@";
const char* websocket_server = "flutteresp.onrender.com"; // SIN https://
const int websocket_port = 443;
const char* websocket_path = "/";
DHT dht(DHT_PIN, DHT11);
WebSocketsClient webSocket;
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 3000; // Enviar cada 3 segundos
void webSocketEvent(WStype_t type, uint8_t * payload, size_t length);
void sendSensorData();
String getCurrentTime();  // ✅ Nueva función
void setup() {
  Serial.begin(115200);
  delay(1000);
=======

// ======= CONFIGURACIÓN DE WIFI =======
const char* ssid = "MACRO_OLIVER";
const char* password = "1085323594@";

// ======= CONFIGURACIÓN DEL SERVIDOR WEBSOCKET =======
const char* websocket_server = "domotica-ws.onrender.com";
const int websocket_port = 443;
const char* websocket_path = "/";

// ======= OBJETOS =======
DHT dht(DHT_PIN, DHT11);
WebSocketsClient webSocket;
WiFiClientSecure client;

// ======= VARIABLES =======
unsigned long lastSendTime = 0;
const unsigned long sendInterval = 3000; // Enviar cada 3 segundos

// ======= PROTOTIPOS =======
void webSocketEvent(WStype_t type, uint8_t * payload, size_t length);
void sendSensorData();

// ======= SETUP =======
void setup() {
  Serial.begin(115200);
  delay(1000);

>>>>>>> d895f240349bcce449c4e1ece083d170089e9c0b
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);
  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, LOW);
  pinMode(LDR_PIN, INPUT);
<<<<<<< HEAD
  dht.begin();
=======

  dht.begin();

  // ======= CONECTAR WIFI =======
>>>>>>> d895f240349bcce449c4e1ece083d170089e9c0b
  Serial.println("Conectando a WiFi...");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ Conectado a WiFi");
  Serial.print("IP local: ");
  Serial.println(WiFi.localIP());
<<<<<<< HEAD
  configTime(-5 * 3600, 0, "pool.ntp.org", "time.nist.gov"); // UTC-5 (Colombia)
  Serial.println("⌚ Esperando sincronización NTP...");
  delay(2000);
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("⚠ No se pudo obtener la hora NTP");
  } else {
    Serial.println("✅ Hora NTP sincronizada correctamente");
  }
  webSocket.beginSSL(websocket_server, websocket_port, websocket_path);
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(5000);
  webSocket.enableHeartbeat(15000, 3000, 2);
  Serial.println("Conectando al servidor WebSocket (Render)...");
}
void loop() {
  webSocket.loop();
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠ WiFi desconectado, intentando reconectar...");
    WiFi.begin(ssid, password);
    delay(1000);
  }
=======

  // ======= CONFIGURAR CLIENTE SSL =======
  client.setInsecure(); // ⚠️ Acepta cualquier certificado (necesario para Render)

  // ======= CONEXIÓN SEGURA CON RENDER =======
  webSocket.beginSSL(websocket_server, websocket_port, websocket_path, "", ""); // usa cliente TLS interno
  webSocket.onEvent(webSocketEvent);
  webSocket.setReconnectInterval(5000);

  Serial.println("Conectando al servidor WebSocket (Render)...");
}

// ======= LOOP PRINCIPAL =======
void loop() {
  webSocket.loop();

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("⚠️ WiFi desconectado, intentando reconectar...");
    WiFi.begin(ssid, password);
    delay(1000);
  }

>>>>>>> d895f240349bcce449c4e1ece083d170089e9c0b
  if (millis() - lastSendTime >= sendInterval) {
    sendSensorData();
    lastSendTime = millis();
  }
}
<<<<<<< HEAD
String getCurrentTime() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "unknown";
  }
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S", &timeinfo);
  return String(buffer);
}
=======

// ======= ENVÍO DE DATOS =======
>>>>>>> d895f240349bcce449c4e1ece083d170089e9c0b
void sendSensorData() {
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  int lightRaw = digitalRead(LDR_PIN);
  bool isDark = (lightRaw == HIGH);
<<<<<<< HEAD
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("⚠ Error al leer DHT11");
    return;
  }
  digitalWrite(RELAY_PIN, temperature > 22.0 ? HIGH : LOW);
  String jsonData = "{";
  jsonData += "\"temperature\":" + String(temperature, 1) + ",";
  jsonData += "\"humidity\":" + String(humidity, 1) + ",";
  jsonData += "\"light\":" + String(isDark ? 1 : 0) + ",";
  jsonData += "\"timestamp\":\"" + getCurrentTime() + "\"";
  jsonData += "}";
  webSocket.sendTXT(jsonData);
  Serial.println("📤 Datos enviados: " + jsonData);
  Serial.printf("🌡 %.1f°C | 💧 %.1f%% | 💡 %d | 🕒 %s | Ventilador: %s\n",
                temperature, humidity,
                isDark ? 1 : 0,
                getCurrentTime().c_str(),
                digitalRead(RELAY_PIN) ? "ON" : "OFF");
}
=======

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("⚠️ Error al leer DHT11");
    return;
  }

  // Control automático del ventilador
  digitalWrite(RELAY_PIN, temperature > 22.0 ? HIGH : LOW);

  // Crear JSON con datos (light como entero 0 o 1)
  String jsonData = "{";
  jsonData += "\"temperature\":" + String(temperature, 1) + ",";
  jsonData += "\"humidity\":" + String(humidity, 1) + ",";
  jsonData += "\"light\":" + String(isDark ? 1 : 0);
  jsonData += "}";

  webSocket.sendTXT(jsonData);

  Serial.println("📤 Datos enviados: " + jsonData);
  Serial.printf("🌡 %.1f°C | 💧 %.1f%% | 💡 %d | Ventilador: %s\n",
                temperature, humidity,
                isDark ? 1 : 0,
                digitalRead(RELAY_PIN) ? "ON" : "OFF");
}

// ======= EVENTOS WEBSOCKET =======
>>>>>>> d895f240349bcce449c4e1ece083d170089e9c0b
void webSocketEvent(WStype_t type, uint8_t * payload, size_t length) {
  switch(type) {
    case WStype_DISCONNECTED:
      Serial.println("❌ Desconectado del servidor WebSocket");
      break;

    case WStype_CONNECTED:
      Serial.println("✅ Conectado al servidor WebSocket (Render)");
      webSocket.sendTXT("ESP32_CONNECTED");
      break;
<<<<<<< HEAD
    case WStype_TEXT: {
      String message = String((char*)payload);
      Serial.println("📩 Mensaje recibido: " + message);
=======

    case WStype_TEXT: {
      String message = String((char*)payload);
      Serial.println("📩 Mensaje recibido: " + message);

>>>>>>> d895f240349bcce449c4e1ece083d170089e9c0b
      if (message == "LED_ON") {
        digitalWrite(LED_PIN, HIGH);
        Serial.println("💡 LED encendido");
      } else if (message == "LED_OFF") {
        digitalWrite(LED_PIN, LOW);
        Serial.println("💡 LED apagado");
      }
      break;
    }
<<<<<<< HEAD
    case WStype_ERROR:
      Serial.println("⚠ Error en la conexión WebSocket");
=======

    case WStype_ERROR:
      Serial.println("⚠️ Error en la conexión WebSocket");
>>>>>>> d895f240349bcce449c4e1ece083d170089e9c0b
      break;
  }
}
