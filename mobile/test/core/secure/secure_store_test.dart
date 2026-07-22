import 'package:along/core/secure/secure_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

class _MockStorage extends Mock implements FlutterSecureStorage {}

class _MockUuid extends Mock implements Uuid {}

void main() {
  test(
    'keeps refresh token and stable installation ID in secure storage',
    () async {
      final values = <String, String>{};
      final storage = _MockStorage();
      final uuid = _MockUuid();
      when(() => uuid.v4()).thenReturn('278b731a-d72a-42bc-8852-f99c56b777fe');
      when(
        () => storage.read(
          key: any(named: 'key'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key]! as String;
        return values[key];
      });
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key]! as String;
        values[key] = invocation.namedArguments[#value]! as String;
      });
      when(
        () => storage.delete(
          key: any(named: 'key'),
          iOptions: any(named: 'iOptions'),
          aOptions: any(named: 'aOptions'),
        ),
      ).thenAnswer((invocation) async {
        values.remove(invocation.namedArguments[#key]! as String);
      });
      final secure = FlutterSecureStore(storage: storage, uuid: uuid);

      final firstInstallation = await secure.installationId();
      final secondInstallation = await secure.installationId();
      expect(firstInstallation, secondInstallation);
      verify(() => uuid.v4()).called(1);

      await secure.writeRefreshToken('opaque-refresh-token');
      expect(await secure.readRefreshToken(), 'opaque-refresh-token');
      await secure.clearSession();
      expect(await secure.readRefreshToken(), isNull);
    },
  );
}
