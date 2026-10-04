import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/llm_settings.dart';

/// 配图生成（可选）。默认关闭；开启后调用 OpenAI 兼容的 /images/generations。
/// 任何失败都被吞掉，不影响主流程。
class ImageService {
  final Dio _dio;
  bool enabled;

  ImageService({Dio? dio, this.enabled = false})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 3),
            ));

  /// 为某个月生成 1 张场景图，返回本地文件路径；失败返回 null。
  Future<String?> generateSceneImage({
    required LlmSettings settings,
    required String prompt,
    required String fileName,
  }) async {
    if (!enabled || !settings.isConfigured || settings.isAnthropic) return null;
    try {
      final response = await _dio.post(
        '${settings.baseUrl.replaceAll(RegExp(r'/+$'), '')}/images/generations',
        options: Options(headers: {
          'Authorization': 'Bearer ${settings.apiKey}',
          'Content-Type': 'application/json',
        }),
        data: {
          'model': 'gpt-image-1',
          'prompt': prompt,
          'n': 1,
          'size': '1024x1024',
        },
      );
      final data = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final list = data['data'];
      if (list is! List || list.isEmpty) return null;
      final first = Map<String, dynamic>.from(list.first as Map);
      final b64 = first['b64_json']?.toString();
      if (b64 == null || b64.isEmpty) return null;
      final dir = await getApplicationDocumentsDirectory();
      final imageDir = Directory(p.join(dir.path, 'images'));
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      final file = File(p.join(imageDir.path, '$fileName.png'));
      await file.writeAsBytes(base64Decode(b64));
      return file.path;
    } catch (_) {
      return null;
    }
  }
}