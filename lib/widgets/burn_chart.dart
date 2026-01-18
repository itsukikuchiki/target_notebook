// lib/widgets/burn_chart.dart

import 'package:flutter/material.dart';
import '../services/burnup_service.dart';

enum BurnChartType {
  burnup,
  burndown,
}

class BurnChart extends StatelessWidget {
  final List<BurnPoint> points;
  final Color color;
  final BurnChartType type;
  final double height;

  const BurnChart({
    super.key,
    required this.points,
    required this.color,
    this.type = BurnChartType.burnup,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            '暂无数据',
            style: TextStyle(color: Colors.black54),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BurnChartPainter(
          points: points,
          color: color,
          type: type,
        ),
      ),
    );
  }
}

class _BurnChartPainter extends CustomPainter {
  final List<BurnPoint> points;
  final Color color;
  final BurnChartType type;

  _BurnChartPainter({
    required this.points,
    required this.color,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintLine = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintPoint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final paintGrid = Paint()
      ..color = Colors.black12
      ..strokeWidth = 1;

    // ===== 1) 基础参数 =====
    final padding = const EdgeInsets.fromLTRB(24, 12, 12, 24);
    final chartW = size.width - padding.left - padding.right;
    final chartH = size.height - padding.top - padding.bottom;

    final minX = 0;
    final maxX = points.length - 1;

    final values = points.map((e) => e.value).toList();
    final minY = 0;
    final maxY = values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);

    double dx(int i) =>
        padding.left + chartW * (i - minX) / (maxX == 0 ? 1 : maxX);

    double dy(int v) =>
        padding.top + chartH * (1 - v / maxY);

    // ===== 2) 背景网格（Y 轴）=====
    const gridCount = 4;
    for (int i = 0; i <= gridCount; i++) {
      final y = padding.top + chartH * i / gridCount;
      canvas.drawLine(
        Offset(padding.left, y),
        Offset(size.width - padding.right, y),
        paintGrid,
      );
    }

    // ===== 3) 曲线路径 =====
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final x = dx(i);
      final y = dy(points[i].value);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paintLine);

    // ===== 4) 点 =====
    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(
        Offset(dx(i), dy(points[i].value)),
        3,
        paintPoint,
      );
    }

    // ===== 5) 轴标签（最后一个值）=====
    final last = points.last;
    final textPainter = TextPainter(
      text: TextSpan(
        text: last.value.toString(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        dx(points.length - 1) - textPainter.width / 2,
        dy(last.value) - 18,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _BurnChartPainter old) {
    return old.points != points ||
        old.color != color ||
        old.type != type;
  }
}

