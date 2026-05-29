import 'package:flutter/material.dart';

import 'chat_api.dart';
import 'chat_message.dart';

class ChatPage extends StatefulWidget {
  ChatPage({super.key, ChatApi? api}) : api = api ?? ChatApi();

  final ChatApi api;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      role: ChatMessageRole.assistant,
      content: '你好，我是 AI 问答助手。你可以先发送一条消息试试。',
      createdAt: DateTime.now(),
    ),
  ];

  DeepSeekModel _selectedModel = DeepSeekModel.flash;
  bool _thinkingEnabled = false;
  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) {
      return;
    }

    final userMessage = ChatMessage(
      role: ChatMessageRole.user,
      content: text,
      createdAt: DateTime.now(),
    );
    final assistantMessage = ChatMessage(
      role: ChatMessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messages.add(assistantMessage);
      _isSending = true;
      _textController.clear();
    });
    _scrollToBottom();

    final assistantIndex = _messages.length - 1;
    String finishReason = 'stop';

    try {
      await for (final chunk in widget.api.sendMessageStream(
        List<ChatMessage>.of(_messages.take(assistantIndex)),
        model: _selectedModel.id,
        thinkingEnabled: _thinkingEnabled,
      )) {
        if (!mounted) {
          return;
        }

        if (chunk.finishReason != null) {
          finishReason = chunk.finishReason!;
        }

        if (chunk.contentDelta.isEmpty && chunk.reasoningDelta.isEmpty) {
          continue;
        }

        setState(() {
          final current = _messages[assistantIndex];
          _messages[assistantIndex] = current.copyWith(
            content: current.content + chunk.contentDelta,
            reasoningContent: current.reasoningContent + chunk.reasoningDelta,
          );
        });
        _scrollToBottom();
      }

      if (!mounted) {
        return;
      }

      final finishMessage = _finishReasonMessage(finishReason);
      if (finishMessage != null) {
        setState(() {
          final current = _messages[assistantIndex];
          _messages[assistantIndex] = current.copyWith(
            content: '${current.content}\n\n$finishMessage'.trim(),
          );
        });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        final current = _messages[assistantIndex];
        final prefix = current.content.trim().isEmpty
            ? ''
            : '${current.content.trim()}\n\n';
        _messages[assistantIndex] = current.copyWith(
          content: '$prefix发送失败：${_formatSendError(error)}',
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  String _formatSendError(Object error) {
    final message = error.toString();
    final normalizedMessage = message.toLowerCase();

    if (normalizedMessage.contains('failed host lookup') ||
        normalizedMessage.contains('nodename nor servname provided') ||
        normalizedMessage.contains('socketexception')) {
      return '无法解析 api.deepseek.com。请检查 iPhone 当前网络、DNS、代理/VPN，或切换到可访问 DeepSeek 的 Wi-Fi/蜂窝网络后重试。';
    }

    return message;
  }

  String? _finishReasonMessage(String finishReason) {
    switch (finishReason) {
      case 'length':
        return '回答已达到长度限制。';
      case 'content_filter':
        return '回答因内容策略被过滤。';
      case 'insufficient_system_resource':
        return '服务端资源不足，本次回复被中断。';
      default:
        return null;
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(title: const Text('AI问答'), centerTitle: false),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(
                      message: _messages[index],
                      isStreaming: _isSending && index == _messages.length - 1,
                      showReasoning: _thinkingEnabled,
                    );
                  },
                ),
              ),
            ),
            _ChatInputBar(
              controller: _textController,
              isSending: _isSending,
              selectedModel: _selectedModel,
              thinkingEnabled: _thinkingEnabled,
              onModelChanged: (model) {
                setState(() {
                  _selectedModel = model;
                });
              },
              onThinkingChanged: (enabled) {
                setState(() {
                  _thinkingEnabled = enabled;
                });
              },
              onSubmitted: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isStreaming,
    required this.showReasoning,
  });

  final ChatMessage message;
  final bool isStreaming;
  final bool showReasoning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alignment = message.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final bubbleColor = message.isUser
        ? colorScheme.primary
        : colorScheme.surfaceContainerHighest;
    final textColor = message.isUser
        ? colorScheme.onPrimary
        : colorScheme.onSurface;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(message.isUser ? 16 : 4),
      bottomRight: Radius.circular(message.isUser ? 4 : 16),
    );

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: borderRadius,
        ),
        child: _BubbleContent(
          message: message,
          isStreaming: isStreaming,
          showReasoning: showReasoning,
          textColor: textColor,
        ),
      ),
    );
  }
}

