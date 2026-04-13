import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class GoogleSignInButton extends StatelessWidget {
  final bool isRegisterMode;
  final VoidCallback? onSuccess;
  
  const GoogleSignInButton({
    super.key,
    this.isRegisterMode = false,
    this.onSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return OutlinedButton(
          onPressed: authProvider.isLoading 
              ? null 
              : () async {
                  final success = await authProvider.signInWithGoogle(context);
                  
                  if (success && context.mounted) {
                    if (authProvider.needsPhoneForGoogle) {
                      Navigator.pushReplacementNamed(context, '/google-phone');
                    } else if (onSuccess != null) {
                      onSuccess!();
                    } else if (authProvider.user?.needsPasswordSetup == true) {
                      Navigator.pushReplacementNamed(context, '/setup-password');
                    } else if (authProvider.user?.isEmailVerified == false) {
                      Navigator.pushReplacementNamed(
                        context, 
                        '/email-verification-required',
                        arguments: authProvider.user?.email,
                      );
                    } else {
                      Navigator.pushReplacementNamed(context, '/home');
                    }
                  } else if (context.mounted && authProvider.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(authProvider.errorMessage!),
                        backgroundColor: Colors.grey.shade800,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  }
                },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: Colors.grey.shade300),
            backgroundColor: Colors.white,
            foregroundColor: Colors.grey.shade900,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Image.asset(
                  'assets/icons/google.png',
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: Colors.grey.shade700,
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isRegisterMode ? 'Sign up with Google' : 'Continue with Google',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}