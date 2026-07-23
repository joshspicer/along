import 'package:flutter/widgets.dart';

class KeyboardDismissalObserver extends NavigatorObserver {
  void _dismissKeyboard() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _dismissKeyboard();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _dismissKeyboard();
  }
}
