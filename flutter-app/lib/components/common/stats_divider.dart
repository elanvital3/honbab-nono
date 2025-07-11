import 'package:flutter/material.dart';

class StatsDivider extends StatelessWidget {
  final double height;
  final double width;
  final Color? color;

  const StatsDivider({
    super.key,
    this.height = 40,
    this.width = 1,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: color ?? Theme.of(context).colorScheme.outline.withOpacity(0.3),
    );
  }
}