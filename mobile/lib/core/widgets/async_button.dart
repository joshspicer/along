import 'package:flutter/material.dart';

class AsyncButton extends StatelessWidget {
  const AsyncButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.busy = false,
    this.icon,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = busy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 9),
              ],
              Flexible(child: Text(label)),
            ],
          );
    if (outlined) {
      return OutlinedButton(onPressed: busy ? null : onPressed, child: child);
    }
    return FilledButton(onPressed: busy ? null : onPressed, child: child);
  }
}
