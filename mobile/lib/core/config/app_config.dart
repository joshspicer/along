import 'generated_commit.dart';

abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'ALONG_API_BASE_URL',
    defaultValue: 'https://along.spicer.dev',
  );
  static const apnsEnvironment = String.fromEnvironment(
    'ALONG_APNS_ENVIRONMENT',
    defaultValue: 'production',
  );
  static const gitCommit = String.fromEnvironment(
    'ALONG_GIT_COMMIT',
    defaultValue: generatedGitCommit,
  );

  static Uri get webSocketUri {
    final httpUri = Uri.parse(apiBaseUrl);
    return httpUri.replace(
      scheme: httpUri.scheme == 'https' ? 'wss' : 'ws',
      path: '/v1/ws',
      query: null,
    );
  }
}
