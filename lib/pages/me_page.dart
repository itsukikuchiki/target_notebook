// lib/pages/me_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';
import '../providers/settings_provider.dart';
import '../services/notification_local_service.dart';
import 'legal_page.dart';
import '../utils/legal_i18n.dart';

class MePage extends StatelessWidget {
  const MePage({super.key});

  static const int _maxAvatarBytes = 2 * 1024 * 1024; // 2MB

  static const Key avatarButtonKey = Key('me.avatar.change');
  static const Key soundTileKey = Key('me.settings.sound');
  static const Key weekStartTileKey = Key('me.settings.week_start');
  static const Key notificationTileKey = Key('me.notification.ensure_ready');
  static const Key authTileKey = Key('me.auth.open');
  static const Key authEmailKey = Key('me.auth.email');
  static const Key authPasswordKey = Key('me.auth.password');
  static const Key authDisplayNameKey = Key('me.auth.display_name');
  static const Key authSubmitKey = Key('me.auth.submit');
  static const Key authToggleKey = Key('me.auth.toggle');
  static const Key authCancelKey = Key('me.auth.cancel');
  static const Key forgotButtonKey = Key('btn_forgot_password');
  static const Key forgotEmailKey = Key('forgot.email');
  static const Key forgotNewPasswordKey = Key('forgot.newpw');
  static const Key forgotSubmitKey = Key('forgot.submit');
  static const Key forgotCancelKey = Key('forgot.cancel');
  static const Key soundSaveKey = Key('me.sound.save');
  static const Key soundCancelKey = Key('me.sound.cancel');
  static const Key weekStartSaveKey = Key('me.week_start.save');
  static const Key weekStartCancelKey = Key('me.week_start.cancel');
  static const Key deleteTileKey = Key('me.delete_account');
  static const Key deleteConfirmKey = Key('me.delete.confirm');
  static const Key deleteCancelKey = Key('me.delete.cancel');

