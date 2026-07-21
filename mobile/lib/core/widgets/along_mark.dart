import 'package:flutter/material.dart';

class AlongMark extends StatelessWidget {
  const AlongMark({super.key, this.size = 54});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Along',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-0.55, -0.5),
            child: _shape(context.colorScheme.primary, Alignment.topLeft),
          ),
          Align(
            alignment: const Alignment(0.55, 0.5),
            child: _shape(context.colorScheme.secondary, Alignment.bottomRight),
          ),
        ],
      ),
    ),
  );

  Widget _shape(Color color, Alignment alignment) => Container(
    width: size * 0.62,
    height: size * 0.62,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.23),
    ),
  );
}

extension ThemeContext on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
}
