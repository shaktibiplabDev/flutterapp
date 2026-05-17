import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '1078723520604-tuke2dok6s5tmo17j0a3pgqh4l3impn7.apps.googleusercontent.com',
    serverClientId: '1078723520604-tuke2dok6s5tmo17j0a3pgqh4l3impn7.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
    ],
  );

  static GoogleSignIn googleSignIn = _googleSignIn;

  // Sign in with Google
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      return account;
    } catch (error) {
      print('Google Sign-In Error: $error');
      return null;
    }
  }

  // Sign out
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (error) {
      print('Google Sign-Out Error: $error');
    }
  }

  // Check if user is signed in
  static Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Get current user
  static Future<GoogleSignInAccount?> getCurrentUser() async {
    try {
      return await _googleSignIn.signInSilently();
    } catch (error) {
      print('Get Current User Error: $error');
      return null;
    }
  }

  // Get authentication tokens
  static Future<GoogleSignInAuthentication?> getAuthTokens() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signInSilently();
      if (account != null) {
        return await account.authentication;
      }
      return null;
    } catch (error) {
      print('Get Auth Tokens Error: $error');
      return null;
    }
  }
}
