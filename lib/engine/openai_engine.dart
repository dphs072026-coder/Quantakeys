import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenAiEngine {
  static const String _defaultApiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _modelsUrl = 'https://api.openai.com/v1/models';

  static String _getApiUrl(String apiKey) {
    if (apiKey.trim().startsWith('gsk_')) {
      return 'https://api.groq.com/openai/v1/chat/completions';
    }
    return _defaultApiUrl;
  }

  static String _getModelsUrl(String apiKey) {
    if (apiKey.trim().startsWith('gsk_')) {
      return 'https://api.groq.com/openai/v1/models';
    }
    return _modelsUrl;
  }

  /// Fetch available models accessible by the provided API key
  static Future<List<String>> fetchAvailableModels(String apiKey) async {
    const defaultModels = ['qwen/qwen3.8-27b', 'openai/gpt-oss-20b', 'openai/gpt-oss-120b', 'meta-llama/llama-prompt-guard-2-22m', 'gpt-6-luna'];
    if (apiKey.trim().isEmpty) {
      return defaultModels;
    }

    try {
      final response = await http.get(
        Uri.parse(_getModelsUrl(apiKey)),
        headers: {
          'Authorization': 'Bearer ${apiKey.trim()}',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> list = data['data'] ?? [];
        
        final Set<String> models = {'gpt-6-luna'};
        for (var item in list) {
          final id = item['id'] as String?;
          if (id != null) {
            if (apiKey.trim().startsWith('gsk_')) {
              models.add(id);
            } else if (id.startsWith('gpt-') || id.startsWith('o1') || id.startsWith('o3')) {
              if (!id.contains('realtime') && !id.contains('audio') && !id.contains('transcription')) {
                models.add(id);
              }
            }
          }
        }
        
        if (models.isNotEmpty) {
          final sorted = models.toList()..sort();
          if (sorted.contains('qwen/qwen3.8-27b')) {
            sorted.remove('qwen/qwen3.8-27b');
            sorted.insert(0, 'qwen/qwen3.8-27b');
          }
          if (sorted.contains('gpt-4o-mini')) {
            sorted.remove('gpt-4o-mini');
            sorted.insert(0, 'gpt-4o-mini');
          }
          if (sorted.contains('gpt-6-luna')) {
            sorted.remove('gpt-6-luna');
            sorted.insert(0, 'gpt-6-luna');
          }
          return sorted;
        }
      }
    } catch (_) {}

    return defaultModels;
  }

  static Future<http.Response> _sendOpenAiRequest({
    required String url,
    required String apiKey,
    required Map<String, dynamic> body,
  }) async {
    var response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer ${apiKey.trim()}',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      try {
        final errorBody = utf8.decode(response.bodyBytes);
        final errorJson = jsonDecode(errorBody);
        final errMsg = errorJson['error']?['message']?.toString().toLowerCase() ?? '';

        if (body.containsKey('temperature') && errMsg.contains('temperature')) {
          final retryBody = Map<String, dynamic>.from(body);
          retryBody.remove('temperature');

          response = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: jsonEncode(retryBody),
          ).timeout(const Duration(seconds: 20));
        }

        if (response.statusCode != 200 && body.containsKey('max_completion_tokens') &&
            errMsg.contains('max_completion_tokens') && 
            (errMsg.contains('not supported') || errMsg.contains('unsupported') || errMsg.contains('unknown') || errMsg.contains('unrecognized'))) {
          
          final retryBody = Map<String, dynamic>.from(body);
          final tokens = retryBody.remove('max_completion_tokens');
          retryBody['max_tokens'] = tokens;

          response = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: jsonEncode(retryBody),
          ).timeout(const Duration(seconds: 20));
        } 
        else if (response.statusCode != 200 && (body.containsKey('max_tokens') || body.containsKey('max_completition_tokens')) &&
            (errMsg.contains('max_tokens') || errMsg.contains('max_completion_tokens') || errMsg.contains('max_completition_tokens'))) {
          
          final retryBody = Map<String, dynamic>.from(body);
          retryBody.remove('max_tokens');
          retryBody.remove('max_completition_tokens');
          retryBody['max_completion_tokens'] = 150;

          response = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: jsonEncode(retryBody),
          ).timeout(const Duration(seconds: 20));
        }
      } catch (_) {}
    }

    return response;
  }

  static String? _cleanResponse(String? text) {
    if (text == null) return null;
    var cleaned = text.trim();
    final prefixes = [
      RegExp(r'^here\s+is\s+(the|your)\s+(polished|corrected|updated)?\s*(text|sentence|grammar)?[:\-]?\s*', caseSensitive: false),
      RegExp(r'^sure[,!]?\s*(here\s+is[^\n:]*[:\-]?)?\s*', caseSensitive: false),
      RegExp(r'^certainly[,!]?\s*', caseSensitive: false),
      RegExp(r'^the\s+polished\s+text\s+is[:\-]?\s*', caseSensitive: false),
      RegExp(r'^solution[:\-]?\s*', caseSensitive: false),
      RegExp(r'^answer[:\-]?\s*', caseSensitive: false),
    ];
    for (var prefix in prefixes) {
      cleaned = cleaned.replaceFirst(prefix, '').trim();
    }
    return cleaned;
  }

  static Future<String?> polishText({
    required String text,
    required String apiKey,
    String model = 'qwen/qwen3.8-27b',
  }) async {
    if (apiKey.isEmpty || text.trim().isEmpty) return null;

    final isReasoningModel = model.startsWith('o1') || model.startsWith('o3');

    final Map<String, dynamic> body = {
      'model': model,
      'messages': [
        if (!isReasoningModel)
          {
            'role': 'system',
            'content': 'You are a strict text-polishing filter. Your ONLY job is to output the corrected, polished version of the user text. '
                'Refine, fix typos, correct grammar, and enhance sentence flow while maintaining the original meaning. '
                'Do NOT include ANY conversational text, pleasantries, greetings, explanations, introductions, quotes, or meta-commentary. '
                'Output ONLY the raw polished text directly.'
          },
        {
          'role': 'user',
          'content': isReasoningModel
              ? 'Refine and polish the following text by fixing typos and grammar. Output ONLY the raw polished text without any conversation or quotes:\n\n${text.trim()}'
              : text.trim(),
        }
      ],
      'max_completion_tokens': 150,
    };

    if (!isReasoningModel) {
      body['temperature'] = 0.3;
    }

    final response = await _sendOpenAiRequest(
      url: _getApiUrl(apiKey),
      apiKey: apiKey,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] as String?;
      return _cleanResponse(content);
    } else {
      try {
        final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
        final errCode = errorJson['error']?['code'] ?? '';
        final errMsg = errorJson['error']?['message'] ?? 'API Error ${response.statusCode}';

        if ((response.statusCode == 404 || errCode == 'model_not_found') && model != 'qwen/qwen3.8-27b' && model != 'gpt-6-luna') {
          return await polishText(text: text, apiKey: apiKey, model: 'qwen/qwen3.8-27b');
        }

        throw Exception(errMsg);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('API Request Failed (${response.statusCode})');
      }
    }
  }

  static Future<String?> solveWordProblem({
    required String query,
    required String apiKey,
    String model = 'qwen/qwen3.8-27b',
  }) async {
    if (apiKey.isEmpty || query.trim().isEmpty) return null;

    final isReasoningModel = model.startsWith('o1') || model.startsWith('o3');

    final Map<String, dynamic> body = {
      'model': model,
      'messages': [
        if (!isReasoningModel)
          {
            'role': 'system',
            'content': 'You are a strict mathematical and scientific calculation engine. Your ONLY job is to output the direct numerical or symbolic result or concise solution to the problem. '
                'Do NOT include ANY conversational text, pleasantries, greetings, explanations, or meta-commentary. '
                'Output ONLY the direct answer/result.'
          },
        {
          'role': 'user',
          'content': isReasoningModel
              ? 'Analyze and solve this problem. Provide the concise final answer directly on the first line with zero conversation:\n\n${query.trim()}'
              : query.trim(),
        }
      ],
      'max_completion_tokens': 150,
    };

    if (!isReasoningModel) {
      body['temperature'] = 0.2;
    }

    final response = await _sendOpenAiRequest(
      url: _getApiUrl(apiKey),
      apiKey: apiKey,
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] as String?;
      return _cleanResponse(content);
    } else {
      try {
        final errorJson = jsonDecode(utf8.decode(response.bodyBytes));
        final errCode = errorJson['error']?['code'] ?? '';
        final errMsg = errorJson['error']?['message'] ?? 'API Error ${response.statusCode}';

        if ((response.statusCode == 404 || errCode == 'model_not_found') && model != 'qwen/qwen3.8-27b' && model != 'gpt-6-luna') {
          return await solveWordProblem(query: query, apiKey: apiKey, model: 'qwen/qwen3.8-27b');
        }

        throw Exception(errMsg);
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('API Request Failed (${response.statusCode})');
      }
    }
  }
}
