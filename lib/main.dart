import 'package:flutter/material.dart';

import 'features/chat/chat_api.dart';
import 'features/chat/chat_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const deepSeekApiKey = String.fromEnvironment('DEEPSEEK_API_KEY');

    return MaterialApp(
      title: 'AI问答',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: ChatPage(api: ChatApi(apiKey: deepSeekApiKey)),
    );
  }
}
