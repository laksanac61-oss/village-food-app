import 'dart:math';

import 'package:flutter/material.dart';

/// A bouncing noodle bowl with little dishes floating up around it. Drawn with icons, so it
/// needs no image files.
class FoodAnimation extends StatefulWidget {
  const FoodAnimation({super.key, this.size = 150});
  final double size;

  @override
  State<FoodAnimation> createState() => _FoodAnimationState();
}

class _FoodAnimationState extends State<FoodAnimation> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  static const _floaters = [
    (Icons.local_pizza, Colors.deepOrange, -0.34, 0.0),
    (Icons.icecream, Colors.pink, 0.36, 0.2),
    (Icons.lunch_dining, Colors.brown, -0.12, 0.4),
    (Icons.emoji_food_beverage, Colors.teal, 0.18, 0.6),
    (Icons.bakery_dining, Colors.amber, -0.40, 0.8),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox.square(
      dimension: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // Two hops per loop, with a squash when the bowl lands.
          final hop = sin(t * 4 * pi).abs();
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final (icon, color, x, phase) in _floaters)
                Builder(
                  builder: (_) {
                    final p = (t + phase) % 1;
                    return Positioned(
                      left: s / 2 + x * s - s * 0.08 + sin(p * 2 * pi) * s * 0.04,
                      top: s * 0.62 - p * s * 0.62,
                      child: Opacity(
                        opacity: sin(p * pi).clamp(0, 1),
                        child: Transform.scale(
                          scale: 0.6 + 0.4 * sin(p * pi),
                          child: Icon(icon, color: color, size: s * 0.16),
                        ),
                      ),
                    );
                  },
                ),
              Positioned(
                bottom: s * 0.06,
                child: Container(
                  width: s * (0.42 - 0.12 * hop),
                  height: s * 0.05,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(s),
                  ),
                ),
              ),
              Positioned(
                bottom: s * 0.08 + hop * s * 0.14,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(1 + (1 - hop) * 0.08, 1 - (1 - hop) * 0.08, 1)
                    ..rotateZ(sin(t * 4 * pi) * 0.08),
                  child: Icon(Icons.ramen_dining, color: Colors.orange.shade700, size: s * 0.5),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
