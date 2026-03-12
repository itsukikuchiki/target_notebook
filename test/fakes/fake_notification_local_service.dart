// test/fakes/fake_notification_local_service.dart
import 'package:target_notebook/services/notification_local_service.dart';

class FakeNotificationLocalService extends NotificationLocalService {
  bool inited = false;

  final List<ScheduleCall> scheduleCalls = [];
  final List<int> cancelCalls = [];
  int cancelAllCalls = 0;

  /// 兼容部分测试喜欢用 bool
  bool get cancelAllCalled => cancelAllCalls > 0;

  @override
  bool get isReady => inited;

  @override
  Future<void> init() async {
    inited = true;
  }

  @override
  Future<void> ensureReady() async {
    inited = true;
  }

  @override
  Future<void> scheduleOne({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    scheduleCalls.add(ScheduleCall(id: id, at: at, title: title, body: body));
  }

  @override
  Future<void> cancel(int id) async {
    cancelCalls.add(id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls += 1;
  }
}

class ScheduleCall {
  final int id;
  final DateTime at;
  final String title;
  final String body;

  ScheduleCall({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });
}

