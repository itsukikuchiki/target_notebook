import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:target_notebook/core/hive_init.dart';
import 'package:target_notebook/models/goal.dart';
import '../hive_test_util.dart';

void main() {
  test('probe write in clear-only vs close-reopen lifecycle', () async {
    print('STEP: setup');
    await HiveTestEnv.setUp();

    print('STEP: goal box open? ${Hive.isBoxOpen(AppBoxes.goal)}');

    final goalBox = Hive.box<Goal>(AppBoxes.goal);
    final dynamic boxAny = goalBox;
    final boxPath = boxAny.path;
    print('STEP: box name=${goalBox.name} path=$boxPath');

    print('STEP: clear only');
    await goalBox.clear();

    print('STEP: write after clear');
    await goalBox.put('probe_clear_only', Goal(title: 'probe-clear-only'));
    print('STEP: write after clear done');

    print('STEP: close box');
    await goalBox.close();

    print('STEP: reopen box');
    final reopened = await openTestBox<Goal>(AppBoxes.goal);

    print('STEP: write after reopen');
    await reopened.put('probe_reopen', Goal(title: 'probe-reopen'));
    print('STEP: write after reopen done');

    await HiveTestEnv.tearDown();
  });
}
