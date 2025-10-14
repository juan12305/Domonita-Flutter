import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../controllers/sensor_controller.dart';

class ControlPage extends StatefulWidget {
  const ControlPage({super.key});

  @override
  State<ControlPage> createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
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

                      // Estado de conexión
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            connected ? Icons.wifi : Icons.wifi_off,
                            color: connected ? Colors.greenAccent : Colors.redAccent,
                            size: 32,
                          ).animate().scale(duration: 800.ms),
                          const SizedBox(width: 8),
                          Text(
                            connected ? 'Conectado' : 'Desconectado',
                            style: GoogleFonts.poppins(
                              color: connected ? Colors.greenAccent : Colors.redAccent,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ).animate().fadeIn(duration: 700.ms),
                        ],
                      ),

                      const SizedBox(height: 30),

                      if (data != null) ...[
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  // ====== Temperatura (halo cálido)
                                  _buildGaugeWithHalo(
                                    title: "Temperatura",
                                    value: data.temperature,
                                    unit: "°C",
                                    color: Colors.orangeAccent,
                                    icon: Icons.thermostat,
                                    haloColor: Colors.orangeAccent.withOpacity(0.35),
                                  ).animate().fadeIn(duration: 900.ms),

                                  // ====== Humedad (halo frío + azul más oscuro en modo día)
                                  _buildGaugeWithHalo(
                                    title: "Humedad",
                                    value: data.humidity,
                                    unit: "%",
                                    color: isBright
                                        ? Colors.blue.shade800 // azul oscuro en modo día
                                        : Colors.blueAccent, // azul claro en modo noche
                                    icon: Icons.water_drop,
                                    haloColor: isBright
                                        ? Colors.white.withOpacity(0.25)
                                        : Colors.blueAccent.withOpacity(0.3),
                                  ).animate().fadeIn(duration: 1100.ms),
                                ],
                              ),
                              const SizedBox(height: 50),

                              // ====== Luz (sin halo)
                              _buildLightIndicator(data.light)
                                  .animate()
                                  .fadeIn(duration: 1300.ms),
                            ],
                          ),
                        ),
                      ] else
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Esperando datos del sensor...',
                              style: TextStyle(color: Colors.white70, fontSize: 16),
                            ),
                          ),
                        ),

                      // Botones LED
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: connected ? controller.turnLedOn : null,
                                icon: const Icon(Icons.lightbulb, color: Colors.white),
                                label: const Text("Encender LED"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.greenAccent.shade400,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 12,
                                ),
                              ).animate().scale(duration: 400.ms),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: connected ? controller.turnLedOff : null,
                                icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
                                label: const Text("Apagar LED"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.shade400,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 12,
                                ),
                              ).animate().scale(duration: 400.ms),
                            ),
                          ],
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

  // Gauge con halo (usado en temperatura y humedad)
  Widget _buildGaugeWithHalo({
    required String title,
    required double value,
    required String unit,
    required Color color,
    required IconData icon,
    required Color haloColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: haloColor,
            blurRadius: 40,
            spreadRadius: 12,
          ),
        ],
      ),
      child: _buildGauge(
        title: title,
        value: value,
        unit: unit,
        color: color,
        icon: icon,
      ),
    );
  }

  Widget _buildGauge({
    required String title,
    required double value,
    required String unit,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      height: 220,
      width: 170,
      child: SfRadialGauge(
        enableLoadingAnimation: true,
        animationDuration: 1000,
        axes: [
          RadialAxis(
            minimum: 0,
            maximum: title == "Temperatura" ? 50 : 100,
            showLabels: false,
            showTicks: false,
            axisLineStyle: AxisLineStyle(
              thickness: 0.2,
              color: Colors.white24,
              thicknessUnit: GaugeSizeUnit.factor,
            ),
            pointers: [
              RangePointer(
                value: value,
                width: 0.25,
                sizeUnit: GaugeSizeUnit.factor,
                color: color,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: [
              GaugeAnnotation(
                widget: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 36),
                    const SizedBox(height: 10),
                    Text(
                      "${value.toStringAsFixed(1)}$unit",
                      style: GoogleFonts.poppins(
                        color: color,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLightIndicator(int light) {
    final bool isBright = light == 0;
    final Color color = isBright ? Colors.yellowAccent : Colors.indigoAccent;
    final String status = isBright ? "Mucha luz" : "Poca luz";
    final IconData icon = isBright ? Icons.wb_sunny_rounded : Icons.nightlight_round;

    return Container(
      height: 220,
      width: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(isBright ? 0.6 : 0.3),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: isBright ? 30 : 10,
            spreadRadius: isBright ? 10 : 2,
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 60)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 1200.ms),
            const SizedBox(height: 12),
            Text(
              status,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              "Luz ambiental",
              style: GoogleFonts.poppins(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
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
