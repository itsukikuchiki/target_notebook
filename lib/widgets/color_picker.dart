import 'package:flutter/material.dart';

/// =======================
/// Color Picker (Simple & Reusable)
/// =======================
///
/// 用法示例：
///
/// ColorPicker(
///   selected: _color,
///   onChanged: (c) => setState(() => _color = c),
/// )
///
/// - selected == null 表示「未设置 / 继承父级颜色」
/// - 返回值为 int?（Color.value）
class ColorPicker extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onChanged;

  const ColorPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const List<Color> _presetColors = [
    Color(0xFF5C6BC0), // Indigo
    Color(0xFF42A5F5), // Blue
    Color(0xFF26A69A), // Teal
    Color(0xFF66BB6A), // Green
    Color(0xFFFFCA28), // Amber
    Color(0xFFFFA726), // Orange
    Color(0xFFEF5350), // Red
    Color(0xFFEC407A), // Pink
    Color(0xFFAB47BC), // Purple
    Color(0xFF8D6E63), // Brown
    Color(0xFF78909C), // Blue Grey
    Color(0xFF90A4AE), // Grey
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '颜色',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            // ---------- 清除 / 继承 ----------
            _ColorDot(
              color: null,
              selected: selected == null,
              label: '继承',
              onTap: () => onChanged(null),
              borderColor: theme.dividerColor,
            ),

            // ---------- 预设颜色 ----------
            for (final c in _presetColors)
              _ColorDot(
                color: c,
                selected: selected == c.value,
                onTap: () => onChanged(c.value),
              ),
          ],
        ),
      ],
    );
  }
}

/// =======================
/// Single Color Dot
/// =======================

class _ColorDot extends StatelessWidget {
  final Color? color;
  final bool selected;
  final VoidCallback onTap;
  final String? label;
  final Color? borderColor;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
    this.label,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          )
        : Border.all(
            color: borderColor ?? Colors.transparent,
          );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? Colors.transparent,
              border: border,
            ),
            child: color == null
                ? const Icon(Icons.layers, size: 16, color: Colors.black45)
                : null,
          ),
          if (label != null) ...[
            const SizedBox(height: 2),
            Text(
              label!,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

