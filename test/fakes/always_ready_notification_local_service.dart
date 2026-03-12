// test/fakes/always_ready_notification_local_service.dart
import 'package:target_notebook/services/notification_local_service.dart';

class AlwaysReadyNotificationLocalService implements NotificationLocalService {
  bool _ready = true;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    _ready = true;
  }

  @override
  Future<void> ensureReady() async {
    _ready = true;
  }

  @override
  Future<void> scheduleOne({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    // no-op
  }

  @override
  Future<void> cancel(int id) async {
    // no-op
  }

  @override
  Future<void> cancelAll() async {
    // no-op
  }
}

