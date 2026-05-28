enum ChatMessageRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.createdAt,
    this.reasoningContent = '',
  });

  final ChatMessageRole role;
  final String content;
  final String reasoningContent;
  final DateTime createdAt;

  bool get isUser => role == ChatMessageRole.user;

  ChatMessage copyWith({
    ChatMessageRole? role,
    String? content,
    String? reasoningContent,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
