import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'legal_page.dart';
import '../utils/legal_i18n.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const String route = '/onboarding';

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final settings = context.read<SettingsProvider>();
    await settings.setSeenOnboarding(true);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  void _openLegal(LegalDoc doc) {
    final title = doc == LegalDoc.privacy
        ? LegalI18n.title(context, LegalTitleKey.privacy)
        : LegalI18n.title(context, LegalTitleKey.terms);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalPage(
          titleText: title,
          doc: doc,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = <_Step>[
      const _Step(
        icon: Icons.flag_outlined,
        title: '目标',
        desc: '设定目标与优先度，把“想做的事”变成清晰的路线图。',
      ),
      const _Step(
        icon: Icons.calendar_month_outlined,
        title: '日程',
        desc: '把目标拆成任务，放进日历并打卡完成，进度一目了然。',
      ),
      const _Step(
        icon: Icons.auto_stories_outlined,
        title: '反思',
        desc: '记录投入与心得，持续优化节奏，越用越顺手。',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：跳过
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('跳过'),
                  ),
                ],
              ),
            ),

            // 中部：分页内容
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _OnboardingCard(step: steps[i]),
              ),
            ),

            // ✅ 底部：条款/隐私入口
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: DefaultTextStyle(
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('继续即表示你同意 '),
                    InkWell(
                      onTap: () => _openLegal(LegalDoc.terms),
                      child: Text(
                        '《利用规约》',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text(' 与 '),
                    InkWell(
                      onTap: () => _openLegal(LegalDoc.privacy),
                      child: Text(
                        '《隐私政策》',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const Text('。'),
                  ],
                ),
              ),
            ),

            // 底部：指示器 + 下一步/开始
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  _Dots(count: steps.length, index: _index),
                  const Spacer(),
                  if (_index < steps.length - 1)
                    ElevatedButton(
                      onPressed: () {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      },
                      child: const Text('下一步'),
                    )
                  else
                    ElevatedButton(
                      onPressed: _finish,
                      child: const Text('开始使用'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String desc;

  const _Step({required this.icon, required this.title, required this.desc});
}

class _OnboardingCard extends StatelessWidget {
  final _Step step;
  const _OnboardingCard({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(step.icon, size: 72),
                const SizedBox(height: 16),
                Text(step.title, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  step.desc,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 6),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: active ? cs.primary : cs.outlineVariant,
          ),
        );
      }),
    );
  }
}