  @override
  Widget build(BuildContext context) {
    final userP = context.watch<UserProvider>();
    final settingsP = context.watch<SettingsProvider>();
    final notification = context.read<NotificationLocalService>();

    final user = userP.currentUser;
    final avatarFile = settingsP.avatarFile;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: CircleAvatar(
              child: avatarFile == null
                  ? const Icon(Icons.person)
                  : ClipOval(
                      child: Image.file(
                        avatarFile,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
            title: Text(userP.displayLabel),
            subtitle: Text(
              user == null
                  ? 'No user'
                  : user.isGuest
                      ? 'Guest Mode'
                      : '${user.authProvider.name.toUpperCase()} · ${user.email ?? ''}',
            ),
            trailing: IconButton(
              key: avatarButtonKey,
              tooltip: 'Change avatar',
              icon: const Icon(Icons.photo_camera_outlined),
              onPressed: () => _pickAvatar(context),
            ),
            onTap: () => _pickAvatar(context),
          ),
        ),
        const SizedBox(height: 12),

        if (userP.isGuest) ...[
          Card(
            child: ListTile(
              key: authTileKey,
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

        Card(
          child: ListTile(
            key: soundTileKey,
            leading: const Icon(Icons.volume_up_outlined),
            title: const Text('提示音'),
            subtitle: Text(_soundLabel(settingsP.soundId)),
            onTap: () => _showSoundPicker(context),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            key: weekStartTileKey,
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('周开始日'),
            subtitle: Text(settingsP.weekStart == WeekStart.monday ? '周一' : '周日'),
            onTap: () => _showWeekStartPicker(context),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            key: notificationTileKey,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('通知权限 / 后台提醒'),
            subtitle: const Text('检查并触发系统授权弹框（建议用户主动点击时触发）'),
            onTap: () async {
              try {
                await notification.ensureReady();
                if (context.mounted) {
                  _showMessage(
                    context,
                    '已请求/确认通知权限（如未弹框请到系统设置检查）',
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  _showMessage(context, '请求通知权限失败：$e');
                }
              }
            },
          ),
        ),
        const SizedBox(height: 12),

        Card(
          child: ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(
              LegalI18n.title(context, LegalTitleKey.privacy),
            ),
            subtitle: Text(
              LegalI18n.isJa(context) ? 'Privacy Policy' : 'Privacy Policy',
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalPage(
                  titleText: LegalI18n.title(context, LegalTitleKey.privacy),
                  doc: LegalDoc.privacy,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.article_outlined),
            title: Text(
              LegalI18n.title(context, LegalTitleKey.terms),
            ),
            subtitle: const Text('Terms of Service'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LegalPage(
                  titleText: LegalI18n.title(context, LegalTitleKey.terms),
                  doc: LegalDoc.terms,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        Card(
          child: ListTile(
            key: deleteTileKey,
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              '删除账号 & 本地数据',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await _confirmDelete(context);
              if (!confirm) return;

              await notification.cancelAll();
              await settingsP.clearAvatar();
              await userP.deleteAccountAndData();

              if (context.mounted) {
                _showMessage(context, '数据已删除');
              }
            },
          ),
        ),
      ],
    );
  }

  void _showMessage(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _pickAvatar(BuildContext context) async {
    final settingsP = context.read<SettingsProvider>();
    final picker = ImagePicker();

    try {
      final x = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 92,
      );
      if (x == null) return;

      final f = File(x.path);
      final bytes = await f.length();
      if (bytes > _maxAvatarBytes) {
        if (context.mounted) {
          _showMessage(context, '头像过大，请选择 2MB 以内的图片');
        }
        return;
      }

      await settingsP.setAvatarPath(f.path);

      if (context.mounted) {
        _showMessage(context, '头像已更新');
      }
    } catch (e) {
      if (context.mounted) {
        _showMessage(context, '选择头像失败：$e');
      }
    }
  }

  void _showSoundPicker(BuildContext context) {
    final settingsP = context.read<SettingsProvider>();
    SoundId selected = settingsP.soundId;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择提示音'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: SoundId.values.map((id) {
              return RadioListTile<SoundId>(
                key: Key('me.sound.option.${id.name}'),
                value: id,
                groupValue: selected,
                title: Text(_soundLabel(id)),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => selected = v);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            key: soundCancelKey,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            key: soundSaveKey,
            onPressed: () async {
              await settingsP.setSoundId(selected);
              if (context.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  String _soundLabel(SoundId id) {
    switch (id) {
      case SoundId.none:
        return '无';
      case SoundId.soft:
        return 'Soft（轻）';
      case SoundId.bell:
        return 'Bell（铃）';
    }
  }

  void _showWeekStartPicker(BuildContext context) {
    final settingsP = context.read<SettingsProvider>();
    WeekStart selected = settingsP.weekStart;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('周开始日'),
        content: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<WeekStart>(
                key: const Key('me.week_start.option.monday'),
                value: WeekStart.monday,
                groupValue: selected,
                title: const Text('周一开始'),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => selected = v);
                },
              ),
              RadioListTile<WeekStart>(
                key: const Key('me.week_start.option.sunday'),
                value: WeekStart.sunday,
                groupValue: selected,
                title: const Text('周日开始'),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => selected = v);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: weekStartCancelKey,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            key: weekStartSaveKey,
            onPressed: () async {
              await settingsP.setWeekStart(selected);
              if (context.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext rootContext, {String? presetEmail}) {
    final emailController = TextEditingController(text: presetEmail ?? '');
    final newPwController = TextEditingController();

    showDialog<void>(
      context: rootContext,
      builder: (ctx) => AlertDialog(
        title: const Text('重置密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: forgotEmailKey,
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              key: forgotNewPasswordKey,
              controller: newPwController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 8),
            const Text(
              'MVP：本地重置（不发送邮件）。如果更换设备，旧设备数据不会同步。',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: forgotCancelKey,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            key: forgotSubmitKey,
            onPressed: () async {
              final userP = rootContext.read<UserProvider>();
              try {
                await userP.resetPassword(
                  email: emailController.text,
                  newPassword: newPwController.text,
                );
                if (rootContext.mounted) {
                  Navigator.pop(ctx);
                  _showMessage(rootContext, '已记录重置请求，密码已重置，请使用新密码登录');
                }
              } catch (e) {
                final msg = _prettyAuthError(e);
                if (rootContext.mounted) {
                  _showMessage(rootContext, msg);
                }
              }
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  void _showEmailAuthDialog(BuildContext rootContext) {
    final emailController = TextEditingController();
    final pwController = TextEditingController();
    final nameController = TextEditingController();

    bool isLogin = true;

    void openLegal(LegalDoc doc) {
      final title = doc == LegalDoc.privacy
          ? LegalI18n.title(rootContext, LegalTitleKey.privacy)
          : LegalI18n.title(rootContext, LegalTitleKey.terms);

      Navigator.of(rootContext).push(
        MaterialPageRoute(
          builder: (_) => LegalPage(
            titleText: title,
            doc: doc,
          ),
        ),
      );
    }

    showDialog<void>(
      context: rootContext,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setState) {
            return AlertDialog(
              title: Text(isLogin ? '邮箱登录' : '邮箱注册'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isLogin)
                      TextField(
                        key: authDisplayNameKey,
                        controller: nameController,
                        decoration:
                            const InputDecoration(labelText: 'Display Name（可选）'),
                      ),
                    TextField(
                      key: authEmailKey,
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    TextField(
                      key: authPasswordKey,
                      controller: pwController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    const SizedBox(height: 8),
                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: forgotButtonKey,
                          onPressed: () {
                            _showForgotPasswordDialog(
                              rootContext,
                              presetEmail: emailController.text,
                            );
                          },
                          child: const Text('忘记密码？'),
                        ),
                      ),
                    TextButton(
                      key: authToggleKey,
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(isLogin ? '没有账号？去注册' : '已有账号？去登录'),
                    ),
                    const SizedBox(height: 6),
                    DefaultTextStyle(
                      style: Theme.of(rootContext).textTheme.bodySmall!.copyWith(
                            color:
                                Theme.of(rootContext).colorScheme.onSurfaceVariant,
                          ),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('继续即表示你同意 '),
                          InkWell(
                            onTap: () => openLegal(LegalDoc.terms),
                            child: Text(
                              '《利用规约》',
                              style: TextStyle(
                                color: Theme.of(rootContext).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text(' 与 '),
                          InkWell(
                            onTap: () => openLegal(LegalDoc.privacy),
                            child: Text(
                              '《隐私政策》',
                              style: TextStyle(
                                color: Theme.of(rootContext).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text('。'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  key: authCancelKey,
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  key: authSubmitKey,
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

                      if (rootContext.mounted) {
                        Navigator.pop(dialogCtx);
                      }
                    } catch (e) {
                      final msg = _prettyAuthError(e);
                      if (rootContext.mounted) {
                        _showMessage(rootContext, msg);
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

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除？'),
            content: const Text('此操作将清空所有本地数据，无法恢复。'),
            actions: [
              TextButton(
                key: deleteCancelKey,
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                key: deleteConfirmKey,
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
