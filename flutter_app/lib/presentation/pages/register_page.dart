import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _loading = false;
  String? _error;

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

  Future<void> _register() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        data: {
          'name': _nameController.text.trim(),
          'username': _usernameController.text.trim(),
        },
      );

      if (response.user != null) {
        await Supabase.instance.client.from('users').insert({
          'id': response.user!.id,
          'email': _emailController.text.trim(),
          'name': _nameController.text.trim(),
          'username': _usernameController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registro exitoso ✅')),
          );
          Navigator.pushReplacementNamed(context, '/control');
        }
      } else {
        setState(() => _error = 'No se pudo registrar el usuario.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con partículas flotantes
          CustomPaint(
            painter: _ParticlePainter(_particles),
            child: Container(),
          ),

          // Gradiente dinámico
          AnimatedContainer(
            duration: const Duration(seconds: 3),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF56CCF2), Color(0xFF2F80ED), Color(0xFF6DD5FA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ).animate().fadeIn(duration: 1.seconds),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedBuilder(
                animation: _particleController,
                builder: (context, child) {
                  final pulseValue = (sin(_particleController.value * 2 * pi) + 1) / 2;
                  return Form(
                    key: _formKey,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.6 + 0.3 * pulseValue),
                            blurRadius: 20 + 15 * pulseValue,
                            spreadRadius: 2 + 2 * pulseValue,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "Crea tu cuenta",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn().slideY(begin: 0.3, end: 0),

                          const SizedBox(height: 30),

                          _buildTextField(_nameController, "Nombre", Icons.person),
                          const SizedBox(height: 16),
                          _buildTextField(_usernameController, "Usuario", Icons.account_circle),
                          const SizedBox(height: 16),
                          _buildTextField(_emailController, "Correo electrónico", Icons.email),
                          const SizedBox(height: 16),
                          _buildTextField(_passwordController, "Contraseña", Icons.lock, isPassword: true),

                          const SizedBox(height: 20),
                          if (_error != null)
                            Text(_error!, style: const TextStyle(color: Colors.redAccent)),

                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _loading
                                ? null
                                : () {
                                    if (_formKey.currentState!.validate()) _register();
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6C63FF),
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 60),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              shadowColor: const Color(0xFF6C63FF).withOpacity(0.5),
                              elevation: 12,
                            ),
                            child: _loading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text("Registrarse",
                                    style: TextStyle(fontSize: 16, color: Colors.white)),
                          ).animate().fadeIn().scale(),

                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                            child: const Text(
                              "¿Ya tienes cuenta? Inicia sesión",
                              style: TextStyle(color: Colors.white70),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF6C63FF)),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Completa este campo' : null,
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
