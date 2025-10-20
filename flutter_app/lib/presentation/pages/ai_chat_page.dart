import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/repositories/sensor_repository.dart';
import '../../data/services/gemini_service.dart';
import '../../domain/sensor_data.dart';
import '../controllers/sensor_controller.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  final List<List<Map<String, String>>> _chatHistory = [];
  String? _analysis;
  bool _isChatLoading = false;
  bool _isAnalysisLoading = false;
  bool _showAnalysis = false;
  int _currentChatId = 1;

  late GeminiService _geminiService;
  
  @override
  void initState() {
    super.initState();
    final controller = Provider.of<SensorController>(context, listen: false);
    _geminiService = controller.geminiService;
    _loadChatHistory();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistory() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('chat_history')
          .select('message, response, created_at, chat_id')
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      if (response.isNotEmpty) {
        // Find the latest chat_id
        final maxChatId = response.map((r) => r['chat_id'] as int? ?? 0).reduce((a, b) => a > b ? a : b);
        _currentChatId = maxChatId + 1;

        // Load only messages from the latest chat
        final latestChatMessages = response.where((r) => r['chat_id'] == maxChatId).toList();

        setState(() {
          _messages.clear();
          for (final row in latestChatMessages) {
            _messages.add({'user': row['message'], 'ai': row['response']});
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading chat history from Supabase: $e');
      // Continue without loading history
    }
  }

  Future<void> _generateAnalysis() async {
    setState(() => _isAnalysisLoading = true);
    final repository = Provider.of<SensorRepository>(context, listen: false);
    final data = repository.allSensorData.take(100).toList();

    final analysis = await _geminiService.generateAnalysis(data);
    setState(() {
      _analysis = analysis;
      _isAnalysisLoading = false;
    });

    // Save to Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && analysis != null) {
      try {
        await Supabase.instance.client.from('chat_history').insert({
          'user_id': userId,
          'message': 'Generar análisis',
          'response': analysis,
          'analysis_data': data.map((d) => d.toJson()).toList(),
        });
      } catch (e) {
        debugPrint('Error saving analysis to Supabase: $e');
        // Continue without saving to DB
      }
    }
  }

  Future<void> _startNewChat() async {
    if (_messages.isNotEmpty) {
      _chatHistory.add(List.from(_messages));
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      // Buscar el máximo chat_id actual del usuario
      final response = await Supabase.instance.client
          .from('chat_history')
          .select('chat_id')
          .eq('user_id', userId);

      int newChatId = 1;
      if (response.isNotEmpty) {
        final ids = response.map((r) => r['chat_id'] as int? ?? 0);
        newChatId = (ids.reduce((a, b) => a > b ? a : b)) + 1;
      }

      setState(() {
        _messages.clear();
        _currentChatId = newChatId;
      });

      debugPrint('Nuevo chat creado con chat_id=$_currentChatId');

    } catch (e) {
      debugPrint('Error al crear nuevo chat: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    debugPrint('AiChatPage: Sending message: "$message"');
    setState(() => _isChatLoading = true);
    _messageController.clear();

    // ✅ Obtener los datos más recientes de los sensores
    final repository = Provider.of<SensorRepository>(context, listen: false);
    final data = repository.allSensorData.take(50).toList(); // puedes ajustar el número
    debugPrint('AiChatPage: Loaded ${data.length} sensor readings');

    // Construir historial del chat
    final history = _messages.map((m) => '${m['user']}: ${m['ai']}').toList();

    // ✅ Pasar los datos del sensor al servicio de Gemini
    final responseData = await _geminiService.chatResponse(
      message,
      history,
      sensorData: data, // 🔥 Nuevo parámetro con datos reales
    );

    debugPrint('AiChatPage: Received response data: $responseData');

    String aiResponse = 'Error: No se pudo obtener respuesta de la IA';
    if (responseData != null) {
      final rawResponse = responseData['response'];
      if (rawResponse is String) {
        aiResponse = rawResponse;
      } else if (rawResponse is Map) {
        aiResponse = rawResponse['response'] ?? aiResponse;
      }

      final actions = responseData['actions'] as List<dynamic>? ?? [];
      final controller = Provider.of<SensorController>(context, listen: false);
      for (final action in actions) {
        switch (action) {
          case 'turn_led_on':
            controller.turnLedOn();
            break;
          case 'turn_led_off':
            controller.turnLedOff();
            break;
          case 'turn_fan_on':
            controller.turnFanOn();
            break;
          case 'turn_fan_off':
            controller.turnFanOff();
            break;
        }
      }
    }

    setState(() {
      _messages.add({'user': message, 'ai': aiResponse});
      _isChatLoading = false;
    });

    // Scroll automático
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Guardar en Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        await Supabase.instance.client.from('chat_history').insert({
          'user_id': userId,
          'message': message,
          'response': aiResponse,
          'chat_id': _currentChatId,
          'analysis_data': data.map((d) => d.toJson()).toList(), // ✅ guardar también los datos
        });
      } catch (e) {
        debugPrint('Error saving message to Supabase: $e');
      }
    }
  }

  void _showAnalysisDialog(BuildContext context) async {
    setState(() => _isAnalysisLoading = true);
    final repository = Provider.of<SensorRepository>(context, listen: false);
    final data = repository.allSensorData.take(100).toList();

    final analysis = await _geminiService.generateAnalysis(data);
    setState(() => _isAnalysisLoading = false);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.tealAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Colors.tealAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Análisis de Datos del Sistema',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (analysis != null) ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    child: SingleChildScrollView(
                      child: Text(
                        analysis,
                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Center(
                    child: Text(
                      'No se pudo generar el análisis',
                      style: GoogleFonts.poppins(
                        color: Colors.redAccent,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cerrar',
                        style: GoogleFonts.poppins(
                          color: Colors.tealAccent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // Save analysis to Supabase
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null && analysis != null) {
      try {
        await Supabase.instance.client.from('chat_history').insert({
          'user_id': userId,
          'message': 'Generar análisis',
          'response': analysis,
          'analysis_data': data.map((d) => d.toJson()).toList(),
        });
      } catch (e) {
        debugPrint('Error saving analysis to Supabase: $e');
        // Continue without saving to DB
      }
    }
  }

  void _showChatHistory(BuildContext context) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario no autenticado')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16213E),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history,
                        color: Colors.tealAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Historial de Chats',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: Supabase.instance.client
                        .from('chat_history')
                        .select('message, response, created_at, chat_id')
                        .eq('user_id', userId)
                        .order('created_at', ascending: false)
                        .limit(50),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: Colors.tealAccent),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error al cargar el historial',
                            style: GoogleFonts.poppins(color: Colors.redAccent),
                          ),
                        );
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.history_toggle_off,
                                color: Colors.white38,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No hay chats en el historial',
                                style: GoogleFonts.poppins(
                                  color: Colors.white38,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Group messages into chats based on time gaps (e.g., 30 minutes)
                      // Use messages in ascending order (oldest first) for proper grouping
                      final chats = _groupMessagesIntoChats(messages);

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: chats.length,
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final firstMessage = chat.first;
                          final lastMessage = chat.last;
                          final startTime = DateTime.parse(firstMessage['created_at']).toLocal();
                          final endTime = DateTime.parse(lastMessage['created_at']).toLocal();

                          return GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              _loadChat(chat);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F0F23),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.chat,
                                        color: Colors.tealAccent,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Chat ${index + 1}',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${startTime.day}/${startTime.month} ${startTime.hour}:${startTime.minute.toString().padLeft(2, '0')}',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${chat.length} mensajes',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    chat.first['message'] ?? 'Mensaje vacío',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      color: Colors.white60,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<List<Map<String, dynamic>>> _groupMessagesIntoChats(List<Map<String, dynamic>> messages) {
    final Map<int, List<Map<String, dynamic>>> grouped = {};

    for (final message in messages) {
      final chatId = message['chat_id'] as int? ?? 0;
      grouped.putIfAbsent(chatId, () => []).add(message);
    }

    // Ordenar los chats por chat_id descendente (último chat primero)
    final sortedChats = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return sortedChats.map((e) => e.value).toList();
  }

  void _loadChat(List<Map<String, dynamic>> chatMessages) {
    setState(() {
      _messages.clear();
      for (final msg in chatMessages.reversed) { // Reverse to chronological order
        _messages.add({'user': msg['message'], 'ai': msg['response']});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.tealAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.tealAccent,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Asistente IA',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.tealAccent),
            onPressed: _startNewChat,
            tooltip: 'Nuevo chat',
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Colors.tealAccent),
            onPressed: () => _showChatHistory(context),
            tooltip: 'Ver historial completo',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.tealAccent),
            onPressed: _loadChatHistory,
            tooltip: 'Recargar historial',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Quick Actions Bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isAnalysisLoading ? null : () => _showAnalysisDialog(context),
                      icon: _isAnalysisLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.analytics_outlined),
                      label: Text(
                        _isAnalysisLoading ? 'Generando...' : 'Análisis de Datos',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent.withOpacity(0.1),
                        foregroundColor: Colors.tealAccent,
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 24 : 16,
                          vertical: isTablet ? 14 : 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.tealAccent, width: 1),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      '${_messages.length} mensajes',
                      style: GoogleFonts.poppins(
                        color: Colors.blueAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            // Chat Messages
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: _messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
  controller: _scrollController,
  padding: EdgeInsets.all(isTablet ? 24 : 16),
  itemCount: _messages.length,
  itemBuilder: (context, index) {
    final msg = _messages[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Burbuja del usuario
        _buildMessageBubble({'user': msg['user']!}, true, isTablet),
        const SizedBox(height: 8),
        // Burbuja de la IA
        _buildMessageBubble({'ai': msg['ai']!}, false, isTablet),
      ],
    );
  },
),
              ),
            ),

            // Message Input
            Container(
              margin: EdgeInsets.all(isTablet ? 24 : 16),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 16,
                vertical: isTablet ? 16 : 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: GoogleFonts.poppins(color: Colors.white),
                      maxLines: isLandscape ? 2 : 1,
                      decoration: InputDecoration(
                        hintText: 'Pregunta sobre tu sistema de domótica...',
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.white38,
                          fontSize: isTablet ? 16 : 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 20 : 16,
                          vertical: isTablet ? 16 : 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.tealAccent, Colors.cyanAccent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: _isChatLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.send, color: Colors.white),
                      onPressed: _isChatLoading ? null : _sendMessage,
                      padding: EdgeInsets.all(isTablet ? 16 : 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.tealAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: Colors.tealAccent,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '¡Hola! Soy tu asistente de IA',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pregúntame sobre tu sistema de domótica,\nlos sensores, o genera un análisis de datos.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white60,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ).animate().fadeIn(duration: 600.ms),
    );
  }

  Widget _buildMessageBubble(Map<String, String> msg, bool isUser, bool isTablet) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: isTablet ? 16 : 12,
          left: isUser ? (isTablet ? 100 : 60) : 0,
          right: isUser ? 0 : (isTablet ? 100 : 60),
        ),
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: isUser
              ? Colors.tealAccent.withOpacity(0.2)
              : const Color(0xFF16213E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
          ),
          border: Border.all(
            color: isUser ? Colors.tealAccent.withOpacity(0.3) : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isUser ? Icons.person : Icons.smart_toy_rounded,
                  color: isUser ? Colors.tealAccent : Colors.blueAccent,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  isUser ? 'Tú' : 'Asistente IA',
                  style: GoogleFonts.poppins(
                    color: isUser ? Colors.tealAccent : Colors.blueAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isUser ? msg['user']! : msg['ai']!,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isTablet ? 16 : 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(
          begin: isUser ? 0.2 : -0.2,
          duration: 300.ms,
        );
  }
}
