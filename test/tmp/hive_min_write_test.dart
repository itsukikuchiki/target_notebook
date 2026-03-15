import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:target_notebook/models/goal.dart';

void main() {
  test('minimal hive goal write/read with fresh temp dir', () async {
    late Directory tempDir;

    print('STEP: init');
    tempDir = await Directory.systemTemp.createTemp('hive_min_write_test_');
    Hive.init(tempDir.path);

    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(GoalAdapter());
    }

    print('STEP: open box');
    final box = await Hive.openBox<Goal>('goal_box');

    print('STEP: write');
    const key = 'g1';
    final input = Goal(title: 'Minimal Goal');
    await box.put(key, input);

    print('STEP: read');
    final output = box.get(key);
    expect(output, isNotNull);
    expect(output!.title, equals('Minimal Goal'));

    await box.close();
    await Hive.close();
    await tempDir.delete(recursive: true);

    print('STEP: done');
  });
}
