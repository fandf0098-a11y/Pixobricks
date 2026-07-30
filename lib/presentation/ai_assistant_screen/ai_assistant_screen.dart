import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';
import '../../theme/app_theme.dart';
import '../../providers/chat_notifier.dart';

// ── Message model ────────────────────────────────────────────────────────────

enum MessageRole { user, assistant }

class ChatMessage {
  final MessageRole role;
  final String text;
  final String? imageBase64;
  final String? imageMimeType;
  final DateTime timestamp;
  final bool isStreaming;

  const ChatMessage({
    required this.role,
    required this.text,
    this.imageBase64,
    this.imageMimeType,
    required this.timestamp,
    this.isStreaming = false,
  });

  ChatMessage copyWith({String? text, bool? isStreaming}) => ChatMessage(
    role: role,
    text: text ?? this.text,
    imageBase64: imageBase64,
    imageMimeType: imageMimeType,
    timestamp: timestamp,
    isStreaming: isStreaming ?? this.isStreaming,
  );
}

// ── Suggestion chips ─────────────────────────────────────────────────────────

const List<String> _kSuggestions = [
  "I'm missing this piece",
  "Make the roof taller",
  "Explain step 17",
  "Reduce piece count",
  "Add lights",
  "Can I build this using blue bricks?",
];

const String _kSystemPrompt =
    '''You are BuildVerse AI, an expert brick-building assistant embedded in the BuildVerse app.
You help users with their LEGO and brick-building projects. You understand commands like:
- "I'm missing this piece" — help find alternatives or substitutions
- "Make the roof taller" — suggest structural modifications
- "Explain step 17" — clarify build instructions
- "Reduce piece count" — suggest simplifications
- "Add lights" — advise on lighting integration
- "Can I build this using blue bricks?" — suggest color substitutions

You remember the user's current project context throughout the conversation.
Always reply in a friendly, conversational tone. Be specific and practical.
When discussing pieces, use standard LEGO part terminology when possible.''';

