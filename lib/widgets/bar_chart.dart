import 'dart:math';

import 'package:flutter/material.dart';

/// A simple bar chart: one bar per period with its label underneath and the amount on top.
/// Tapping a bar selects it. The last bar (the current period) is drawn darker.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.topLabels,
    this.selected,
    this.onSelect,
    this.height = 200,
  });

  final List<double> values;
  final List<String> labels;
  final List<String> topLabels;
  final int? selected;
  final ValueChanged<int>? onSelect;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final top = values.fold<double>(0, max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: InkWell(
                onTap: onSelect == null ? null : () => onSelect!(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (values[i] > 0)
                        FittedBox(
                          child: Text(
                            topLabels[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: i == selected ? FontWeight.bold : null,
                            ),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: top == 0 ? 2 : max(2, (height - 44) * values[i] / top),
                        decoration: BoxDecoration(
                          color: i == selected
                              ? scheme.primary
                              : i == values.length - 1
                              ? scheme.primary.withValues(alpha: 0.7)
                              : scheme.primary.withValues(alpha: 0.35),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(labels[i], style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
