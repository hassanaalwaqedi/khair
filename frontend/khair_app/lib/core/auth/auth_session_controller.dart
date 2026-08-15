import 'dart:async';

/// Coordinates authentication expiry between the HTTP layer and AuthBloc.
///
/// A protected API request can discover an expired/revoked token before any UI
/// does. Broadcasting that fact keeps secure storage, navigation, and visible
/// account state in sync.
class AuthSessionController {
  final StreamController<void> _expiredController =
      StreamController<void>.broadcast(sync: true);

  Stream<void> get expired => _expiredController.stream;

  void notifyExpired() => _expiredController.add(null);

  Future<void> dispose() => _expiredController.close();
}
