import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/llm_settings.dart';

class LlmException implements Exception {
  final String message;
  LlmException(this.message);
  @override
  String toString() => message;
}

/// 未配置 API Key / Base URL 时抛出，界面据此引导到设置页。
class LlmConfigException extends LlmException {
  LlmConfigException(super.message);
}

/// LLM 调用服务。支持 OpenAI 兼容接口（DeepSeek / OpenAI / 自建）与 Anthropic。
class LlmService {
  final Dio _dio;

  LlmService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5),
              sendTimeout: const Duration(minutes: 1),
            ));

  Future<String> chat(LlmSettings settings, List<ChatMessage> messages) async {
    if (!settings.isConfigured) {
      throw LlmConfigException('尚未配置 LLM：请在「设置」中填写 API Key 与接口地址。');
    }
    if (settings.isAnthropic) {
      return _chatAnthropic(settings, messages);
    }
    return _chatOpenAiCompatible(settings, messages);
  }

  /// 连通性测试：发一条极短的消息。
  Future<String> testConnection(LlmSettings settings) async {
    final reply = await chat(settings, [
      const ChatMessage(role: 'user', content: '请只回复两个字：可用'),
    ]);
    return reply.trim();
  }

  Future<String> _chatOpenAiCompatible(
      LlmSettings settings, List<ChatMessage> messages) async {
    final url = _join(settings.baseUrl, '/chat/completions');
    try {
      final response = await _dio.post(
        url,
        options: Options(headers: {
          'Authorization': 'Bearer ${settings.apiKey}',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': settings.model,
          'messages': messages
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(),
          'temperature': settings.temperature,
          'max_tokens': settings.maxTokens,
          'stream': false,
        },
      );
      final data = _asMap(response.data);
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final message = _asMap(choices.first)['message'];
        return _asMap(message)['content']?.toString() ?? '';
      }
      throw LlmException('返回格式异常：未找到 choices');
    } on DioException catch (e) {
      throw LlmException(_describeDioError(e));
    }
  }

  Future<String> _chatAnthropic(
      LlmSettings settings, List<ChatMessage> messages) async {
    final url = _join(settings.baseUrl, '/v1/messages');
    final systemParts =
        messages.where((m) => m.role == 'system').map((m) => m.content);
    final dialog = messages.where((m) => m.role != 'system');
    try {
      final response = await _dio.post(
        url,
        options: Options(headers: {
          'x-api-key': settings.apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': settings.model,
          'max_tokens': settings.maxTokens,
          'temperature': settings.temperature,
          if (systemParts.isNotEmpty) 'system': systemParts.join('\n\n'),
          'messages': dialog
              .map((m) => {'role': m.role, 'content': m.content})
              .toList(),
        },
      );
      final data = _asMap(response.data);
      final content = data['content'];
      if (content is List && content.isNotEmpty) {
        return content
            .map((e) => _asMap(e)['text']?.toString() ?? '')
            .join();
      }
      throw LlmException('返回格式异常：未找到 content');
    } on DioException catch (e) {
      throw LlmException(_describeDioError(e));
    }
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  static String _join(String base, String path) {
    var b = base.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    if (b.isEmpty) return path;
    return '$b$path';
  }

  static String _describeDioError(DioException e) {
    final status = e.response?.statusCode;
    var detail = '';
    final data = e.response?.data;
    if (data != null) {
      try {
        detail = data is String ? data : jsonEncode(data);
      } catch (_) {
        detail = data.toString();
      }
      if (detail.length > 300) detail = '${detail.substring(0, 300)}…';
    }
    if (status == 401) return '鉴权失败（401）：请检查 API Key。$detail';
    if (status == 402) return '余额不足或未开通（402）。$detail';
    if (status == 404) return '接口地址不存在（404）：请检查 Base URL 与模型名。$detail';
    if (status == 429) return '请求过于频繁（429）：稍后重试。$detail';
    if (status != null) return '接口返回错误（$status）。$detail';
    return '网络请求失败：${e.message ?? e.type.name}';
  }
}

class ChatMessage {
  final String role; // system / user / assistant
  final String content;
  const ChatMessage({required this.role, required this.content});
}