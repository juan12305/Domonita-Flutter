import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'data/repositories/sensor_repository.dart';
import 'domain/sensor_data.dart';
import 'presentation/controllers/sensor_controller.dart';
import 'presentation/pages/control_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Hive
  await Hive.initFlutter();
  Hive.registerAdapter(SensorDataAdapter());

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final repository = SensorRepository(websocketUrl: 'ws://192.168.110.155:3000');
            repository.init();
            return repository;
          },
        ),
        ChangeNotifierProxyProvider<SensorRepository, SensorController>(
          create: (context) => SensorController(repository: context.read<SensorRepository>()),
          update: (context, repository, previous) => SensorController(repository: repository),
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
        home: const ControlPage(),
      ),
    );
  }
}
