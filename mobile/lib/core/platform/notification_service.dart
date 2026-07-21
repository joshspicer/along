import 'package:flutter/services.dart';

class NotificationPermissionResult {
  const NotificationPermissionResult({required this.granted, this.apnsToken});

  final bool granted;
  final String? apnsToken;
}

class NotificationService {
  const NotificationService();

  static const _channel = MethodChannel('com.joshspicer.along/notifications');

  Future<NotificationPermissionResult> request() async {
    final result = await _channel.invokeMapMethod<String, Object?>('request');
    return NotificationPermissionResult(
      granted: result?['granted'] == true,
      apnsToken: result?['token'] as String?,
    );
  }
}
