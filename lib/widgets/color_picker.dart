import 'package:flutter/material.dart';

/// 轻量颜色选择器：
/// - selected: 当前选中颜色（ARGB int），null 表示“未选择 / 继承默认”
/// - onChanged: 点击颜色或清除时回调
class ColorPicker extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;

  /// 可复用的稳定色板（与你 GoalProvider.effectiveColorInt 同风格）
  static const List<int> palette = <int>[
    0xFFEF5350, // red
    0xFFAB47BC, // purple
    0xFF5C6BC0, // indigo
    0xFF29B6F6, // lightBlue
    0xFF26A69A, // teal
    0xFF66BB6A, // green
    0xFFFFCA28, // amber
    0xFFFFA726, // orange
    0xFF8D6E63, // brown
    0xFF78909C, // blueGrey
  ];

  const ColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(int c) {
      final isSelected = selected == c;

      return InkWell(
        onTap: () => onChanged(c),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(right: 10, bottom: 10),
          decoration: BoxDecoration(
            color: Color(c),
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 2,
            ),
          ),
          child: isSelected
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('颜色（可选）'),
        const SizedBox(height: 8),
        Wrap(
          children: [
            ...palette.map(chip),
            TextButton.icon(
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.backspace_outlined, size: 18),
              label: const Text('清除'),
            ),
          ],
        ),
      ],
    );
  }
}

