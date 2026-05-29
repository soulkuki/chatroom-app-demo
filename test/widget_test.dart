import 'package:chatroom_app_demo/features/chat/chat_api.dart';
import 'package:chatroom_app_demo/features/chat/chat_message.dart';
import 'package:chatroom_app_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatroom_app_demo/features/chat/chat_page.dart';

void main() {
  testWidgets('Chat page shows AI QA controls and mock reply', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('AI问答'), findsOneWidget);
    expect(find.text('深度思考'), findsOneWidget);
    expect(find.text('V4 Flash'), findsOneWidget);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(find.text('发消息或按住说话...'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '你好');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();

    expect(find.text('你好'), findsOneWidget);
    expect(find.text('AI 正在回复...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('我收到了：你好'), findsOneWidget);
  });

  testWidgets('Chat page sends selected model and shows reasoning stream', (
    WidgetTester tester,
  ) async {
    final api = _FakeChatApi();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: ChatPage(api: api),
      ),
    );

    await tester.tap(find.text('V4 Flash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('V4 Pro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('深度思考'));
    await tester.pump();

    await tester.enterText(find.byType(TextField), '比较 9.11 和 9.8');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(api.model, DeepSeekModel.pro.id);
    expect(api.thinkingEnabled, isTrue);
    expect(find.text('思考过程'), findsOneWidget);
    await tester.tap(find.text('思考过程'));
    await tester.pumpAndSettle();

    expect(find.textContaining('先比较整数位'), findsOneWidget);
    expect(find.textContaining('9.8 更大'), findsOneWidget);
  });

  testWidgets('Chat page unfocuses input when answer area is tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byType(TextField));
    await tester.pump();

    EditableText editableText = tester.widget(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.tap(find.textContaining('你好，我是 AI 问答助手'));
    await tester.pump();

    editableText = tester.widget(find.byType(EditableText));
    expect(editableText.focusNode.hasFocus, isFalse);
  });
}

class _FakeChatApi extends ChatApi {
  String? model;
  bool? thinkingEnabled;

  @override
  Stream<ChatStreamChunk> sendMessageStream(
    List<ChatMessage> messages, {
    required String model,
    required bool thinkingEnabled,
  }) async* {
    this.model = model;
    this.thinkingEnabled = thinkingEnabled;
    yield const ChatStreamChunk(reasoningDelta: '先比较整数位，再比较小数位。');
    yield const ChatStreamChunk(contentDelta: '9.8 更大。');
    yield const ChatStreamChunk(finishReason: 'stop');
  }
}
