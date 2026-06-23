import 'package:cloud_functions/cloud_functions.dart';

/// A single turn in the design consultation.
class ChatTurn {
  final String role; // 'user' | 'assistant'
  final String text;

  /// Reference images as data URLs (data:image/...;base64,...). Only on user
  /// turns, and only sent to the backend — not displayed back from here.
  final List<String> images;

  const ChatTurn({
    required this.role,
    required this.text,
    this.images = const [],
  });

  Map<String, dynamic> toWire() => {'role': role, 'text': text, 'images': images};
}

/// Result of generating a concept image.
class ConceptResult {
  final String imageBase64; // raw base64 png (no data: prefix)
  final String summary;
  final String placement;
  final String style;
  final String size;
  final String colors;

  const ConceptResult({
    required this.imageBase64,
    required this.summary,
    required this.placement,
    required this.style,
    required this.size,
    required this.colors,
  });
}

/// Client wrapper around the OpenAI-proxy Cloud Functions. The API key lives on
/// the server; this just passes the conversation through.
class AiService {
  AiService(this._functions);
  final FirebaseFunctions _functions;

  /// Sends the conversation and returns the assistant's next reply.
  Future<String> chat({
    required String appointmentId,
    required List<ChatTurn> messages,
  }) async {
    final res = await _functions.httpsCallable('aiChat').call<Map>({
      'appointmentId': appointmentId,
      'messages': messages.map((m) => m.toWire()).toList(),
    });
    return (res.data['reply'] as String?) ?? '';
  }

  /// Generates the concept image + artist brief from the conversation.
  Future<ConceptResult> generateConcept({
    required String appointmentId,
    required List<ChatTurn> messages,
    required List<String> referenceImages,
  }) async {
    final res = await _functions.httpsCallable('aiGenerateConcept').call<Map>({
      'appointmentId': appointmentId,
      'messages': messages.map((m) => m.toWire()).toList(),
      'referenceImages': referenceImages,
    });
    final d = res.data;
    return ConceptResult(
      imageBase64: (d['conceptImageBase64'] as String?) ?? '',
      summary: (d['summary'] as String?) ?? '',
      placement: (d['placement'] as String?) ?? '',
      style: (d['style'] as String?) ?? '',
      size: (d['size'] as String?) ?? '',
      colors: (d['colors'] as String?) ?? '',
    );
  }
}
