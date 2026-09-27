import 'package:flutter/foundation.dart';

import '../domain/access_mode.dart';

enum AuthGatewayStatus { loading, signedOut, signingIn, signedIn, failure }

final class AuthGatewayState {
  const AuthGatewayState({required this.status, this.session, this.errorCode});

  const AuthGatewayState.loading() : this(status: AuthGatewayStatus.loading);

  final AuthGatewayStatus status;
  final AccessSession? session;
  final String? errorCode;
}

final class AuthGatewayController extends ChangeNotifier {
  AuthGatewayController({
    required this._sessionRepository,
    required this._identityGateway,
  });

  final AccessSessionRepository _sessionRepository;
  final FederatedIdentityGateway _identityGateway;
  AuthGatewayState _state = const AuthGatewayState.loading();

  AuthGatewayState get state => _state;

  Future<void> restore() async {
    final session = await _sessionRepository.restore();
    _state = AuthGatewayState(
      status: session == null
          ? AuthGatewayStatus.signedOut
          : AuthGatewayStatus.signedIn,
      session: session,
    );
    notifyListeners();
  }

  Future<void> continueWithoutAccount() =>
      _complete(const AccessSession(AccessMode.localGuest));

  Future<void> signIn(AccessMode provider) async {
    _state = const AuthGatewayState(status: AuthGatewayStatus.signingIn);
    notifyListeners();
    try {
      await _complete(await _identityGateway.signIn(provider));
    } catch (_) {
      _state = const AuthGatewayState(
        status: AuthGatewayStatus.failure,
        errorCode: 'identity.providerUnavailable',
      );
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _sessionRepository.clear();
    _state = const AuthGatewayState(status: AuthGatewayStatus.signedOut);
    notifyListeners();
  }

  Future<void> _complete(AccessSession session) async {
    await _sessionRepository.save(session);
    _state = AuthGatewayState(
      status: AuthGatewayStatus.signedIn,
      session: session,
    );
    notifyListeners();
  }
}
