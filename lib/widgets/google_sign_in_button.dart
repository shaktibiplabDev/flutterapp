import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_sign_in_service.dart';

class GoogleSignInButton extends StatefulWidget {
  final Function(GoogleSignInAccount) onSignInSuccess;
  final Function(String) onSignInError;

  const GoogleSignInButton({
    Key? key,
    required this.onSignInSuccess,
    required this.onSignInError,
  }) : super(key: key);

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        icon: _isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Image.asset(
                'assets/images/google_logo.png',
                height: 24,
                width: 24,
              ),
        label: Text(
          _isLoading ? 'Signing in...' : 'Sign in with Google',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? account = await GoogleSignInService.signIn();
      
      if (account != null) {
        // Get authentication tokens
        final GoogleSignInAuthentication? auth = await account.authentication;
        
        // Send data to backend or handle as needed
        widget.onSignInSuccess(account);
      } else {
        widget.onSignInError('Google Sign-In was cancelled');
      }
    } catch (error) {
      widget.onSignInError('Google Sign-In failed: ${error.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
