// lib/services/ai_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/ai_breakdown_models.dart';

class AiService {
  final String apiKey;

  /// 你也可以在 main.dart 里传入别的模型
  /// 注意：Structured Outputs（json_schema）需要支持的模型快照（4o-mini/4o 等）
  /// 你的选择 gpt-4o-mini 是合理的。:contentReference[oaicite:2]{index=2}
  final String model;

  /// 网络超时
  final Duration timeout;

  AiService({
    required this.apiKey,
    this.model = 'gpt-4o-mini',
    this.timeout = const Duration(seconds: 30),
  });

  bool get hasKey => apiKey.trim().isNotEmpty;

  Future<AiBreakdownResult> breakdownGoal({
    required String title,
    String? description,
    DateTime? deadline,
    int weeklyHours = 5,
    String locale = 'zh',
  }) async {
    if (!hasKey) {
      throw Exception('OPENAI_API_KEY is empty');
    }

    final uri = Uri.parse('https://api.openai.com/v1/responses');

    final system = '''
You are a goal decomposition assistant.
Generate subgoals and tasks for the user's goal.

Rules:
- Return JSON that strictly follows the provided JSON Schema.
- Subgoals should be outcome-oriented.
- Tasks must be actionable, start with a verb, and small enough to do in 15~240 minutes.
- priority: 1 (highest) ~ 5 (lowest)
- dueInDays: 0+ integer
''';

    final userPayload = <String, dynamic>{
      'title': title,
      'description': description ?? '',
      'deadline': deadline?.toIso8601String() ?? '',
      'weeklyHours': weeklyHours,
      'locale': locale,
    };

    // ✅ JSON Schema（与你现有 models 对齐）
    final schema = {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'subGoals': {
          'type': 'array',
          'items': {
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'title': {'type': 'string'},
              'description': {'type': ['string', 'null']},
              'why': {'type': ['string', 'null']},
              'estimateDays': {'type': 'integer', 'minimum': 1, 'maximum': 3650},
              'priority': {'type': 'integer', 'minimum': 1, 'maximum': 5},
              'tasks': {
                'type': 'array',
                'items': {
                  'type': 'object',
                  'additionalProperties': false,
                  'properties': {
                    'title': {'type': 'string'},
                    'minutes': {'type': 'integer', 'minimum': 15, 'maximum': 240},
                    'dueInDays': {'type': 'integer', 'minimum': 0, 'maximum': 3650},
                    'priority': {'type': 'integer', 'minimum': 1, 'maximum': 5},
                    'note': {'type': ['string', 'null']},
                  },
                  'required': ['title', 'minutes', 'dueInDays', 'priority'],
                },
              },
            },
            'required': ['title', 'estimateDays', 'priority', 'tasks'],
          },
        },
      },
      'required': ['subGoals'],
    };

    // ✅ Structured Outputs（REST）正确写法：text.format.type = json_schema
    // 并开启 strict。:contentReference[oaicite:3]{index=3}
    final body = {
      'model': model,
      'input': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': jsonEncode(userPayload)},
      ],
      'text': {
        'format': {
          'type': 'json_schema',
          'name': 'goal_breakdown',
          'strict': true,
          'schema': schema,
        },
      },
    };

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw Exception('AI request timeout after ${timeout.inSeconds}s');
    } catch (e) {
      throw Exception('AI network error: $e');
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      // 尽量把 body 也带上（便于你 debug：rate_limit、invalid_api_key、model 不支持等）
      throw Exception('AI request failed: ${resp.statusCode} ${resp.body}');
    }

    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final outputText = _extractOutputText(decoded);

    // 你的模型层自带 tryParse（支持从文本中截 JSON）
    return AiBreakdownResult.tryParse(outputText);
  }

  String _extractOutputText(Map<String, dynamic> root) {
    // 1) 官方/示例里常见 output_text
    final ot = root['output_text'];
    if (ot is String && ot.trim().isNotEmpty) return ot;

    // 2) 否则遍历 output[].content[].text
    final output = root['output'];
    if (output is List) {
      final buf = StringBuffer();
      for (final item in output) {
        if (item is! Map<String, dynamic>) continue;
        final content = item['content'];
        if (content is! List) continue;
        for (final c in content) {
          if (c is! Map<String, dynamic>) continue;
          final t = c['text'];
          if (t is String) buf.write(t);
        }
      }
      final s = buf.toString();
      if (s.trim().isNotEmpty) return s;
    }

    // 3) 最后兜底：把整个 body 抛出去，方便定位结构变化
    throw Exception('AI response has no readable output_text: ${jsonEncode(root)}');
  }
}

