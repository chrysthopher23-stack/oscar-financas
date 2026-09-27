import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/access_mode.dart';

final class LocalAccessSessionRepository implements AccessSessionRepository {
  LocalAccessSessionRepository(this._preferences);

  static const _key = 'access.mode';
  final SharedPreferences _preferences;

  @override
  Future<void> clear() => _preferences.remove(_key);

  @override
  Future<AccessSession?> restore() async {
    final stored = _preferences.getString(_key);
    if (stored == null) return null;
    final mode = AccessMode.values
        .where((value) => value.name == stored)
        .firstOrNull;
    return mode == null ? null : AccessSession(mode);
  }

  @override
  Future<void> save(AccessSession session) =>
      _preferences.setString(_key, session.mode.name);
}

final class DevelopmentIdentityGateway implements FederatedIdentityGateway {
  const DevelopmentIdentityGateway();

  @override
  Future<AccessSession> signIn(AccessMode provider) async {
    if (kReleaseMode) {
      throw StateError('Federated identity provider is not configured.');
    }
    if (provider == AccessMode.localGuest) {
      throw ArgumentError.value(provider, 'provider');
    }
    return AccessSession(provider);
  }
}
