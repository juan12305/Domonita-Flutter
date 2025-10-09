import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/sensor_controller.dart';

class ControlPage extends StatelessWidget {
  const ControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Domótica'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Consumer<SensorController>(
        builder: (context, controller, child) {
          final sensorData = controller.sensorData;
          final connected = controller.connected;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Estado de conexión
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      connected ? Icons.wifi : Icons.wifi_off,
                      color: connected ? Colors.green : Colors.red,
                      size: 30,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      connected ? 'Conectado' : 'Desconectado',
                      style: TextStyle(
                        color: connected ? Colors.green : Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Datos de sensores
                if (sensorData != null) ...[
                  _buildSensorCard(
                    'Temperatura',
                    '${sensorData.temperature.toStringAsFixed(1)} °C',
                    Icons.thermostat,
                    Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  _buildSensorCard(
                    'Humedad',
                    '${sensorData.humidity.toStringAsFixed(1)} %',
                    Icons.water_drop,
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildSensorCard(
                    'Luz',
                    (sensorData.light == 0)
                        ? 'Mucha luz'
                        : (sensorData.light == 1)
                            ? 'Poca luz'
                            : 'Valor desconocido',
                    Icons.lightbulb,
                    Colors.yellow,
                  ),
                ] else ...[
                  const Center(
                    child: Text(
                      'Esperando datos de sensores...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
                const Spacer(),

                // Botones de control del LED
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connected ? controller.turnLedOn : null,
                        icon: const Icon(Icons.lightbulb),
                        label: const Text('Encender LED'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: connected ? controller.turnLedOff : null,
                        icon: const Icon(Icons.lightbulb_outline),
                        label: const Text('Apagar LED'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSensorCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
