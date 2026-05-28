# AI 问答聊天室 Demo

一个基于 Flutter 的 AI 问答聊天室示例项目，当前接入 DeepSeek Chat Completions 流式接口。项目保留了无 API Key 时的本地模拟回复，方便先跑通界面和交互，再切换到真实接口。

## 功能特性

- 流式展示 AI 回复内容。
- 支持 DeepSeek V4 Flash / V4 Pro 模型切换。
- 支持“深度思考”开关，并在开启后展示 reasoning 内容。
- 无 `DEEPSEEK_API_KEY` 时自动使用本地模拟回复。
- 基于 Material 3 的移动端聊天界面。
- 包含基础 Widget 测试，覆盖模拟回复、模型选择和思考过程展示。

## 技术栈

- Flutter 3.38.10
- Dart 3.10.9
- `http`：调用 DeepSeek HTTP 流式接口
- `flutter_lints`：基础代码规范检查

## 项目结构

```text
lib/
  main.dart                         # 应用入口，读取 DEEPSEEK_API_KEY 并注入 ChatApi
  features/chat/
    chat_page.dart                  # 聊天页 UI、输入栏、模型选择、流式消息渲染
    chat_api.dart                   # DeepSeek 接口封装、SSE 解析、本地模拟回复
    chat_message.dart               # 聊天消息模型
test/
  widget_test.dart                  # 聊天页 Widget 测试
```

## 快速开始

先安装依赖：

```bash
flutter pub get
```

不配置 API Key 也可以直接运行，此时会走本地模拟回复：

```bash
flutter run
```

配置 DeepSeek API Key 后运行，会调用真实接口：

```bash
flutter run --dart-define=DEEPSEEK_API_KEY=你的_API_Key
```

也可以指定运行平台，例如 Chrome：

```bash
flutter run -d chrome --dart-define=DEEPSEEK_API_KEY=你的_API_Key
```

### 终端运行与热更新

进入项目根目录后，在终端启动应用：

```bash
cd /Users/chen/Desktop/project/richinfo/demo/chatroom-app-demo
flutter run
```

如果需要带 API Key 启动：

```bash
flutter run --dart-define=DEEPSEEK_API_KEY=你的_API_Key
```

如果本机连接了多个设备，可以先查看设备列表：

```bash
flutter devices
```

然后指定设备启动，例如 Chrome：

```bash
flutter run -d chrome --dart-define=DEEPSEEK_API_KEY=你的_API_Key
```

应用启动后，保持这个终端不要关闭。修改 Dart 文件并保存后，在同一个终端输入下面的快捷键：

```text
r
```

`r` 表示 Hot Reload，适合大多数 UI、文案、样式和普通逻辑修改，速度最快，应用状态通常会保留。

如果修改了入口、全局初始化、状态结构等 Hot Reload 不生效的内容，可以输入：

```text
R
```

`R` 表示 Hot Restart，会重启 Flutter 应用，状态会重置，但终端进程仍然保持运行。

终止应用有两种常用方式：

```text
q
```

`q` 会正常退出当前 `flutter run` 会话。

也可以使用终端中断快捷键：

```text
Ctrl + C
```

`Ctrl + C` 会中断当前终端进程，适合需要强制停止或终端没有响应时使用。

## 配置说明

应用入口在 `lib/main.dart` 中通过编译期环境变量读取 API Key：

```dart
const deepSeekApiKey = String.fromEnvironment('DEEPSEEK_API_KEY');
```

`ChatApi` 默认配置如下：

- `baseUrl`：`https://api.deepseek.com`
- 接口路径：`/chat/completions`
- 请求方式：`POST`
- 响应方式：SSE 流式响应

如果 `DEEPSEEK_API_KEY` 为空，`ChatApi` 会返回本地模拟内容，不会发起网络请求。

## 常用命令

代码静态检查：

```bash
flutter analyze
```

运行测试：

```bash
flutter test
```

构建 Web：

```bash
flutter build web --dart-define=DEEPSEEK_API_KEY=你的_API_Key
```

构建 Android：

```bash
flutter build apk --dart-define=DEEPSEEK_API_KEY=你的_API_Key
```

## 使用说明

1. 启动应用后，聊天页会显示默认欢迎消息。
2. 在输入框输入问题，点击发送按钮或键盘发送。
3. 发送过程中输入栏会进入发送状态，AI 回复会流式追加到最后一条消息。
4. 点击模型选择器可以在 `V4 Flash` 和 `V4 Pro` 之间切换。
5. 开启“深度思考”后，请求会携带 thinking 参数；如果接口返回 reasoning 内容，聊天气泡中会展示可展开的“思考过程”。

## 关键实现

### 流式请求

`ChatApi.sendMessageStream` 会把聊天消息转换为 DeepSeek 接口需要的 `messages` 格式，并设置：

```json
{
  "stream": true,
  "thinking": {
    "type": "enabled 或 disabled"
  }
}
```

接口返回后，`parseSseLine` 会解析每一行 `data:` 内容，并提取：

- `delta.content`：普通回复增量。
- `delta.reasoning_content`：思考过程增量。
- `finish_reason`：回复结束原因。

### 消息渲染

`ChatPage` 会先插入用户消息，再插入一条空的助手消息。随后每收到一个流式片段，就更新最后一条助手消息的 `content` 或 `reasoningContent`，从而实现边生成边展示。

## 注意事项

- 不建议把真实 API Key 写死在源码或提交到仓库。
- `--dart-define` 会在编译时注入变量，适合本地开发和简单 Demo；生产环境建议结合服务端代理或平台安全配置管理密钥。
- 当前 Demo 只维护内存中的会话消息，刷新或重启后历史记录不会保留。
- 当前输入框提示包含“按住说话”，但项目还没有实现语音输入功能。

## 后续可扩展方向

- 增加会话列表和本地历史记录持久化。
- 增加 Markdown 渲染、代码块复制、图片消息等富文本能力。
- 增加停止生成、重新生成、清空上下文等聊天操作。
- 增加服务端代理，避免客户端直接暴露 API Key。
- 增加错误状态、重试机制和接口超时控制。
