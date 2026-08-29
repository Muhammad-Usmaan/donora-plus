/// Abstract interface for the Donora+ AI chatbot.
///
/// Implement this for different backend providers (Qwen/Alibaba Cloud,
/// OpenAI, etc.) without changing the call sites.
abstract class ChatbotService {
  /// Sends a user [message] and returns the bot's text response.
  ///
  /// [conversationHistory] is an optional list of prior messages
  /// (each a map with 'role' and 'content' keys) to maintain context.
  ///
  /// [userContext] is an optional human-readable summary of the current
  /// user's profile (name, blood group, city, role, etc.) injected into
  /// the system prompt so the bot can personalise its answers.
  Future<String> sendMessage(
    String message, {
    List<Map<String, String>>? conversationHistory,
    String? userContext,
  });
}
