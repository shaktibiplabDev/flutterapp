import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'providers/auth_provider.dart';
import 'services/google_auth_service.dart';
import 'services/api_interceptor.dart';
import 'services/firebase_messaging_service.dart';
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
import 'screens/home/business_profile_screen.dart';
import 'screens/home/settings_screen.dart';
import 'screens/legal/legal_page_screen.dart';
import 'screens/auth/email_verification_required_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GoogleAuthService.initialize();

  // Initialize Firebase Messaging
  final firebaseMessaging = FirebaseMessagingService();
  await firebaseMessaging.initialize();

  // Initialize Crashlytics
  await _initializeCrashlytics();

  runApp(const MyApp());
}

Future<void> _initializeCrashlytics() async {
  // Pass all uncaught "fatal" errors from the framework to Crashlytics
  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };

  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Enable Crashlytics in all modes (including debug for testing)
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
  debugPrint('📊 Crashlytics enabled for testing');
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
        navigatorKey: ApiInterceptor.navigatorKey, // Set the navigator key
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
          // Auth Routes
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/reset-password': (context) => const ResetPasswordScreen(email: ''),
          '/verify-email': (context) => const VerifyEmailScreen(email: ''),
          '/google-phone': (context) => const GooglePhoneScreen(),
          '/setup-password': (context) => const SetupPasswordScreen(),
          '/email-verification-required': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as String?;
            return EmailVerificationRequiredScreen(email: args ?? '');
          },
          
          // Main App Routes
          '/home': (context) => const HomeScreen(),
          '/wallet': (context) => const WalletScreen(),
          '/vehicles': (context) => const VehiclesScreen(),
          '/bookings': (context) => const BookingsScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/business-profile': (context) => const BusinessProfileScreen(),
          '/settings': (context) => const SettingsScreen(),
          
          // Legal Routes
          '/legal/privacy': (context) => const LegalPageScreen(slug: 'privacy-policy'),
          '/legal/terms': (context) => const LegalPageScreen(slug: 'terms-of-service'),
          '/legal/about': (context) => const LegalPageScreen(slug: 'about'),
        },
      ),
    );
  }
}