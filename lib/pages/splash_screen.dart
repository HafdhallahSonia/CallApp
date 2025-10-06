// screens/splash_screen.dart
import 'dart:async';

import 'package:contact_list/db/auth_service.dart';
import 'package:contact_list/pages/home_page.dart';
import 'package:contact_list/pages/login_screen.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNextScreen();
  }

  void _navigateToNextScreen() async {
    // Simule un temps de chargement (optionnel)
    await Future.delayed(Duration(milliseconds: 3000));

    final userId = await AuthService().getRememberedUserId();
    final nextScreen = userId != null
        ? HomePage(
            username:
                await AuthService().getRememberedUsername() ?? 'Utilisateur',
            userId: userId,
          )
        : LoginScreen();

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => nextScreen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Fond très clair
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔷 Logo ou icône (vous pouvez remplacer par une image)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person, size: 60, color: Colors.blue[700]),
            ),
            SizedBox(height: 24),
            Text(
              'ContactsPro',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Gérez vos contacts en toute sécurité',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
            ),
          ],
        ),
      ),
    );
  }
}
