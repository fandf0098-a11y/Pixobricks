import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/aiIntegrations/chat_completion_service.dart';

class ChatConfig {
  final String provider;
  final String model;
  final bool streaming;

  const ChatConfig({
    required this.provider,
    required this.model,
    this.streaming = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatConfig &&
          provider == other.provider &&
          model == other.model &&
          streaming == other.streaming;

  @override
  int get hashCode => provider.hashCode ^ model.hashCode ^ streaming.hashCode;
}

class ChatState {
  final String response;
  final dynamic fullResponse;
  final bool isLoading;
  final Exception? error;

  const ChatState({
    this.response = '',
    this.fullResponse,
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    String? response,
    dynamic fullResponse,
    bool? isLoading,
    Exception? error,
    bool clearError = false,
  }) {
    return ChatState(
      response: response ?? this.response,
      fullResponse: fullResponse ?? this.fullResponse,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String provider;
  final String model;
  final bool streaming;

  ChatNotifier({
    required this.provider,
    required this.model,
    this.streaming = true,
  }) : super(const ChatState());

  Future<void> sendMessage(
    List<Map<String, dynamic>> messages, {
    Map<String, dynamic> parameters = const {},
  }) async {
    state = ChatState(
      response: '',
      fullResponse: streaming ? <Map<String, dynamic>>[] : null,
      isLoading: true,
    );

    try {
      if (streaming) {
        await getStreamingChatCompletion(
          provider,
          model,
          messages,
          onChunk: (chunk) {
            final chunks = List<Map<String, dynamic>>.from(
              state.fullResponse as List? ?? [],
            )..add(chunk);
            final content =
                chunk['choices']?[0]?['delta']?['content'] as String?;
            state = state.copyWith(
              fullResponse: chunks,
              response: content != null
                  ? state.response + content
                  : state.response,
            );
          },
          onComplete: () => state = state.copyWith(isLoading: false),
          onError: (error) =>
              state = state.copyWith(error: error, isLoading: false),
          parameters: parameters,
        );
      } else {
        final result = await getChatCompletion(
          provider,
          model,
          messages,
          parameters: parameters,
        );
        final content =
            result['choices']?[0]?['message']?['content'] as String? ?? '';
        state = ChatState(
          response: content,
          fullResponse: result,
          isLoading: false,
        );
      }
    } catch (error) {
      state = state.copyWith(
        error: error is Exception ? error : Exception(error.toString()),
        isLoading: false,
      );
    }
  }

  void clearResponse() => state = const ChatState();
}

final chatNotifierProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, ChatConfig>(
      (ref, config) => ChatNotifier(
        provider: config.provider,
        model: config.model,
        streaming: config.streaming,
      ),
    );
