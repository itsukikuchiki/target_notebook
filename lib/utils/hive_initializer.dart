import 'package:hive/hive.dart';

/// 打开一个带类型参数的 Hive 盒子。
///
/// - 如果名称为 [name] 的盒子已经打开，则直接返回现有的 typed box；
/// - 如果尚未打开，则以类型 [T] 打开并返回。
Future<Box<T>> ensureTypedBox<T>(String name) async {
  if (Hive.isBoxOpen(name)) {
    return Hive.box<T>(name);
  }
  return Hive.openBox<T>(name);
}

