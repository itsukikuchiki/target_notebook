import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// W6: 本地通知（MVP）
///
/// - main.dart 里调用 init()
/// - Splash 再调用 ensureReady() 兜底
/// - 对有 alarm 的 Task 做 schedule / cancel
class NotificationLocalService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _inited = false;
  bool get isReady => _inited;

  static const String _channelId = 'task_alarm_channel';
  static const String _channelName = 'Task Alarms';
  static const String _channelDesc = 'Notifications for scheduled task alarms';

  /// 初始化（尽量“无侵入”：失败不崩）
  Future<void> init() async {
    if (_inited) return;

    try {
      // ✅ timezone 初始化（非常关键）
      _initTimeZoneSafe();

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const settings = InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      );

      await _plugin.initialize(settings);

      // ✅ Android Channel（部分机型不显式建会“静默”）
      await _ensureAndroidChannel();

      // ✅ iOS: 再显式请求一次权限（可选，但更稳）
      await _requestIOSPermissionsSafe();

      _inited = true;
    } catch (e) {
      debugPrint('[NotificationLocalService] init failed: $e');
      _inited = false;
    }
  }

  /// Splash 兜底调用：确保 init 被执行过
  Future<void> ensureReady() async {
    if (_inited) return;
    await init();
  }

  /// 调度一次性通知（MVP：单次提醒）
  ///
  /// - id：建议用 taskId 的 int（Hive key）
  /// - at：提醒时间（本地时区）
  Future<void> scheduleOne({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    if (!_inited) await init();
    if (!_inited) return;

    // 过去时间不调度
    if (at.isBefore(DateTime.now())) return;

    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
      );

      const darwinDetails = DarwinNotificationDetails();

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final tzAt = _toTz(at);

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzAt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: null, // 单次
      );
    } catch (e) {
      debugPrint('[NotificationLocalService] scheduleOne failed: $e');
    }
  }

  /// 取消某条通知
  Future<void> cancel(int id) async {
    if (!_inited) await init();
    if (!_inited) return;

    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('[NotificationLocalService] cancel failed: $e');
    }
  }

  /// 取消所有通知（用于“删除账号&数据”）
  Future<void> cancelAll() async {
    if (!_inited) await init();
    if (!_inited) return;

    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('[NotificationLocalService] cancelAll failed: $e');
    }
  }

  // =========================
  // helpers
  // =========================

  void _initTimeZoneSafe() {
    try {
      tzdata.initializeTimeZones();

      // 你的项目默认时区：东京（JST）
      // 如果未来要按设备时区：可用 native_timezone 插件取设备时区名再 getLocation()
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
    } catch (e) {
      debugPrint('[NotificationLocalService] timezone init failed: $e');
      // fallback：不设置也能跑，但可能偏移
    }
  }

  tz.TZDateTime _toTz(DateTime dt) {
    // tz.local 已在 init 时设置为 Asia/Tokyo（尽量稳定）
    return tz.TZDateTime.from(dt, tz.local);
  }

  Future<void> _ensureAndroidChannel() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;

      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      );

      await android.createNotificationChannel(channel);
    } catch (e) {
      debugPrint('[NotificationLocalService] createChannel failed: $e');
    }
  }

  Future<void> _requestIOSPermissionsSafe() async {
    try {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('[NotificationLocalService] requestPermissions failed: $e');
    }
  }
}

