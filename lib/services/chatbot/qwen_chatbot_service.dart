import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/env_config.dart';
import 'chatbot_service.dart';

/// Concrete chatbot implementation backed by Alibaba Cloud's Qwen model.
///
/// Builds a dynamic system prompt that includes the Donora+ app context,
/// the current user's profile summary, and strict brevity instructions.
class QwenChatbotService implements ChatbotService {
  QwenChatbotService({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const String _apiEndpoint =
      'https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions';

  // ── Static app-context block (shared across all users) ──────────────────
  static const String _appContext = '''
You are "Donora Assistant", the in-app AI helper for Donora+, a blood donation
matching platform built for Pakistan.

App features you can help with:
- BLOOD REQUESTS: Users can post urgent or non-urgent blood requests specifying
  blood type, units needed, hospital, and deadline.
- DONOR MAP: A live map showing nearby verified donors and blood banks using
  GPS and OpenStreetMap.
- IN-APP CHAT: Direct messaging between seekers and donors to coordinate
  donations.
- VERIFICATION: A badge system — donors submit documents to become verified,
  which increases trust and match priority.
- DONOR SEARCH: Filter donors by blood group, city, distance, and verification
  status.
- PUSH NOTIFICATIONS: Alerts for urgent blood requests nearby, new messages,
  and request updates.
- COOLDOWN TIMER: 90-day enforced rest period between donations, tracked
  automatically.
- DUAL ROLE: Every user can switch between "seeker" (needs blood) and "donor"
  (gives blood) modes.
- CHATBOT: You — the AI assistant that answers questions about blood donation,
  eligibility, app features, and the user's personal donation status.
''';

  // ── Response-style instructions ──────────────────────────────────────────
  static const String _styleRules = '''
RESPONSE STYLE — follow strictly:
- Be EXTREMELY brief. Answer in 1-3 short sentences unless the user explicitly
  asks for more detail.
- Answer ONLY what is asked. Do not volunteer extra information, tips, or
  follow-up suggestions unless the user requests them.
- When the user's profile answers their question (e.g. "can I donate?" and
  they are on cooldown), state the fact and stop.
- Use plain text only. No markdown, no bullet points, no headers, no emojis.
- For medical questions, say "Please consult a doctor for medical advice."
  and nothing more.
- If you don't know the answer, say so briefly. Do not guess or make up
  information.
- Do NOT greet the user or add pleasantries unless they greet you first.
''';

  // ── Dynamic system prompt builder ───────────────────────────────────────
  String _buildSystemPrompt(String? userContext) {
    final buffer = StringBuffer()
      ..writeln(_appContext)
      ..writeln();

    if (userContext != null && userContext.isNotEmpty) {
      buffer
        ..writeln('CURRENT USER PROFILE:')
        ..writeln(userContext)
        ..writeln()
        ..writeln(
            'Use this profile to personalise answers. '
            'For example, if the user asks "Can I donate?", check their '
            'cooldown status and blood group before answering.')
        ..writeln();
    }

    buffer.writeln(_styleRules);
    return buffer.toString();
  }

  @override
  Future<String> sendMessage(
    String message, {
    List<Map<String, String>>? conversationHistory,
    String? userContext,
  }) async {
    if (EnvConfig.qwenApiKey.isEmpty) {
      throw ChatbotApiKeyException();
    }

    final messages = <Map<String, String>>[
      {
        'role': 'system',
        'content': _buildSystemPrompt(userContext),
      },
      ...?conversationHistory,
      {'role': 'user', 'content': message},
    ];

    final response = await _http.post(
      Uri.parse(_apiEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${EnvConfig.qwenApiKey}',
      },
      body: jsonEncode({
        'model': 'qwen-plus',
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 256,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Chatbot API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>;
    final botMessage = (choices.first as Map<String, dynamic>)['message']
        as Map<String, dynamic>;
    return botMessage['content'] as String;
  }
}

/// Thrown when the QWEN_API_KEY is not configured.
class ChatbotApiKeyException implements Exception {
  @override
  String toString() =>
      'Chatbot is not configured. Please set QWEN_API_KEY in your environment.';
}