class _BubbleContent extends StatelessWidget {
  const _BubbleContent({
    required this.message,
    required this.isStreaming,
    required this.showReasoning,
    required this.textColor,
  });

  final ChatMessage message;
  final bool isStreaming;
  final bool showReasoning;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Text(
        message.content,
        style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
      );
    }

    final hasReasoning = message.reasoningContent.trim().isNotEmpty;
    final hasContent = message.content.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showReasoning && hasReasoning) ...[
          _ReasoningPanel(reasoningContent: message.reasoningContent),
          const SizedBox(height: 8),
        ],
        Text(
          hasContent
              ? message.content
              : isStreaming && hasReasoning
              ? '正在组织回答...'
              : 'AI 正在回复...',
          style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
        ),
      ],
    );
  }
}

class _ReasoningPanel extends StatelessWidget {
  const _ReasoningPanel({required this.reasoningContent});

  final String reasoningContent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        initiallyExpanded: false,
        dense: true,
        title: Text(
          '思考过程',
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              reasoningContent,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.controller,
    required this.isSending,
    required this.selectedModel,
    required this.thinkingEnabled,
    required this.onModelChanged,
    required this.onThinkingChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool isSending;
  final DeepSeekModel selectedModel;
  final bool thinkingEnabled;
  final ValueChanged<DeepSeekModel> onModelChanged;
  final ValueChanged<bool> onThinkingChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ThinkingToggle(
                  enabled: thinkingEnabled,
                  isDisabled: isSending,
                  onChanged: onThinkingChanged,
                ),
                const SizedBox(width: 8),
                _ModelSelector(
                  selectedModel: selectedModel,
                  isDisabled: isSending,
                  onChanged: onModelChanged,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InputField(
              controller: controller,
              isSending: isSending,
              onSubmitted: onSubmitted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingToggle extends StatelessWidget {
  const _ThinkingToggle({
    required this.enabled,
    required this.isDisabled,
    required this.onChanged,
  });

  final bool enabled;
  final bool isDisabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foregroundColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;
    final borderColor = enabled
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final backgroundColor = enabled
        ? colorScheme.primaryContainer.withValues(alpha: 0.38)
        : colorScheme.surface;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: isDisabled ? null : () => onChanged(!enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 16, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              '深度思考',
              style: TextStyle(
                color: foregroundColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelSelector extends StatelessWidget {
  const _ModelSelector({
    required this.selectedModel,
    required this.isDisabled,
    required this.onChanged,
  });

  final DeepSeekModel selectedModel;
  final bool isDisabled;
  final ValueChanged<DeepSeekModel> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<DeepSeekModel>(
      enabled: !isDisabled,
      initialValue: selectedModel,
      tooltip: '选择模型',
      onSelected: onChanged,
      itemBuilder: (context) {
        return DeepSeekModel.values
            .map(
              (model) => PopupMenuItem<DeepSeekModel>(
                value: model,
                child: Text(model.label),
              ),
            )
            .toList(growable: false);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selectedModel.label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.isSending,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.graphic_eq, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              decoration: const InputDecoration(
                hintText: '发消息或按住说话...',
                border: InputBorder.none,
                isDense: true,
              ),
              onSubmitted: (_) => onSubmitted(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: '发送',
            onPressed: isSending ? null : onSubmitted,
            icon: isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
