// lib/pages/splash_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_local_service.dart';
import 'onboarding_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    this.preDelay = const Duration(milliseconds: 250),
    this.postDelay = const Duration(milliseconds: 900),
  });

  /// 启动前的短暂停顿（UI 稳定/动效）
  /// ✅ 测试时可传 Duration.zero
  final Duration preDelay;

  /// 初始化完成后的停顿（避免一闪而过）
  /// ✅ 测试时可传 Duration.zero
  final Duration postDelay;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (widget.preDelay > Duration.zero) {
      await Future<void>.delayed(widget.preDelay);
    }

    // 1) User（防御式：测试/某些场景可能未 init）
    final userP = context.read<UserProvider>();
    if (!userP.hasUser) {
      await userP.init();
    }

    // 2) Settings（同理：防御式）
    final settingsP = context.read<SettingsProvider>();
    if (!settingsP.inited) {
      await settingsP.init();
    }

    // 3) Notification（请求/确认权限）
    final notification = context.read<NotificationLocalService>();
    await notification.ensureReady();

    if (widget.postDelay > Duration.zero) {
      await Future<void>.delayed(widget.postDelay);
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    final next = settingsP.seenOnboarding ? '/home' : OnboardingPage.route;
    Navigator.of(context).pushReplacementNamed(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/brand/app_icon.png',
              width: 96,
              height: 96,
              gaplessPlayback: true,
              // ✅ 测试环境 asset 取不到时，不让 ImageStream 持续挂起
              errorBuilder: (_, __, ___) => const Icon(
                Icons.flag_circle_outlined,
                size: 96,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Target Notebook',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

