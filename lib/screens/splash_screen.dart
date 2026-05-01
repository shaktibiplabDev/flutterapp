import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _logoAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _rotationAnimation;
  
  String _loadingMessage = "Initializing...";
  int _loadingStep = 0;
  bool _isCheckingAuth = false;
  
  final List<String> _loadingMessages = [
    "Initializing...",
    "Checking credentials...",
    "Validating session...",
    "Loading dashboard...",
    "Almost there...",
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
    
    // Start loading simulation
    _startLoadingSimulation();
    
    // Check auth after minimum splash duration
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!_isCheckingAuth && mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  void _startLoadingSimulation() {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() {
          _loadingStep = 1;
          _loadingMessage = _loadingMessages[1];
        });
      }
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _loadingStep = 2;
          _loadingMessage = _loadingMessages[2];
        });
      }
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _loadingStep = 3;
          _loadingMessage = _loadingMessages[3];
        });
      }
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        setState(() {
          _loadingStep = 4;
          _loadingMessage = _loadingMessages[4];
        });
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    if (_isCheckingAuth || !mounted) return;
    
    _isCheckingAuth = true;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Load stored auth data from secure storage
      await authProvider.loadStoredAuthData();
      
      final isAuthenticated = authProvider.isAuthenticated;
      
      if (isAuthenticated) {
        // Update loading message
        if (mounted) {
          setState(() {
            _loadingMessage = "Validating session...";
          });
        }
        
        // Validate token by fetching current user
        final isValid = await authProvider.validateToken();
        
        if (isValid && mounted) {
          // Refresh user data to get latest info
          await authProvider.refreshUser();
          
          // Double check authentication after refresh
          if (authProvider.isAuthenticated && mounted) {
            // Navigate to home screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomeScreen(),
                settings: const RouteSettings(name: '/home'),
              ),
            );
            return;
          }
        }
        
        // Token invalid or refresh failed - logout
        if (mounted) {
          await authProvider.logout();
          _navigateToLogin();
        }
      } else {
        // Not authenticated, go to login
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('Auth check error: $e');
      
      // Check if it's a network error
      if (e.toString().contains('SocketException') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('Network is unreachable')) {
        // Show network error dialog
        if (mounted) {
          _showNetworkErrorDialog();
        }
      } else {
        _navigateToLogin();
      }
    } finally {
      _isCheckingAuth = false;
    }
  }

  void _navigateToLogin() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
          settings: const RouteSettings(name: '/login'),
        ),
      );
    }
  }

  void _showNetworkErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.red),
            SizedBox(width: 8),
            Text('Network Error'),
          ],
        ),
        content: const Text(
          'Unable to connect to the server. Please check your internet connection and try again.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Retry connection
              _checkAuthAndNavigate();
            },
            child: const Text('Retry'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: const Text('Go to Login'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Animated Background Gradient
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white,
                      Colors.grey.shade50,
                      Colors.grey.shade100.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),
          
          // Animated Background Circles
          ..._buildBackgroundCircles(screenWidth, screenHeight),
          
          SafeArea(
            child: Column(
              children: [
                // Top decorative element
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.grey.shade400,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const Spacer(flex: 2),
                
                // Main Animation Section
                _buildAnimationSection(screenHeight, screenWidth),
                
                const Spacer(flex: 1),
                
                // App Name Section
                _buildAppNameSection(),
                
                const Spacer(flex: 1),
                
                // Loading Section
                _buildLoadingSection(),
                
                const SizedBox(height: 20),
                
                // Powered by Section
                _buildPoweredBySection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBackgroundCircles(double width, double height) {
    return [
      // Top-right circle
      Positioned(
        top: -50,
        right: -50,
        child: AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * 3.14,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.grey.shade200.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      
      // Bottom-left circle
      Positioned(
        bottom: -80,
        left: -80,
        child: AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: -_rotationAnimation.value * 2.14,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.grey.shade200.withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      
      // Center decorative circle
      Positioned(
        left: width / 2 - 100,
        top: height / 2 - 100,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: 0.5 + (_scaleAnimation.value * 0.3),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.grey.shade100.withOpacity(0.4),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildAnimationSection(double screenHeight, double screenWidth) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: TweenAnimationBuilder(
        tween: Tween<double>(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 1000),
        builder: (context, double scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              height: screenHeight * 0.4,
              width: screenWidth * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(200),
                child: Lottie.asset(
                  'assets/animations/car_loading.json',
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: true,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade300,
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.directions_car,
                        size: 100,
                        color: Colors.grey.shade600,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAppNameSection() {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _logoAnimation,
        child: Column(
          children: [
            // App Name with enhanced styling
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade900,
                    Colors.grey.shade700,
                    Colors.grey.shade600,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              child: const Text(
                'EKiraya',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                  height: 1.2,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Tagline with animated underline
            Stack(
              children: [
                Text(
                  'Your Vehicle Rental Partner',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Positioned(
                  bottom: -4,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _logoAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 100 * _logoAnimation.value,
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade300,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Version badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Version 2.0.0',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Animated progress indicator
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade700),
              backgroundColor: Colors.grey.shade200,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Animated dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _loadingStep >= index ? 8 : 4,
                height: _loadingStep >= index ? 8 : 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _loadingStep >= index 
                      ? Colors.grey.shade700 
                      : Colors.grey.shade300,
                ),
              );
            }),
          ),
          
          const SizedBox(height: 12),
          
          // Loading message with fade animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _loadingMessage,
              key: ValueKey(_loadingMessage),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                letterSpacing: 0.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoweredBySection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        child: Column(
          children: [
            // Decorative line
            Container(
              width: 120,
              height: 1,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade300,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            
            // Powered by text with icon
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.flash_on,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Text(
                  'Powered by Versaero',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.bolt,
                  size: 12,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Copyright text
            Text(
              '© ${DateTime.now().year} EKiraya. All rights reserved.',
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey.shade300,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}