import 'dart:async';
import 'package:flutter/material.dart';
import 'package:contact_list/services/auth_service.dart';
import 'package:contact_list/pages/home_page.dart';
import 'package:contact_list/pages/login_screen.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    
    // Set system UI overlay style
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    
    // Ensure the first frame is rendered before starting the navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Add a small delay to ensure the splash screen is visible
      Future.delayed(const Duration(milliseconds: 100), _navigateToNextScreen);
    });
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for both the delay and any async operations
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    
    try {
      final userId = await AuthService().getRememberedUserId();
      final nextScreen = userId != null
          ? HomePage(
              username: await AuthService().getRememberedUsername() ?? 'User',
              userId: userId,
            )
          : const LoginScreen();

      if (!mounted) return;
      
      // Use a fade transition for a smoother experience
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = 0.0;
            const end = 1.0;
            const curve = Curves.easeInOut;
            
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var fadeAnimation = animation.drive(tween);
            
            return FadeTransition(
              opacity: fadeAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      // If there's an error, navigate to login screen
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Match background color
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Union.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Title at top
            Positioned(
              top: 50,
              left: 0,
              right: 0,
              child: const Text(
                "Call App",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // “Join Now” button at bottom
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final userId = await AuthService().getRememberedUserId();
                    final nextScreen = userId != null
                        ? HomePage(
                            username: await AuthService()
                                    .getRememberedUsername() ??
                                'User',
                            userId: userId,
                          )
                        : LoginScreen();

                    if (!mounted) return;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => nextScreen),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 70, vertical: 15),
                  ),
                  child: const Text(
                    "JOIN NOW",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
