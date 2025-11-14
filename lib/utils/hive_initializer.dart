import 'package:hive/hive.dart';

/// 确保获得一个泛型为 T 的 Box：
/// - 如果未打开 => 直接 openBox<T>
/// - 如果已打开但泛型匹配 => 直接返回
/// - 如果已打开但泛型不匹配 => 关闭后以 T 重新打开
Future<Box<T>> ensureTypedBox<T>(String name) async {
  if (!Hive.isBoxOpen(name)) {
    return await Hive.openBox<T>(name);
  }
  final opened = Hive.box(name);
  if (opened is Box<T>) {
    return opened;
  }
  await opened.close();
  return await Hive.openBox<T>(name);
}

