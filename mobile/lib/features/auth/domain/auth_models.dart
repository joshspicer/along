class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.displayName,
    this.pairId,
    this.partnerName,
    this.installationId,
  });

  factory AuthAccount.fromJson(Map<String, Object?> json) => AuthAccount(
    id: json['id']! as String,
    displayName: json['display_name']! as String,
    pairId: json['pair_id'] as String?,
    partnerName: json['partner_name'] as String?,
    installationId: json['installation_id'] as String?,
  );

  final String id;
  final String displayName;
  final String? pairId;
  final String? partnerName;
  final String? installationId;

  AuthAccount copyWith({
    String? pairId,
    String? partnerName,
    String? installationId,
  }) => AuthAccount(
    id: id,
    displayName: displayName,
    pairId: pairId ?? this.pairId,
    partnerName: partnerName ?? this.partnerName,
    installationId: installationId ?? this.installationId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'display_name': displayName,
    'pair_id': pairId,
    'partner_name': partnerName,
    'installation_id': installationId,
  };
}

class RecoveryKit {
  const RecoveryKit({
    required this.accountId,
    required this.recoveryHandle,
    required this.codes,
  });

  factory RecoveryKit.fromJson(Map<String, Object?> json) => RecoveryKit(
    accountId: json['account_id']! as String,
    recoveryHandle: json['recovery_handle']! as String,
    codes: (json['codes']! as List<Object?>).cast<String>(),
  );

  final String accountId;
  final String recoveryHandle;
  final List<String> codes;

  String get printable {
    final lines = <String>[
      'Along recovery kit',
      'Account: $recoveryHandle',
      '',
      ...codes,
      '',
      'Each code works once. Keep this page private.',
    ];
    return lines.join('\n');
  }
}

enum AuthStatus { signedOut, signedIn }

class AuthState {
  const AuthState.signedOut()
    : status = AuthStatus.signedOut,
      account = null,
      recoveryKit = null,
      notificationsExplained = false;

  const AuthState.signedIn({
    required this.account,
    required this.notificationsExplained,
    this.recoveryKit,
  }) : status = AuthStatus.signedIn;

  final AuthStatus status;
  final AuthAccount? account;
  final RecoveryKit? recoveryKit;
  final bool notificationsExplained;

  bool get isSignedIn => status == AuthStatus.signedIn && account != null;

  AuthState copyWith({
    AuthAccount? account,
    RecoveryKit? recoveryKit,
    bool clearRecoveryKit = false,
    bool? notificationsExplained,
  }) => AuthState.signedIn(
    account: account ?? this.account!,
    recoveryKit: clearRecoveryKit ? null : recoveryKit ?? this.recoveryKit,
    notificationsExplained:
        notificationsExplained ?? this.notificationsExplained,
  );
}
