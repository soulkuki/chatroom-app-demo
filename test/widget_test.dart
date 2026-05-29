import 'package:chatroom_app_demo/features/chat/chat_api.dart';
import 'package:chatroom_app_demo/features/chat/chat_message.dart';
import 'package:chatroom_app_demo/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatroom_app_demo/features/chat/chat_page.dart';

void main() {
  testWidgets('Chat page shows AI QA controls and mock reply', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('AI问答'), findsOneWidget);
    expect(find.text('深度思考'), findsNothing);
    expect(find.text('V4 Flash'), findsNothing);
    expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
    expect(find.text('有问题，尽管问'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '你好');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();

    expect(find.text('你好'), findsOneWidget);
    expect(find.text('AI 正在回复...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('我收到了：你好'), findsOneWidget);
  });

  testWidgets('Chat page sends default model without reasoning', (
    WidgetTester tester,
  ) async {
    final api = _FakeChatApi();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: ChatPage(api: api),
      ),
    );

    await tester.enterText(find.byType(TextField), '比较 9.11 和 9.8');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(api.model, DeepSeekModel.flash.id);
    expect(api.thinkingEnabled, isFalse);
    expect(find.text('思考过程'), findsNothing);
    expect(find.textContaining('先比较整数位'), findsNothing);
    expect(find.textContaining('9.8 更大'), findsOneWidget);
  });

  testWidgets('Chat page selects assistant answer and copies full answer', (
    WidgetTester tester,
  ) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (methodCall) async {
        switch (methodCall.method) {
          case 'Clipboard.setData':
            final arguments = methodCall.arguments as Map<dynamic, dynamic>;
            clipboardText = arguments['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return <String, dynamic>{'text': clipboardText};
        }

        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(const MyApp());

    await tester.enterText(find.byType(TextField), '你好');
    await tester.tap(find.byTooltip('发送'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    const expectedAnswer =
        '我收到了：你好\n\n当前是本地模拟回复。配置 DEEPSEEK_API_KEY 后会调用 DeepSeek。';

    expect(find.widgetWithText(SelectableText, expectedAnswer), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);
    expect(find.widgetWithText(SelectableText, '你好'), findsNothing);

    await tester.tap(find.byTooltip('复制回答').last);
    await tester.pump();

    expect(clipboardText, expectedAnswer);
    expect(find.text('已复制回答'), findsOneWidget);
  });

  testWidgets('Chat page unfocuses input when answer area is tapped', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byType(TextField));
    await tester.pump();

    EditableText editableText = tester.widget(
      find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.tap(find.textContaining('你好，我是 AI 问答助手'));
    await tester.pump();

    editableText = tester.widget(
      find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.focusNode.hasFocus, isFalse);
  });

  testWidgets('Chat page unfocuses input when answer area is dragged', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    await tester.tap(find.byType(TextField));
    await tester.pump();

    EditableText editableText = tester.widget(
      find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      ),
    );
    expect(editableText.focusNode.hasFocus, isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, -80));
    await tester.pump();

    editableText = tester.widget(
      find.descendant(
        of: find.byType(TextField),
        matching: find.byType(EditableText),
      ),
    );
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
