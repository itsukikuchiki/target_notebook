import 'package:flutter/material.dart';


class SimpleBarChart extends StatelessWidget {
final Map<DateTime, double> data; // 7天数据
const SimpleBarChart({super.key, required this.data});


@override
Widget build(BuildContext context) {
final entries = data.entries.toList()
..sort((a, b) => a.key.compareTo(b.key));
final maxVal = entries.fold<double>(0, (m, e) => e.value > m ? e.value : m);
return Row(
crossAxisAlignment: CrossAxisAlignment.end,
children: [
for (final e in entries)
Expanded(
child: Column(
mainAxisAlignment: MainAxisAlignment.end,
children: [
Expanded(
child: Align(
alignment: Alignment.bottomCenter,
child: FractionallySizedBox(
heightFactor: maxVal == 0 ? 0 : (e.value / maxVal).clamp(0, 1),
child: Container(
margin: const EdgeInsets.symmetric(horizontal: 4),
decoration: BoxDecoration(
borderRadius: BorderRadius.circular(6),
color: Theme.of(context).colorScheme.primary.withOpacity(.25),
),
),
),
),
),
const SizedBox(height: 6),
Text(_weekday(e.key), style: const TextStyle(fontSize: 12, color: Colors.black54)),
],
),
),
],
);
}


String _weekday(DateTime d) {
const w = ['日','一','二','三','四','五','六'];
return w[d.weekday % 7];
}
}
