import '../../../core/database/app_database.dart';
import '../../../core/network/token_coordinator.dart';
import '../../auth/domain/auth_models.dart';

class PairRepository {
  PairRepository(this._tokens, this._database);

  final TokenCoordinator _tokens;
  final AppDatabase _database;

  Future<Uri> createInvite() async {
    final response = await _tokens.client.post<Map<String, Object?>>(
      '/v1/pair/invites',
      data: const <String, Object?>{},
    );
    final invite = response.data!['invite']! as Map<String, Object?>;
    return Uri.parse(invite['url']! as String);
  }

  Future<AuthAccount> accept(String tokenOrUrl) async {
    final token = _extractToken(tokenOrUrl);
    await _tokens.client.post<void>(
      '/v1/pair/accept',
      data: <String, Object?>{'token': token},
    );
    return refreshAccount();
  }

  Future<AuthAccount> refreshAccount() async {
    final response = await _tokens.client.get<Map<String, Object?>>('/v1/me');
    final account = AuthAccount.fromJson(
      response.data!['account']! as Map<String, Object?>,
    );
    final profile = await _database.profile();
    await _database.saveProfile(
      account,
      notificationsExplained: profile?.$2 ?? false,
    );
    return account;
  }

  String _extractToken(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return trimmed;
  }
}
