import 'generated_commit.dart';

abstract final class AppConfig {
  static const productionApiBaseUrl = 'https://along.spicer.dev';
  static const developmentPasskeyApiBaseUrl = 'https://along-dev.spicer.dev';
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'ALONG_API_BASE_URL',
  );
  static const _isRelease = bool.fromEnvironment('dart.vm.product');
  static String get defaultApiBaseUrl => _configuredApiBaseUrl.isNotEmpty
      ? _configuredApiBaseUrl
      : _isRelease
      ? productionApiBaseUrl
      : 'http://localhost:8080';
  static const defaultApnsEnvironment = String.fromEnvironment(
    'ALONG_APNS_ENVIRONMENT',
    defaultValue: 'production',
  );
  static const gitCommit = String.fromEnvironment(
    'ALONG_GIT_COMMIT',
    defaultValue: generatedGitCommit,
  );
}
