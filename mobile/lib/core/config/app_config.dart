import 'generated_commit.dart';

abstract final class AppConfig {
  static const defaultApiBaseUrl = String.fromEnvironment(
    'ALONG_API_BASE_URL',
    defaultValue: 'https://along.spicer.dev',
  );
  static const defaultApnsEnvironment = String.fromEnvironment(
    'ALONG_APNS_ENVIRONMENT',
    defaultValue: 'production',
  );
  static const gitCommit = String.fromEnvironment(
    'ALONG_GIT_COMMIT',
    defaultValue: generatedGitCommit,
  );
}