// ── Screen ───────────────────────────────────────────────────────────────────

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();

  final List<ChatMessage> _messages = [];
  XFile? _pendingImage;
  bool _isRecording = false;
  bool _showSuggestions = true;

  late AnimationController _micPulseController;
  late Animation<double> _micPulse;
  late AnimationController _typingController;
  late Animation<double> _typingDot;

  static const _chatConfig = ChatConfig(
    provider: 'GEMINI',
    model: 'gemini/gemini-2.5-flash',
    streaming: true,
  );

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _micPulse = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _typingDot = Tween<double>(begin: 0, end: 1).animate(_typingController);
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _micPulseController.dispose();
    _typingController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  List<Map<String, dynamic>> _buildMessages(
    String userText, {
    String? imageBase64,
    String? imageMimeType,
  }) {
    final history = <Map<String, dynamic>>[
      {'role': 'system', 'content': _kSystemPrompt},
    ];

    for (final msg in _messages) {
      if (msg.role == MessageRole.user) {
        if (msg.imageBase64 != null) {
          history.add({
            'role': 'user',
            'content': [
              {'type': 'text', 'text': msg.text},
              {
                'type': 'image_url',
                'image_url': {
                  'url':
                      'data:${msg.imageMimeType ?? 'image/jpeg'};base64,${msg.imageBase64}',
                },
              },
            ],
          });
        } else {
          history.add({'role': 'user', 'content': msg.text});
        }
      } else {
        history.add({'role': 'assistant', 'content': msg.text});
      }
    }

    // Add current user message
    if (imageBase64 != null) {
      history.add({
        'role': 'user',
        'content': [
          {'type': 'text', 'text': userText},
          {
            'type': 'image_url',
            'image_url': {
              'url':
                  'data:${imageMimeType ?? 'image/jpeg'};base64,$imageBase64',
            },
          },
        ],
      });
    } else {
      history.add({'role': 'user', 'content': userText});
    }

    return history;
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _pendingImage == null) return;

    final trimmed = text.trim().isEmpty ? '(image attached)' : text.trim();
    _inputController.clear();
    _focusNode.unfocus();

    String? imageBase64;
    String? imageMimeType;

    if (_pendingImage != null) {
      final bytes = await _pendingImage!.readAsBytes();
      imageBase64 = base64Encode(bytes);
      imageMimeType = _pendingImage!.mimeType ?? 'image/jpeg';
    }

    final userMsg = ChatMessage(
      role: MessageRole.user,
      text: trimmed,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _pendingImage = null;
      _showSuggestions = false;
    });
    _scrollToBottom();

    final messages = _buildMessages(
      trimmed,
      imageBase64: imageBase64,
      imageMimeType: imageMimeType,
    );

    // Add placeholder assistant message for streaming
    final assistantPlaceholder = ChatMessage(
      role: MessageRole.assistant,
      text: '',
      timestamp: DateTime.now(),
      isStreaming: true,
    );
    setState(() => _messages.add(assistantPlaceholder));
    _scrollToBottom();

    await ref
        .read(chatNotifierProvider(_chatConfig).notifier)
        .sendMessage(
          messages,
          parameters: {'temperature': 0.7, 'max_tokens': 1024},
        );
  }

  void _onSuggestionTap(String suggestion) {
    _inputController.text = suggestion;
    _sendMessage(suggestion);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        setState(() => _pendingImage = picked);
      }
    } catch (_) {
      Fluttertoast.showToast(
        msg: 'Could not pick image',
        backgroundColor: AppTheme.error,
      );
    }
  }

  void _toggleRecording() {
    setState(() => _isRecording = !_isRecording);
    if (_isRecording) {
      // Voice recording UI active — in a real app, use speech_to_text or record package
      // For now, show a toast and auto-stop after 3s
      Fluttertoast.showToast(
        msg: 'Voice input: speak now…',
        backgroundColor: AppTheme.primary,
        toastLength: Toast.LENGTH_SHORT,
      );
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isRecording) {
          setState(() => _isRecording = false);
          Fluttertoast.showToast(
            msg: 'Voice input captured',
            backgroundColor: AppTheme.success,
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      });
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chatState = ref.watch(chatNotifierProvider(_chatConfig));

    // Listen for streaming updates
    ref.listen<ChatState>(chatNotifierProvider(_chatConfig), (prev, next) {
      if (next.error != null) {
        Fluttertoast.showToast(
          msg: next.error.toString(),
          backgroundColor: AppTheme.error,
        );
        // Remove placeholder on error
        if (_messages.isNotEmpty &&
            _messages.last.role == MessageRole.assistant &&
            _messages.last.isStreaming) {
          setState(() => _messages.removeLast());
        }
        return;
      }

      // Update streaming placeholder
      if (_messages.isNotEmpty &&
          _messages.last.role == MessageRole.assistant) {
        setState(() {
          _messages[_messages.length - 1] = _messages.last.copyWith(
            text: next.response,
            isStreaming: next.isLoading,
          );
        });
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(isDark),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? AppTheme.backgroundGradientDark
              : AppTheme.backgroundGradientLight,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : _buildMessageList(isDark, chatState),
              ),
              if (_showSuggestions && _messages.isEmpty)
                _buildSuggestionChips(isDark),
              _buildInputBar(isDark, chatState),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark
                ? Colors.white.withAlpha(13)
                : AppTheme.primary.withAlpha(15),
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.smart_toy_rounded,
            color: AppTheme.primary,
            size: 22,
          ),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BuildVerse AI',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1730),
            ),
          ),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Powered by Gemini',
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withAlpha(128)
                      : const Color(0xFF4A4870).withAlpha(153),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            setState(() {
              _messages.clear();
              _showSuggestions = true;
            });
            ref
                .read(chatNotifierProvider(_chatConfig).notifier)
                .clearResponse();
          },
          icon: Icon(
            Icons.refresh_rounded,
            color: isDark
                ? Colors.white.withAlpha(180)
                : const Color(0xFF4A4870),
            size: 20,
          ),
          tooltip: 'New conversation',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(80),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your Building Assistant',
              style: GoogleFonts.manrope(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1730),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask me anything about your current build.\nI remember your project context.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark
                    ? Colors.white.withAlpha(153)
                    : const Color(0xFF4A4870).withAlpha(180),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionChips(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Try asking:',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withAlpha(128)
                    : const Color(0xFF4A4870).withAlpha(153),
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kSuggestions.map((s) {
              return GestureDetector(
                onTap: () => _onSuggestionTap(s),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.primary.withAlpha(30)
                        : AppTheme.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.primary.withAlpha(60),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.manrope(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.primaryLight : AppTheme.primary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark, ChatState chatState) {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(4.w, 8, 4.w, 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _buildMessageBubble(msg, isDark);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    final isUser = msg.role == MessageRole.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: 75.w),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppTheme.primary
                    : (isDark
                          ? AppTheme.surfaceVariantDark
                          : AppTheme.surfaceVariantLight),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 40 : 15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.imageBase64 != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        base64Decode(msg.imageBase64!),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        semanticLabel: 'Uploaded image for building question',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (msg.isStreaming && msg.text.isEmpty)
                    _buildTypingIndicator(isDark)
                  else
                    Text(
                      msg.text,
                      style: GoogleFonts.manrope(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: isUser
                            ? Colors.white
                            : (isDark
                                  ? Colors.white.withAlpha(230)
                                  : const Color(0xFF1A1730)),
                        height: 1.5,
                      ),
                    ),
                  if (msg.isStreaming && msg.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildStreamingCursor(),
                    ),
                ],
              ),
            ),
          ),
          if (isUser) ...[
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(left: 8, bottom: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.surfaceVariantDark
                    : AppTheme.surfaceVariantLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person_rounded,
                color: isDark ? Colors.white.withAlpha(180) : AppTheme.primary,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return AnimatedBuilder(
      animation: _typingDot,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i / 3;
            final value = (_typingDot.value - delay).clamp(0.0, 1.0);
            final opacity = (value < 0.5 ? value * 2 : (1 - value) * 2).clamp(
              0.3,
              1.0,
            );
            return Container(
              margin: const EdgeInsets.only(right: 4),
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha((opacity * 200).round())
                    : AppTheme.primary.withAlpha((opacity * 200).round()),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildStreamingCursor() {
    return AnimatedBuilder(
      animation: _typingDot,
      builder: (context, _) {
        final opacity =
            (_typingDot.value < 0.5
                    ? _typingDot.value * 2
                    : (1 - _typingDot.value) * 2)
                .clamp(0.0, 1.0);
        return Container(
          width: 2,
          height: 14,
          decoration: BoxDecoration(
            color: AppTheme.secondary.withAlpha((opacity * 255).round()),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      },
    );
  }

  Widget _buildInputBar(bool isDark, ChatState chatState) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        3.w,
        8,
        3.w,
        MediaQuery.of(context).padding.bottom + 80,
      ),
      child: Column(
        children: [
          if (_pendingImage != null) _buildImagePreview(isDark),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(18)
                      : Colors.white.withAlpha(200),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withAlpha(25)
                        : AppTheme.primary.withAlpha(40),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 50 : 15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Image attach button
                    _buildIconButton(
                      icon: Icons.image_outlined,
                      onTap: chatState.isLoading ? null : _pickImage,
                      isDark: isDark,
                      tooltip: 'Attach image',
                    ),
                    // Text field
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _focusNode,
                        maxLines: 4,
                        minLines: 1,
                        enabled: !chatState.isLoading,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (v) => _sendMessage(v),
                        style: GoogleFonts.manrope(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? Colors.white.withAlpha(230)
                              : const Color(0xFF1A1730),
                        ),
                        decoration: InputDecoration(
                          hintText: _isRecording
                              ? 'Listening…'
                              : 'Ask about your build…',
                          hintStyle: GoogleFonts.manrope(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white.withAlpha(80)
                                : const Color(0xFF4A4870).withAlpha(120),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    // Mic button
                    _buildMicButton(isDark, chatState.isLoading),
                    // Send button
                    _buildSendButton(isDark, chatState.isLoading),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FutureBuilder<Uint8List>(
              future: _pendingImage!.readAsBytes(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Container(
                    width: 70,
                    height: 70,
                    color: isDark
                        ? AppTheme.surfaceVariantDark
                        : AppTheme.surfaceVariantLight,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return Image.memory(
                  snapshot.data!,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  semanticLabel: 'Image selected for upload',
                );
              },
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () => setState(() => _pendingImage = null),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: AppTheme.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    required bool isDark,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
          child: Icon(
            icon,
            size: 22,
            color: onTap == null
                ? (isDark
                      ? Colors.white.withAlpha(50)
                      : const Color(0xFF4A4870).withAlpha(80))
                : (isDark
                      ? Colors.white.withAlpha(160)
                      : const Color(0xFF4A4870).withAlpha(180)),
          ),
        ),
      ),
    );
  }

  Widget _buildMicButton(bool isDark, bool isLoading) {
    return GestureDetector(
      onTap: isLoading ? null : _toggleRecording,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
        child: _isRecording
            ? AnimatedBuilder(
                animation: _micPulse,
                builder: (context, child) => Transform.scale(
                  scale: _micPulse.value,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.error.withAlpha(200),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              )
            : Icon(
                Icons.mic_none_rounded,
                size: 22,
                color: isLoading
                    ? (isDark
                          ? Colors.white.withAlpha(50)
                          : const Color(0xFF4A4870).withAlpha(80))
                    : (isDark
                          ? Colors.white.withAlpha(160)
                          : const Color(0xFF4A4870).withAlpha(180)),
              ),
      ),
    );
  }

  Widget _buildSendButton(bool isDark, bool isLoading) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: GestureDetector(
        onTap: isLoading ? null : () => _sendMessage(_inputController.text),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: isLoading ? null : AppTheme.primaryGradient,
            color: isLoading
                ? (isDark
                      ? Colors.white.withAlpha(25)
                      : const Color(0xFF4A4870).withAlpha(30))
                : null,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isLoading
                ? []
                : [
                    BoxShadow(
                      color: AppTheme.primary.withAlpha(80),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.primary,
                    ),
                  ),
                )
              : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
