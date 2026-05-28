import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'chat_message.dart';

class DeepSeekModel {
  const DeepSeekModel({required this.id, required this.label});

  final String id;
  final String label;

  static const flash = DeepSeekModel(
    id: 'deepseek-v4-flash',
    label: 'V4 Flash',
  );

  static const pro = DeepSeekModel(id: 'deepseek-v4-pro', label: 'V4 Pro');

  static const values = [flash, pro];
}

class ChatStreamChunk {
  const ChatStreamChunk({
    this.contentDelta = '',
    this.reasoningDelta = '',
    this.finishReason,
  });

  final String contentDelta;
  final String reasoningDelta;
  final String? finishReason;
}

class ChatApi {
  ChatApi({
    this.apiKey = '',
    this.baseUrl = 'https://api.deepseek.com',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String baseUrl;
  final http.Client _client;

  Stream<ChatStreamChunk> sendMessageStream(
    List<ChatMessage> messages, {
    required String model,
    required bool thinkingEnabled,
  }) async* {
    final normalizedMessages = _normalizeMessages(messages);
    if (normalizedMessages.isEmpty) {
      throw ArgumentError('消息内容不能为空');
    }

    if (apiKey.trim().isEmpty) {
      yield* _mockReply(normalizedMessages.last['content'] as String);
      return;
    }

    final request =
        http.Request(
            'POST',
            Uri.parse('${_trimTrailingSlashes(baseUrl)}/chat/completions'),
          )
          ..headers.addAll({
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          })
          ..body = jsonEncode({
            'model': model,
            'messages': normalizedMessages,
            'stream': true,
            'thinking': {'type': thinkingEnabled ? 'enabled' : 'disabled'},
            if (thinkingEnabled) 'reasoning_effort': 'high',
          });

    final response = await _client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw Exception(_formatHttpError(response.statusCode, body));
    }

    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final chunk = parseSseLine(line);
      if (chunk != null) {
        yield chunk;
      }
    }
  }

  static ChatStreamChunk? parseSseLine(String line) {
    final trimmedLine = line.trim();
    if (trimmedLine.isEmpty || !trimmedLine.startsWith('data:')) {
      return null;
    }

    final data = trimmedLine.substring(5).trim();
    if (data.isEmpty || data == '[DONE]') {
      return null;
    }

    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }

    final choice = choices.first;
    if (choice is! Map<String, dynamic>) {
      return null;
    }

    final delta = choice['delta'];
    final finishReason = choice['finish_reason'];
    String contentDelta = '';
    String reasoningDelta = '';

    if (delta is Map<String, dynamic>) {
      final content = delta['content'];
      if (content is String) {
        contentDelta = content;
      }

      final reasoningContent = delta['reasoning_content'];
      if (reasoningContent is String) {
        reasoningDelta = reasoningContent;
      }
    }

    return ChatStreamChunk(
      contentDelta: contentDelta,
      reasoningDelta: reasoningDelta,
      finishReason: finishReason is String ? finishReason : null,
    );
  }

  List<Map<String, String>> _normalizeMessages(List<ChatMessage> messages) {
    final firstUserIndex = messages.indexWhere((message) => message.isUser);
    if (firstUserIndex == -1) {
      return const [];
    }

    return messages
        .skip(firstUserIndex)
        .where((message) => message.content.trim().isNotEmpty)
        .map(
          (message) => {
            'role': message.isUser ? 'user' : 'assistant',
            'content': message.content.trim(),
          },
        )
        .toList(growable: false);
  }

  Stream<ChatStreamChunk> _mockReply(String message) async* {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    yield ChatStreamChunk(contentDelta: '我收到了：$message');
    await Future<void>.delayed(const Duration(milliseconds: 180));
    yield const ChatStreamChunk(
      contentDelta: '\n\n当前是本地模拟回复。配置 DEEPSEEK_API_KEY 后会调用 DeepSeek。',
    );
    yield const ChatStreamChunk(finishReason: 'stop');
  }

  String _formatHttpError(int statusCode, String body) {
    if (body.trim().isEmpty) {
      return '请求失败：$statusCode';
    }

    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic>) {
        final error = data['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return '请求失败：$statusCode，$message';
          }
        }
      }
    } catch (_) {
      // Fall through to the compact body preview below.
    }

    return '请求失败：$statusCode，$body';
  }
}

String _trimTrailingSlashes(String value) {
  return value.trim().replaceFirst(RegExp(r'/+$'), '');
}
