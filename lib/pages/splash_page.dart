// lib/pages/splash_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/notification_local_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

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
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final userP = context.read<UserProvider>();
    if (!userP.hasUser) {
      await userP.init();
    }

    final notification = context.read<NotificationLocalService>();
    await notification.ensureReady();

    await Future<void>.delayed(const Duration(milliseconds: 900));

    if (!mounted || _navigated) return;
    _navigated = true;

    Navigator.of(context).pushReplacementNamed('/home');
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
              // ✅ 关键：测试环境 asset 取不到时，不让 ImageStream 持续挂起
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

