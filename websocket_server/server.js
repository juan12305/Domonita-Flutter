const WebSocket = require('ws');

const server = new WebSocket.Server({ port: 3000 });

let esp32Client = null;
let flutterClients = [];

console.log('Servidor WebSocket iniciado en el puerto 3000');

server.on('connection', (ws) => {
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
      // Comando desde Flutter al ESP32
      if (esp32Client && esp32Client.readyState === WebSocket.OPEN) {
        esp32Client.send(msg);
        console.log('Comando enviado al ESP32:', msg);
      } else {
        console.log('ESP32 no conectado, no se puede enviar comando');
      }
    } else {
      // Datos de sensores desde ESP32, reenviar a Flutter
      try {
        const sensorData = JSON.parse(msg);
        if (sensorData.temperature !== undefined && sensorData.humidity !== undefined && sensorData.light !== undefined) {
          flutterClients.forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(msg);
            }
          });
          console.log('Datos de sensores reenviados a Flutter:', msg);
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
      flutterClients = flutterClients.filter(client => client !== ws);
      console.log('Flutter desconectado');
    }
  });

  ws.on('error', (error) => {
    console.error('Error en la conexión:', error);
  });
});

console.log('Esperando conexiones...');
