import 'package:flutter/material.dart';

import '../../domain/sensor_data.dart';
import '../../data/repositories/sensor_repository.dart';

class SensorController extends ChangeNotifier {
  final SensorRepository repository;

  SensorController({required this.repository}) {
    repository.addListener(_onRepositoryChanged);
  }

  SensorData? get sensorData => repository.lastSensorData;
  bool get connected => repository.connected;

  void _onRepositoryChanged() {
    notifyListeners();
  }

  void turnLedOn() {
    repository.sendLedOn();
  }

  void turnLedOff() {
    repository.sendLedOff();
  }

  @override
  void dispose() {
    repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
