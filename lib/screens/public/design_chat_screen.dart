import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ai_service.dart';
import '../../services/services.dart';
import 'booking_success_screen.dart';

/// Shown right after a booking is created. An AI assistant chats with the client
/// to nail down the design (idea, style, size, placement, references), then
/// generates a concept image. Everything is saved server-side for the artist.
class DesignChatScreen extends StatefulWidget {
  const DesignChatScreen({
    super.key,
    required this.appointmentId,
    required this.buildSuccess,
  });

  final String appointmentId;

  /// Builds the booking confirmation, injecting the conversation so the success
  /// screen can offer to generate a concept image from it.
  final BookingSuccessScreen Function(
      List<ChatTurn> messages, List<String> referenceImages) buildSuccess;

  @override
  State<DesignChatScreen> createState() => _DesignChatScreenState();
}

class _UiMessage {
  final String role; // user | assistant
  final String text;
  final List<Uint8List> images;
  _UiMessage(this.role, this.text, {this.images = const []});
}

class _DesignChatScreenState extends State<DesignChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  final List<_UiMessage> _ui = [];
  final List<ChatTurn> _wire = []; // history sent to the model
  final List<String> _pendingImages = []; // data URLs staged for next send
  final List<Uint8List> _pendingBytes = [];
  final List<String> _allReferenceImages = []; // every ref shared, for generation

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _ui.add(_UiMessage(
      'assistant',
      "Hi! I'll help plan your tattoo so your artist has everything ready. "
      "To start — what's the idea or subject you have in mind? Feel free to "
      "attach reference photos too.",
    ));
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _attach() async {
    final files = await _picker.pickMultiImage(imageQuality: 70, limit: 4);
    for (final f in files) {
      if (_pendingImages.length >= 4) break;
      final bytes = await f.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image too large (max 5 MB).')),
          );
        }
        continue;
      }
      final mime = f.mimeType ?? 'image/png';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      setState(() {
        _pendingImages.add(dataUrl);
        _pendingBytes.add(bytes);
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty && _pendingImages.isEmpty) return;
    if (_sending) return;

    final images = List<String>.from(_pendingImages);
    final bytes = List<Uint8List>.from(_pendingBytes);
    _allReferenceImages.addAll(images);

    setState(() {
      _ui.add(_UiMessage('user', text, images: bytes));
      _wire.add(ChatTurn(role: 'user', text: text, images: images));
      _input.clear();
      _pendingImages.clear();
      _pendingBytes.clear();
      _sending = true;
    });
    _scrollToEnd();

    try {
      final reply = await ai.chat(
        appointmentId: widget.appointmentId,
        messages: _wire,
      );
      setState(() {
        _ui.add(_UiMessage('assistant', reply));
        _wire.add(ChatTurn(role: 'assistant', text: reply));
      });
    } catch (e) {
      setState(() => _ui.add(_UiMessage('assistant',
          "Sorry — I had trouble responding. You can still finish booking and "
          "your artist will follow up.")));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => widget.buildSuccess(_wire, _allReferenceImages),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design your tattoo'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _ui.length + (_sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _ui.length) return const _TypingBubble();
                    return _Bubble(_ui[i]);
                  },
                ),
              ),
              if (_pendingBytes.isNotEmpty) _pendingStrip(),
              const Divider(height: 1),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pendingStrip() => SizedBox(
        height: 72,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _pendingBytes.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_pendingBytes[i],
                      width: 56, height: 56, fit: BoxFit.cover),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _pendingBytes.removeAt(i);
                      _pendingImages.removeAt(i);
                    }),
                    child: const CircleAvatar(
                      radius: 9,
                      backgroundColor: Colors.black87,
                      child: Icon(Icons.close, size: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _composer() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _sending ? null : _attach,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                tooltip: 'Attach reference photos',
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Describe your idea…',
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _finish,
              child: const Text('Finish'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble(this.msg);
  final _UiMessage msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? scheme.primary : const Color(0xFF1B1B22),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (msg.images.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final b in msg.images)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(b,
                          width: 120, height: 120, fit: BoxFit.cover),
                    ),
                ],
              ),
            if (msg.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: msg.images.isNotEmpty ? 8 : 0),
                child: Text(
                  msg.text,
                  style: TextStyle(
                    color: isUser ? Colors.black : Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1B22),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
}
