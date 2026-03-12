import 'package:flutter_test/flutter_test.dart';

/// Safer alternative to pumpAndSettle() that will not hang forever
/// when there are periodic timers / ticking animations.
///
/// IMPORTANT:
/// - We DO NOT advance fake time here (no pump(Duration)).
/// - This prevents endless settling caused by timers/animations.
/// Returns true if it settled, false if it hit [maxFrames].
Future<bool> pumpAndSettleSafe(
  WidgetTester tester, {
  // Keep the old signature for compatibility.
  Duration step = const Duration(milliseconds: 16), // ignored intentionally
  int maxFrames = 120,
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(); // ⚠️ never advance time
    if (!tester.binding.hasScheduledFrame) return true;
  }
  return false;
}

/// Pumps a few frames without trying to fully settle.
/// IMPORTANT: does not advance fake time.
Future<void> pumpFrames(
  WidgetTester tester, {
  int frames = 3,
  Duration step = const Duration(milliseconds: 16), // ignored intentionally
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(); // ⚠️ never advance time
  }
}
