// server.js
const express = require('express');
const http = require('http');
const WebSocket = require('ws');

const PORT = process.env.PORT || 3000;

const app = express();

// Render necesita que haya un endpoint HTTP activo
app.get('/', (req, res) => {
  res.send('Servidor WebSocket activo');
});

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

let esp32Client = null;
let flutterClients = [];

wss.on('connection', (ws) => {
  console.log('Nueva conexión establecida');

  ws.on('message', (message) => {
    const msg = message.toString();
    console.log('Mensaje recibido:', msg);

    if (msg === 'ESP32_CONNECTED') {
      esp32Client = ws;
      console.log('ESP32 conectado');
      ws.send('connection_successful');
    } else if (msg === 'FLUTTER_CONNECTED') {
      flutterClients.push(ws);
      console.log('Flutter conectado');
      ws.send('connection_successful');
    } else if (msg === 'LED_ON' || msg === 'LED_OFF') {
      if (esp32Client && esp32Client.readyState === WebSocket.OPEN) {
        esp32Client.send(msg);
        console.log('Comando enviado al ESP32:', msg);
      }
    } else {
      try {
        const sensorData = JSON.parse(msg);
        if (
          sensorData.temperature !== undefined &&
          sensorData.humidity !== undefined &&
          sensorData.light !== undefined
        ) {
          flutterClients.forEach((client) => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(msg);
            }
          });
          console.log('Datos reenviados a Flutter:', msg);
        }
      } catch (e) {
        console.log('Mensaje no reconocido:', msg);
      }
    }
  });

  ws.on('close', () => {
    console.log('Conexión cerrada');
    if (ws === esp32Client) {
      esp32Client = null;
      console.log('ESP32 desconectado');
    } else {
      flutterClients = flutterClients.filter((c) => c !== ws);
      console.log('Flutter desconectado');
    }
  });
});

server.listen(PORT, () => {
  console.log(`Servidor WebSocket y HTTP activo en puerto ${PORT}`);
});
