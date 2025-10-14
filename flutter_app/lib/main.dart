import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import 'data/repositories/sensor_repository.dart';
import 'domain/sensor_data.dart';
import 'presentation/controllers/sensor_controller.dart';
import 'presentation/pages/control_page.dart';
import 'presentation/pages/register_page.dart';
import 'presentation/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(
    url: 'https://ujlssaucwnaunizxqphg.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVqbHNzYXVjd25hdW5penhxcGhnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAzNjk3OTEsImV4cCI6MjA3NTk0NTc5MX0.j9j-evd2nvdCApNCAfiUZnXIEq7hi6WmqjviZawxttg',
  );

  // Inicializar Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SensorDataAdapter());

  // ✅ Inicializar el repositorio *antes* del runApp
  final repository = SensorRepository(websocketUrl: 'wss://flutteresp.onrender.com');
  await repository.init(); // 👈 Esperar a que la conexión WebSocket esté lista

  runApp(MyApp(repository: repository));
}

class MyApp extends StatelessWidget {
  final SensorRepository repository;

  const MyApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repositorio principal
        ChangeNotifierProvider.value(value: repository),

        // Controlador dependiente del repositorio
        ChangeNotifierProvider(
          create: (_) => SensorController(repository: repository),
        ),
      ],
      child: MaterialApp(
        title: 'Domótica App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginPage(),
          '/register': (context) => const RegisterPage(),
          '/control': (context) => const ControlPage(),
        },
      ),
    );
  }
}
