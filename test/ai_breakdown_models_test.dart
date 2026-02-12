import 'package:flutter_test/flutter_test.dart';
import 'package:target_notebook/models/ai_breakdown_models.dart';

void main() {
  group('AiBreakdownResult.tryParse', () {
    test('parses valid json', () {
      const raw = r'''
      {
        "subGoals": [
          {
            "title": "子目标A",
            "description": "说明",
            "why": "原因",
            "estimateDays": 7,
            "priority": 2,
            "tasks": [
              {"title":"任务1","minutes":45,"dueInDays":1,"priority":2,"note":"备注"}
            ]
          }
        ]
      }
      ''';

      final r = AiBreakdownResult.tryParse(raw);
      expect(r.subGoals.length, 1);
      expect(r.subGoals.first.title, '子目标A');
      expect(r.subGoals.first.tasks.length, 1);
      expect(r.subGoals.first.tasks.first.minutes, inInclusiveRange(15, 240));
    });

    test('parses json embedded in text (slice {...})', () {
      const raw = r'''
      some preface text...
      {"subGoals":[{"title":"SG","estimateDays":3,"priority":1,"tasks":[{"title":"T","minutes":30,"dueInDays":0,"priority":1}]}]}
      ...some tail text
      ''';

      final r = AiBreakdownResult.tryParse(raw);
      expect(r.subGoals.length, 1);
      expect(r.subGoals.first.title, 'SG');
      expect(r.subGoals.first.tasks.first.title, 'T');
    });

    test('clamps minutes/priority/dueInDays', () {
      const raw = r'''
      {"subGoals":[{"title":"SG","estimateDays":1,"priority":99,"tasks":[{"title":"T","minutes":999,"dueInDays":-1,"priority":0}]}]}
      ''';

      final r = AiBreakdownResult.tryParse(raw);
      final sg = r.subGoals.first;
      final t = sg.tasks.first;

      expect(sg.priority, 5); // clamp 1..5
      expect(t.minutes, 240); // clamp 15..240
      expect(t.dueInDays, 0); // clamp >=0
      expect(t.priority, 1);  // clamp 1..5
    });

    test('empty text returns empty result', () {
      final r = AiBreakdownResult.tryParse('   ');
      expect(r.subGoals, isEmpty);
    });
  });
}

