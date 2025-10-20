import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../controllers/sensor_controller.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleController;
  final List<_Particle> _particles = List.generate(25, (_) => _Particle());

  @override
  void initState() {
    super.initState();
    _particleController =
        AnimationController(vsync: this, duration: const Duration(seconds: 20))
          ..addListener(() {
            setState(() {
              for (final p in _particles) {
                p.update();
              }
            });
          })
          ..repeat();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<SensorController>(
          builder: (context, controller, child) {
            final data = controller.sensorData;
            final connected = controller.connected;
            final allData = controller.repository.allSensorData;

            final bool isBright = data?.light == 0; // 0 = mucha luz
            final List<Color> dayColors = [
              const Color(0xFF56CCF2),
              const Color(0xFF2F80ED),
              const Color(0xFF6DD5FA)
            ];
            final List<Color> nightColors = [
              const Color(0xFF1A1A2E),
              const Color(0xFF16213E),
              const Color(0xFF0F3460)
            ];

            return Stack(
              children: [
                // Fondo con partículas flotantes
                CustomPaint(
                  painter: _ParticlePainter(_particles),
                  child: Container(),
                ),

                AnimatedContainer(
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isBright ? dayColors : nightColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Título y botón de regreso
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
                          ).animate().scale(duration: 400.ms),
                          Text(
                            'Historial de Datos',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ).animate().fadeIn(duration: 700.ms),
                          const SizedBox(width: 48), // Para centrar el título
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Estado de conexión
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            connected ? Icons.wifi : Icons.wifi_off,
                            color: connected ? Colors.greenAccent : Colors.redAccent,
                            size: 24,
                          ).animate().scale(duration: 800.ms),
                          const SizedBox(width: 8),
                          Text(
                            connected ? 'Conectado' : 'Desconectado',
                            style: GoogleFonts.poppins(
                              color: connected ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ).animate().fadeIn(duration: 700.ms),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Lista de historial
                      Expanded(
                        child: allData.isEmpty
                            ? Center(
                                child: Text(
                                  'No hay datos guardados aún.',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 18,
                                  ),
                                ).animate().fadeIn(duration: 1000.ms),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                itemCount: allData.length,
                                itemBuilder: (context, index) {
                                  final item = allData[allData.length - 1 - index]; // Más reciente primero
                                  final dateTime = DateTime.parse(item.timestamp);
                                  final formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(dateTime);

                                  return Card(
                                    color: Colors.white.withOpacity(0.1),
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      title: Text(
                                        'Registro ${allData.length - index}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Temperatura: ${item.temperature.toStringAsFixed(1)}°C',
                                            style: GoogleFonts.poppins(
                                              color: Colors.orangeAccent,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Humedad: ${item.humidity.toStringAsFixed(1)}%',
                                            style: GoogleFonts.poppins(
                                              color: isBright ? Colors.blue.shade800 : Colors.blueAccent,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Luz: ${item.light == 0 ? "Mucha" : "Poca"}',
                                            style: GoogleFonts.poppins(
                                              color: item.light == 0 ? Colors.yellowAccent : Colors.indigoAccent,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Fecha: $formattedDate',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ).animate().fadeIn(duration: 600.ms, delay: (index * 100).ms);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ==== SISTEMA DE PARTÍCULAS ====
class _Particle {
  Offset position = Offset(Random().nextDouble() * 400, Random().nextDouble() * 800);
  double radius = Random().nextDouble() * 2 + 1;
  double speedX = (Random().nextDouble() - 0.5) * 0.5;
  double speedY = (Random().nextDouble() - 0.5) * 0.5;
  Color color = Colors.white.withOpacity(Random().nextDouble() * 0.3 + 0.2);

  void update() {
    position += Offset(speedX, speedY);
    if (position.dx < 0 || position.dx > 400) speedX *= -1;
    if (position.dy < 0 || position.dy > 800) speedY *= -1;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(p.position, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
