import 'package:flutter/material.dart';

import 'common.dart';

/// Colour adjustment that makes food photos look fresher: about 30% more colour, a little more contrast and a
/// slightly warmer tone, while white plates stay white. Applied when showing the photo, so it also covers
/// photos uploaded before and needs no image processing on the server.
const appetizingFilter = ColorFilter.matrix(<double>[
  1.362, -0.236, -0.024, 0, -2, //
  -0.069, 1.172, -0.023, 0, -2,
  -0.068, -0.227, 1.353, 0, -2,
  0, 0, 0, 1, 0,
]);

/// A menu photo with the appetizing filter, or a food icon when the shop hasn't added one.
class FoodPhoto extends StatelessWidget {
  const FoodPhoto(this.url, {super.key});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (url == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primaryContainer, scheme.secondaryContainer],
          ),
        ),
        child: Center(child: Icon(Icons.ramen_dining, size: 48, color: scheme.onPrimaryContainer)),
      );
    }
    return ColorFiltered(colorFilter: appetizingFilter, child: NetPhoto(url!));
  }
}
