import 'package:flutter_test/flutter_test.dart';

import '../helpers/hive_test_env.dart';

void main() {
  test('TEST W1: plain test, no Hive', () async {
    print('STEP W1-1: start');
    print('STEP W1-2: end');
  });

  testWidgets('TEST W2: testWidgets, no Hive', (tester) async {
    print('STEP W2-1: start');
    print('STEP W2-2: end');
  });

  test('TEST W3: plain test + HiveTestEnv.setUp/tearDown', () async {
    print('STEP W3-1: before setUp');
    await HiveTestEnv.setUp();
    print('STEP W3-2: after setUp');

    print('STEP W3-3: before tearDown');
    await HiveTestEnv.tearDown();
    print('STEP W3-4: after tearDown');
  });

  testWidgets('TEST W4: testWidgets + HiveTestEnv.setUp/tearDown', (tester) async {
    print('STEP W4-1: before setUp');
    await HiveTestEnv.setUp();
    print('STEP W4-2: after setUp');

    print('STEP W4-3: before tearDown');
    await HiveTestEnv.tearDown();
    print('STEP W4-4: after tearDown');
  });
}
