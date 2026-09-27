enum AccessMode { localGuest, google, apple }

final class AccessSession {
  const AccessSession(this.mode);
  final AccessMode mode;
}

abstract interface class AccessSessionRepository {
  Future<AccessSession?> restore();
  Future<void> save(AccessSession session);
  Future<void> clear();
}

abstract interface class FederatedIdentityGateway {
  Future<AccessSession> signIn(AccessMode provider);
}
