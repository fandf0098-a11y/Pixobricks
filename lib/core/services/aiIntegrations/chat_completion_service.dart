import 'dart:convert';
import 'package:dio/dio.dart';
import '../ai_client.dart';

const String _chatCompletionEndpoint = String.fromEnvironment(
  'AWS_LAMBDA_CHAT_COMPLETION_URL',
);

Future<Map<String, dynamic>> getChatCompletion(
  String provider,
  String model,
  List<Map<String, dynamic>> messages, {
  Map<String, dynamic> parameters = const {},
}) async {
  final payload = {
    'provider': provider,
    'model': model,
    'messages': messages,
    'stream': false,
    'parameters': parameters,
  };
  return await callLambdaFunction(_chatCompletionEndpoint, payload);
}

Future<void> getStreamingChatCompletion(
  String provider,
  String model,
  List<Map<String, dynamic>> messages, {
  required void Function(Map<String, dynamic> chunk) onChunk,
  required void Function() onComplete,
  required void Function(Exception error) onError,
  Map<String, dynamic> parameters = const {},
}) async {
  final payload = {
    'provider': provider,
    'model': model,
    'messages': messages,
    'stream': true,
    'parameters': parameters,
  };

  try {
    final dio = Dio();
    final response = await dio.post<ResponseBody>(
      _chatCompletionEndpoint,
      data: payload,
      options: Options(
        headers: {'Content-Type': 'application/json'},
        responseType: ResponseType.stream,
      ),
    );

    String buffer = '';
    await for (final chunk in response.data!.stream) {
      buffer += utf8.decode(chunk);
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (line.startsWith('data: ')) {
          try {
            final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
            if (data['type'] == 'chunk' && data['chunk'] != null) {
              onChunk(data['chunk'] as Map<String, dynamic>);
            } else if (data['type'] == 'done') {
              onComplete();
            } else if (data['type'] == 'error') {
              print(
                'Lambda Function Error: ${data['error']}, details: ${data['details']}',
              );
              onError(Exception(data['error']));
            }
          } catch (_) {}
        }
      }
    }
  } catch (error) {
    print('Streaming error: $error');
    onError(error is Exception ? error : Exception(error.toString()));
  }
}
