import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:target_notebook/providers/nav_provider.dart';

void main() {
  // ✅ 初始化 Flutter 测试绑定（一次即可）
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NavProvider setIndex 会更新且通知', () async {
    // ✅ 提供内存态 prefs，避免真实 IO
    SharedPreferences.setMockInitialValues({});

    final p = NavProvider();
    int notifyCount = 0;
    p.addListener(() => notifyCount++);

    expect(p.index, 0);
    p.setIndex(3);

    // 等一拍让异步写入/通知完成
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(p.index, 3);
    expect(notifyCount, greaterThan(0));
  });
}

