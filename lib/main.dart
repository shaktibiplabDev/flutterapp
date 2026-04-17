import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/google_auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/auth/google_phone_screen.dart';
import 'screens/auth/setup_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home/wallet_screen.dart';
import 'screens/home/vehicles_screen.dart';
import 'screens/home/bookings_screen.dart';
import 'screens/home/profile_screen.dart';
import 'screens/auth/email_verification_required_screen.dart';

void main() {
  // Initialize Google Sign-In with client IDs
  GoogleAuthService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'EKiraya',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            elevation: 0,
            centerTitle: true,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black,
          ),
        ),
        debugShowCheckedModeBanner: false,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(email: ''),
          '/verify-email': (context) => const VerifyEmailScreen(email: ''),
          '/google-phone': (context) => const GooglePhoneScreen(),
          '/setup-password': (context) => const SetupPasswordScreen(),
          '/home': (context) => const HomeScreen(),
          '/wallet': (context) => const WalletScreen(),
          '/vehicles': (context) => const VehiclesScreen(),
          '/bookings': (context) => const BookingsScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/email-verification-required': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as String?;
            return EmailVerificationRequiredScreen(email: args ?? '');
          },
        },
      ),
    );
  }
}