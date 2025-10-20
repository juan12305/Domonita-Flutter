import 'package:flutter/material.dart';

import '../../domain/sensor_data.dart';
import '../../data/repositories/sensor_repository.dart';
import '../../data/services/gemini_service.dart';

class SensorController extends ChangeNotifier {
  final SensorRepository repository;
  final GeminiService geminiService;
  bool _isAutoMode = false;
  Map<String, String>? _cachedDecision;
  DateTime? _lastDecisionTime;

  // Cache decisions for 5 minutes to avoid excessive API calls
  static const Duration _decisionCacheDuration = Duration(seconds: 15);


  SensorController({required this.repository, required String geminiApiKey})
      : geminiService = GeminiService(geminiApiKey) {
    repository.addListener(_onRepositoryChanged);
  }

  SensorData? get sensorData => repository.lastSensorData;
  bool get connected => repository.connected;
  bool get isAutoMode => _isAutoMode;

  void _onRepositoryChanged() async {
    notifyListeners();
    if (_isAutoMode && sensorData != null) {
      debugPrint('Auto mode active, sensor data: ${sensorData!.toJson()}');
      final decision = await getAutoDecision();
      debugPrint('AI decision: $decision');
      if (decision != null) {
        if (decision['light_action'] == 'ON') {
          debugPrint('AI decided to turn LIGHT ON');
          turnLedOn();
        } else {
          debugPrint('AI decided to turn LIGHT OFF');
          turnLedOff();
        }
        if (decision['fan_action'] == 'ON') {
          debugPrint('AI decided to turn FAN ON');
          turnFanOn();
        } else {
          debugPrint('AI decided to turn FAN OFF');
          turnFanOff();
        }
      } else {
        debugPrint('AI decision returned null');
      }
    }
  }

  void turnLedOn() {
    repository.sendLedOn();
  }

  void turnLedOff() {
    repository.sendLedOff();
  }

  void turnFanOn() {
    repository.sendFanOn();
  }

  void turnFanOff() {
    repository.sendFanOff();
  }

  void toggleAutoMode() {
    _isAutoMode = !_isAutoMode;
    // Clear cache when toggling auto mode
    if (!_isAutoMode) {
      _cachedDecision = null;
      _lastDecisionTime = null;
      debugPrint('Cleared AI decision cache when disabling auto mode');
    }
    notifyListeners();
  }

  Future<Map<String, String>?> getAutoDecision() async {
    if (sensorData == null) return null;

    // Check if we have a cached decision that's still valid
    if (_cachedDecision != null && _lastDecisionTime != null) {
      final timeSinceLastDecision = DateTime.now().difference(_lastDecisionTime!);
      if (timeSinceLastDecision < _decisionCacheDuration) {
        debugPrint('Using cached AI decision (age: ${timeSinceLastDecision.inMinutes} minutes)');
        return _cachedDecision;
      }
    }

    // Get new decision from AI
    final decision = await geminiService.getAutoDecision(sensorData!);

    // Cache the decision if successful
    if (decision != null) {
      _cachedDecision = decision;
      _lastDecisionTime = DateTime.now();
      debugPrint('Cached new AI decision for 5 minutes');
    }

    return decision;
  }

  @override
  void dispose() {
    repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }
}
