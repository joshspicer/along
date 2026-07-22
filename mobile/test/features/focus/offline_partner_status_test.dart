import 'package:along/features/auth/domain/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline accounts are explicitly local-only', () {
    const account = AuthAccount(
      id: 'offline-installation',
      displayName: 'You',
      pairId: 'offline-installation',
    );
    expect(account.isOfflineOnly, isTrue);
  });

  test('regular paired accounts are not offline-only', () {
    const account = AuthAccount(
      id: 'account-id',
      displayName: 'Jamie',
      pairId: 'pair-id',
      partnerName: 'Alex',
    );
    expect(account.isOfflineOnly, isFalse);
  });
}
