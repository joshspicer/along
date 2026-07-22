import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/runtime_config.dart';

enum ServerAvailability { checking, available, unavailable }

class ServerAvailabilityController extends AsyncNotifier<ServerAvailability> {
  @override
  Future<ServerAvailability> build() async {
    final config = ref.watch(runtimeConfigProvider).requireValue;
    final client = Dio(
      BaseOptions(
        baseUrl: config.apiBaseUrl,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        sendTimeout: const Duration(seconds: 3),
      ),
    );
    try {
      final response = await client.get<void>('/health/ready');
      return response.statusCode == 200
          ? ServerAvailability.available
          : ServerAvailability.unavailable;
    } on DioException {
      return ServerAvailability.unavailable;
    } finally {
      client.close();
    }
  }
}

final serverAvailabilityProvider =
    AsyncNotifierProvider<ServerAvailabilityController, ServerAvailability>(
      ServerAvailabilityController.new,
    );
