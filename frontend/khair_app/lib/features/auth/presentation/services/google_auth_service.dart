import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Obtains an ID token only; Khair's API verifies the token and owns account
/// creation/linking. No identity attributes from this client are trusted.
class GoogleAuthService {
  // OAuth client IDs are public identifiers, not secrets. Keeping this Khair
  // project default means a normal VS Code web run still opens Google's account
  // chooser; deployments can override it with --dart-define.
  static const _webClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1061209811578-nqgg6gmad0vvru94rnnfku51bdq9b0uk.apps.googleusercontent.com',
  );
  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1061209811578-nqgg6gmad0vvru94rnnfku51bdq9b0uk.apps.googleusercontent.com',
  );

  GoogleAuthService()
      : _signIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
          clientId: _webClientId.isEmpty ? null : _webClientId,
          // serverClientId is NOT supported on Web — only pass it on mobile.
          serverClientId: kIsWeb
              ? null
              : (_serverClientId.isEmpty ? null : _serverClientId),
        );

  final GoogleSignIn _signIn;

  /// Returns an ID token (mobile) or access token (web) for the backend to verify.
  Future<String?> obtainIdToken() async {
    GoogleSignInAccount? account;
    try {
      account = await _signIn.signIn();
    } catch (_) {
      final origin = kIsWeb ? Uri.base.origin : 'this app';
      throw GoogleAuthException(
        'Google rejected sign-in from $origin. In Google Cloud Console, add this exact value under Authorized JavaScript origins, then try again.',
      );
    }
    if (account == null) return null;
    final authentication = await account.authentication;

    // Prefer ID token (available on mobile), fall back to access token (web).
    final token = authentication.idToken ?? authentication.accessToken;
    if (token == null || token.isEmpty) {
      throw const GoogleAuthException(
          'Google did not return a secure identity token.');
    }
    return token;
  }
}

class GoogleAuthException implements Exception {
  final String message;
  const GoogleAuthException(this.message);
  @override
  String toString() => message;
}
