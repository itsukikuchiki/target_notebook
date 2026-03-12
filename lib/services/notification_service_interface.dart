// lib/services/notification_service_interface.dart

abstract interface class NotificationService {
  /// 是否已完成初始化（可安全 schedule / cancel）
  bool get isReady;

  /// 初始化（尽量不抛异常）
  Future<void> init();

  /// Splash 兜底调用：确保 init 被执行过
  Future<void> ensureReady();

  /// 调度一次性通知（MVP：单次提醒）
  ///
  /// - id：建议用 taskId 的 int（Hive key）
  /// - at：提醒时间（本地时区）
  Future<void> scheduleOne({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  /// 取消某条通知
  Future<void> cancel(int id);

  /// 取消所有通知（用于“删除账号&数据”）
  Future<void> cancelAll();
}

