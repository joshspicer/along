import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

abstract interface class SecureStore {
  Future<String> installationId();
  Future<String?> readRefreshToken();
  Future<void> writeRefreshToken(String token);
  Future<void> clearSession();
}

class FlutterSecureStore implements SecureStore {
  FlutterSecureStore({FlutterSecureStorage? storage, Uuid? uuid})
    : _storage = storage ?? const FlutterSecureStorage(),
      _uuid = uuid ?? const Uuid();

  static const _installationKey = 'along.installation_id';
  static const _refreshKey = 'along.refresh_token';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  static const _androidOptions = AndroidOptions(resetOnError: true);

  @override
  Future<String> installationId() async {
    final existing = await _storage.read(
      key: _installationKey,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final generated = _uuid.v4();
    await _storage.write(
      key: _installationKey,
      value: generated,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
    return generated;
  }

  @override
  Future<String?> readRefreshToken() => _storage.read(
    key: _refreshKey,
    iOptions: _iosOptions,
    aOptions: _androidOptions,
  );

  @override
  Future<void> writeRefreshToken(String token) => _storage.write(
    key: _refreshKey,
    value: token,
    iOptions: _iosOptions,
    aOptions: _androidOptions,
  );

  @override
  Future<void> clearSession() => _storage.delete(
    key: _refreshKey,
    iOptions: _iosOptions,
    aOptions: _androidOptions,
  );
}
