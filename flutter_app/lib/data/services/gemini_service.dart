import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../domain/sensor_data.dart';

class GeminiService {
  late GenerativeModel _model;

  GeminiService(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-2.0-flash-lite', // Using gemini-2.0-flash-lite which is free
      apiKey: apiKey,
    );
  }

  Future<Map<String, String>?> getAutoDecision(SensorData data) async {
    debugPrint('GeminiService: getAutoDecision called with data: ${data.toJson()}');

    final prompt = '''
Eres un sistema de control automático de domótica IoT. Tu ÚNICA función es decidir si encender o apagar el bombillo y ventilador basado en reglas simples.

**SENSORES:**
- light: 0 = mucha luz, 1 = poca luz
- temperature: grados Celsius

**REGLAS EXACTAS:**
- SI light = 1 ENTONCES light_action = "ON" SINO light_action = "OFF"
- SI temperature >= 22 ENTONCES fan_action = "ON" SINO fan_action = "OFF"

**IMPORTANTE:**
- NO uses lógica compleja, solo sigue estas reglas exactas
- Responde ÚNICAMENTE con JSON válido
- Formato: {"light_action": "ON/OFF", "fan_action": "ON/OFF", "reason": "breve explicación"}

**DATOS ACTUALES:**
${data.toJson()}
''';

    debugPrint('GeminiService: Sending prompt to AI');

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      debugPrint('GeminiService: Raw AI response: "$text"');

      if (text != null) {
        debugPrint('GeminiService: Processing response...');
        // Handle markdown code blocks
        String jsonText = text;
        if (text.contains('```')) {
          debugPrint('GeminiService: Response contains markdown code blocks, extracting JSON...');
          // Extract JSON from markdown code block
          final jsonMatch = RegExp(r'```(?:json)?\s*(\{.*?\})\s*```', dotAll: true).firstMatch(text);
          if (jsonMatch != null) {
            jsonText = jsonMatch.group(1)!;
            debugPrint('GeminiService: Extracted JSON from code block: "$jsonText"');
          } else {
            debugPrint('GeminiService: Could not extract JSON from code block');
          }
        }

        if (jsonText.startsWith('{') && jsonText.endsWith('}')) {
          debugPrint('GeminiService: Response looks like JSON, parsing...');
          final Map<String, dynamic> result = jsonDecode(jsonText);
          debugPrint('GeminiService: Parsed result: $result');

          final decision = <String, String>{
            'light_action': result['light_action'] ?? 'OFF',
            'fan_action': result['fan_action'] ?? 'OFF',
            'reason': result['reason'] ?? 'No reason provided',
          };
          debugPrint('GeminiService: Final decision: $decision');
          return decision;
        } else {
          debugPrint('GeminiService: Response does not look like JSON');
        }
      } else {
        debugPrint('GeminiService: Response is null');
      }
    } catch (e) {
      debugPrint('GeminiService: Error generating auto decision: $e');
    }
    debugPrint('GeminiService: Returning null');
    return null;
  }

  Future<String?> generateAnalysis(List<SensorData> data) async {
    if (data.isEmpty) return null;

    final prompt = '''
Eres un analista experto en datos ambientales IoT especializado en interpretar lecturas de sensores para optimizar el confort del hogar.

**INSTRUCCIONES DE ANÁLISIS:**
- Analiza ÚNICAMENTE los datos históricos proporcionados en formato JSON array.
- Cada dato contiene: temperature (°C), humidity (%), light (0=mucha luz, 1=poca luz), timestamp.
- Interpreta los valores con contexto:
  * Temperatura: 18-25°C óptimo, >25°C caluroso, <18°C frío.
  * Humedad: 40-60% confortable, >70% húmedo, <30% seco.
  * Luz: 0=día/brillante, 1=noche/oscuro.

**ANÁLISIS REQUERIDO:**
- **Tendencias**: Identifica patrones temporales (día/noche, variaciones estacionales).
- **Anomalías**: Detecta valores extremos o cambios bruscos inusuales.
- **Comportamiento**: Observa correlaciones entre temperatura, humedad y luz.
- **Recomendaciones**: Sugiere ajustes en iluminación o ventilación basados en datos.

**SALIDA:**
- Responde en español con texto claro y estructurado.
- Incluye estadísticas clave (promedios, mínimos, máximos).
- Máximo 300 palabras, enfocado en insights útiles para el usuario.

**DATOS HISTÓRICOS:**
${data.map((d) => d.toJson()).toList()}
''';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      return response.text?.trim();
    } catch (e) {
      print('Error generating analysis: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> chatResponse(String userMessage, List<String> history) async {
    debugPrint('GeminiService: chatResponse called with message: "$userMessage"');
    debugPrint('GeminiService: history length: ${history.length}');

    final context = history.isNotEmpty ? 'Historial de conversación reciente:\n${history.join('\n')}\n\n' : '';
    final prompt = '''
Eres un asistente inteligente especializado en sistemas de domótica IoT con sensores ambientales. Tu conocimiento incluye:

**SISTEMA ACTUAL:**
- Sensores: Temperatura (°C), Humedad (%), Luz (0=mucha luz, 1=poca luz)
- Actuadores: Bombillo (iluminación), Ventilador (circulación de aire)
- Almacenamiento: Datos históricos en Hive (últimos 200 registros), conversaciones en Supabase
- Modos: Manual (control directo) y Automático (decisiones IA basadas en sensores)

**INSTRUCCIONES DE RESPUESTA:**
- Responde ÚNICAMENTE en español, usando términos muy claros y simples para que cualquier persona pueda entender fácilmente, sin jerga técnica complicada.
- Explica todo de manera sencilla, como si hablaras con alguien que no conoce mucho de tecnología.
- Usa el contexto de conversación proporcionado para mantener coherencia.
- Si la pregunta involucra datos, menciona rangos normales de forma fácil:
  * Temperatura: entre 18 y 25 grados Celsius es lo mejor
  * Humedad: entre 40 y 60 por ciento se siente cómodo
  * Luz: 0 significa mucho sol o día, 1 significa poca luz o noche
- Para preguntas técnicas, explica el funcionamiento del sistema IoT de manera básica y paso a paso.
- Si no tienes datos específicos, sugiere consultar los registros históricos de forma simple.
- Mantén respuestas cortas pero útiles (máximo 200 palabras), enfocándote en lo que el usuario necesita saber.

**COMANDOS DE CONTROL:**
- Para respuestas normales sin comandos, responde con texto claro en español.
- Si el usuario pide encender o apagar el bombillo o ventilador, responde con JSON estructurado.
- Formato JSON: {"response": "mensaje de confirmación", "actions": ["turn_led_on", "turn_led_off", "turn_fan_on", "turn_fan_off"]}
- Solo incluye acciones si se detecta un comando claro.
- Ejemplos:
  * "Enciende el bombillo" -> {"response": "Encendiendo el bombillo.", "actions": ["turn_led_on"]}
  * "Apaga el ventilador" -> {"response": "Apagando el ventilador.", "actions": ["turn_fan_off"]}
  * Pregunta normal -> Respuesta normal en texto claro

**CONTEXTO RECIENTE:**
${context}

**PREGUNTA DEL USUARIO:**
$userMessage
''';

    debugPrint('GeminiService: Sending prompt to AI for chat');
    debugPrint('GeminiService: Prompt length: ${prompt.length}');

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      debugPrint('GeminiService: Raw chat response: "$text"');

      if (text != null) {
        // Try to parse as JSON
        try {
          final Map<String, dynamic> result = jsonDecode(text);
          debugPrint('GeminiService: Parsed JSON response: $result');
          return result;
        } catch (e) {
          debugPrint('GeminiService: Response not JSON, treating as plain text');
          // If not JSON, treat as plain text response
          return {'response': text, 'actions': []};
        }
      }
    } catch (e) {
      debugPrint('GeminiService: Error generating chat response: $e');
    }
    debugPrint('GeminiService: Returning null from chatResponse');
    return null;
  }
}
