import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../services/notification_local_service.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userP = context.watch<UserProvider>();
    final notification = context.read<NotificationLocalService>();

    final user = userP.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(userP.displayLabel),
            subtitle: Text(
              user == null
                  ? 'No user'
                  : user.isGuest
                      ? 'Guest Mode'
                      : '${user.authProvider.name.toUpperCase()} · ${user.email ?? ''}',
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 登录 / 注册
        if (userP.isGuest) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.login),
              title: const Text('登录 / 注册（邮箱）'),
              subtitle: const Text('保存数据到账号'),
              onTap: () => _showEmailAuthDialog(context),
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (userP.isAuthed) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('登出（返回 Guest）'),
              onTap: () async {
                await userP.signOutToGuest();
              },
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 删除账号 & 数据
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              '删除账号 & 本地数据',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await _confirmDelete(context);
              if (!confirm) return;

              await notification.cancelAll();
              await userP.deleteAccountAndData();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('数据已删除')),
                );
              }
            },
          ),
        ),

        const SizedBox(height: 24),

        const Card(
          child: ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('Theme（占位）'),
            subtitle: Text('Material 3 · Seed Color'),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Sync（占位）'),
            subtitle: Text('iCloud / Firebase / Notion'),
          ),
        ),
      ],
    );
  }

  // ===========================================================
  // 邮箱登录 / 注册 Dialog（MVP）
  // ===========================================================

  void _showEmailAuthDialog(BuildContext rootContext) {
    final emailController = TextEditingController();
    final pwController = TextEditingController();
    final nameController = TextEditingController();

    bool isLogin = true;

    showDialog(
      context: rootContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: Text(isLogin ? '邮箱登录' : '邮箱注册'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isLogin)
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Display Name（可选）'),
                    ),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  TextField(
                    controller: pwController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => isLogin = !isLogin),
                    child: Text(isLogin ? '没有账号？去注册' : '已有账号？去登录'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final userP = rootContext.read<UserProvider>();

                    try {
                      final email = emailController.text;
                      final pw = pwController.text;

                      if (isLogin) {
                        await userP.signInWithEmail(email: email, password: pw);
                      } else {
                        await userP.registerWithEmail(
                          email: email,
                          password: pw,
                          displayName: nameController.text,
                        );
                      }

                      if (rootContext.mounted) Navigator.pop(dialogCtx);
                    } catch (e) {
                      final msg = _prettyAuthError(e);
                      if (rootContext.mounted) {
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    }
                  },
                  child: Text(isLogin ? '登录' : '注册'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _prettyAuthError(Object e) {
    final s = e.toString();
    if (s.contains('email is empty')) return '请输入邮箱';
    if (s.contains('password is empty')) return '请输入密码';
    if (s.contains('email already registered')) return '该邮箱已注册，请直接登录';
    if (s.contains('email not registered')) return '该邮箱未注册，请先注册';
    if (s.contains('invalid password')) return '密码不正确';
    return '操作失败：$s';
  }

  // ===========================================================
  // 删除确认
  // ===========================================================

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除？'),
            content: const Text('此操作将清空所有本地数据，无法恢复。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

