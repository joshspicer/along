import 'package:flutter/services.dart';

abstract final class AlongHaptics {
  static Future<void> selection() => HapticFeedback.selectionClick();
  static Future<void> action() => HapticFeedback.lightImpact();
  static Future<void> success() => HapticFeedback.mediumImpact();
  static Future<void> warning() => HapticFeedback.heavyImpact();
}
