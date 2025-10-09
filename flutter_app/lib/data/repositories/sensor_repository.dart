import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/sensor_data.dart';

class SensorRepository extends ChangeNotifier {
  final String websocketUrl;
  late WebSocketChannel _channel;
  late Box _box;

  SensorData? _lastSensorData;
  bool _connected = false;

  SensorRepository({required this.websocketUrl});

  SensorData? get lastSensorData => _lastSensorData;
  bool get connected => _connected;

  Future<void> init() async {
    _box = await Hive.openBox('sensorDataBox');
    // Load last saved data
    final savedData = _box.get('lastSensorData');
    if (savedData != null) {
      _lastSensorData = SensorData.fromJson(Map<String, dynamic>.from(savedData));
    }
    _connect();
  }

  void _connect() {
    _channel = WebSocketChannel.connect(Uri.parse(websocketUrl));

    _channel.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data is Map<String, dynamic> &&
            data.containsKey('temperature') &&
            data.containsKey('humidity') &&
            data.containsKey('light')) {
          _lastSensorData = SensorData.fromJson(data);
          _box.put('lastSensorData', data);
          notifyListeners();
        }
      } catch (e) {
        // Ignore non-JSON messages or errors
      }
    }, onDone: () {
      _connected = false;
      notifyListeners();
      _reconnect();
    }, onError: (error) {
      _connected = false;
      notifyListeners();
      _reconnect();
    });

    _channel.ready.then((_) {
      _connected = true;
      notifyListeners();
      _channel.sink.add('FLUTTER_CONNECTED');
    });
  }

  void _reconnect() async {
    await Future.delayed(const Duration(seconds: 5));
    if (!_connected) {
      _connect();
    }
  }

  void sendLedOn() {
    if (_connected) {
      _channel.sink.add('LED_ON');
    }
  }

  void sendLedOff() {
    if (_connected) {
      _channel.sink.add('LED_OFF');
    }
  }

  void dispose() {
    _channel.sink.close();
    super.dispose();
  }
}
