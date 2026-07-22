import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/along_mark.dart';
import '../../auth/data/auth_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Future<_SecurityData> _data = _load();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(authControllerProvider).requireValue.account!;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Account and devices'),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async => setState(() => _data = _load()),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Card(
                child: ListTile(
                  minTileHeight: 76,
                  leading: CircleAvatar(
                    backgroundColor: context.colorScheme.primary,
                    foregroundColor: context.colorScheme.onPrimary,
                    child: Text(
                      account.displayName.characters.first.toUpperCase(),
                    ),
                  ),
                  title: Text(account.displayName),
                  subtitle: Text(
                    account.partnerName == null
                        ? 'Private account'
                        : 'Paired with ${account.partnerName}',
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 18),
              Text('Passkeys', style: context.textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<_SecurityData>(
                future: _data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Card(
                      child: ListTile(
                        title: Text('Security details could not load'),
                        subtitle: Text('Pull down to try again.'),
                      ),
                    );
                  }
                  final data = snapshot.data!;
                  return Column(
                    children: [
                      for (final passkey in data.passkeys)
                        _RevocableTile(
                          icon: Icons.key_rounded,
                          title: passkey['label']! as String,
                          subtitle: 'Created ${_date(passkey['created_at'])}',
                          onRevoke: () => _revoke(
                            'Revoke this passkey?',
                            () => ref
                                .read(authRepositoryProvider)
                                .revokePasskey(passkey['id']! as String),
                          ),
                        ),
                      ListTile(
                        minTileHeight: 56,
                        leading: const Icon(Icons.add_rounded),
                        title: const Text('Add a passkey'),
                        onTap: _addPasskey,
                      ),
                      const Divider(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Signed-in sessions',
                          style: context.textTheme.titleLarge,
                        ),
                      ),
                      for (final session in data.sessions)
                        _RevocableTile(
                          icon: Icons.devices_outlined,
                          title: session['installation_name']! as String,
                          subtitle: session['current'] == true
                              ? 'This session'
                              : 'Last used ${_date(session['last_seen_at'])}',
                          onRevoke: () => _revoke(
                            'Sign out this session?',
                            () => session['current'] == true
                                ? ref
                                      .read(authControllerProvider.notifier)
                                      .logout()
                                : ref
                                      .read(authRepositoryProvider)
                                      .revokeSession(session['id']! as String),
                          ),
                        ),
                      const Divider(height: 32),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Device installations',
                          style: context.textTheme.titleLarge,
                        ),
                      ),
                      for (final install in data.installations)
                        _RevocableTile(
                          icon: Icons.phone_iphone_rounded,
                          title: install['name']! as String,
                          subtitle: install['platform']! as String,
                          onRevoke: () => _revoke(
                            'Revoke this installation?',
                            () async {
                              await ref
                                  .read(authRepositoryProvider)
                                  .revokeInstallation(install['id']! as String);
                              if (install['id'] == account.installationId) {
                                await ref
                                    .read(authControllerProvider.notifier)
                                    .logout();
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const Divider(height: 32),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.shield_outlined),
                title: const Text('Replace recovery codes'),
                subtitle: const Text(
                  'Old unused codes stop working immediately.',
                ),
                onTap: _replaceRecoveryCodes,
              ),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Sign out'),
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
              const Divider(height: 32),
              ListTile(
                minTileHeight: 56,
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Advanced'),
                onTap: () => context.push('/settings/advanced'),
              ),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) => ListTile(
                  leading: const AlongMark(size: 34),
                  title: const Text('Along'),
                  subtitle: Text(
                    'Version ${snapshot.data?.version ?? '—'} (${snapshot.data?.buildNumber ?? '—'}) · ${AppConfig.gitCommit}',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_SecurityData> _load() async {
    final repository = ref.read(authRepositoryProvider);
    final values = await Future.wait([
      repository.passkeys(),
      repository.sessions(),
      repository.installations(),
    ]);
    return _SecurityData(
      passkeys: values[0],
      sessions: values[1],
      installations: values[2],
    );
  }

  Future<void> _addPasskey() async {
    try {
      await ref.read(authRepositoryProvider).addPasskey();
      if (mounted) {
        setState(() => _data = _load());
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = friendlyNetworkError(error));
      }
    }
  }

  Future<void> _replaceRecoveryCodes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace recovery codes?'),
        content: const Text(
          'Every old recovery code will stop working. Save the replacement kit before leaving.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      final kit = await ref
          .read(authRepositoryProvider)
          .regenerateRecoveryCodes();
      await SharePlus.instance.share(
        ShareParams(subject: 'Along recovery kit', text: kit.printable),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = friendlyNetworkError(error));
      }
    }
  }

  Future<void> _revoke(String prompt, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(prompt),
        content: const Text('This takes effect immediately.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await action();
      if (mounted) {
        setState(() => _data = _load());
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = friendlyNetworkError(error));
      }
    }
  }

  String _date(Object? value) {
    if (value is! String) {
      return 'recently';
    }
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? 'recently'
        : '${parsed.toLocal().month}/${parsed.toLocal().day}/${parsed.toLocal().year}';
  }
}

class _SecurityData {
  const _SecurityData({
    required this.passkeys,
    required this.sessions,
    required this.installations,
  });

  final List<Map<String, Object?>> passkeys;
  final List<Map<String, Object?>> sessions;
  final List<Map<String, Object?>> installations;
}

class _RevocableTile extends StatelessWidget {
  const _RevocableTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onRevoke,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 64,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: IconButton(
      tooltip: 'Revoke $title',
      onPressed: onRevoke,
      icon: const Icon(Icons.remove_circle_outline),
    ),
  );
}
