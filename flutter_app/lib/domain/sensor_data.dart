import 'package:hive/hive.dart';

part 'sensor_data.g.dart';

@HiveType(typeId: 0)
class SensorData {
  @HiveField(0)
  final double temperature;

  @HiveField(1)
  final double humidity;

  @HiveField(2)
  final int light;

  SensorData({
    required this.temperature,
    required this.humidity,
    required this.light,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: double.tryParse(json['temperature'].toString()) ?? 0.0,
      humidity: double.tryParse(json['humidity'].toString()) ?? 0.0,
      light: int.tryParse(json['light'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'light': light,
    };
  }

  @override
  String toString() {
    return 'SensorData(temperature: $temperature, humidity: $humidity, light: $light)';
  }
}
