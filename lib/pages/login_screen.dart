// screens/login_screen.dart
import 'package:contact_list/db/auth_service.dart';
import 'package:contact_list/db/db.dart';

import 'package:contact_list/models/user.dart'; // ← Ajouté
import 'package:contact_list/pages/SignupScreen.dart';
import 'package:contact_list/pages/home_page.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.blue[800],
        title: Text('Connexion'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔷 Titre
                Text(
                  'Bienvenue !',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Connectez-vous à votre compte',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                SizedBox(height: 32),

                // 🔷 Champ username
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Nom d’utilisateur',
                    prefixIcon: Icon(Icons.person, color: Colors.blue[700]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez entrer un nom d’utilisateur';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),

                // 🔷 Champ mot de passe
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock, color: Colors.blue[700]),
                    suffixIcon: Icon(Icons.visibility_off, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer un mot de passe';
                    }
                    if (value.length < 4) {
                      return 'Le mot de passe doit avoir au moins 4 caractères';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8),

                // 🔷 "Se souvenir de moi"
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (bool? value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      activeColor: Colors.blue[700],
                    ),
                    Text('Se souvenir de moi'),
                  ],
                ),
                SizedBox(height: 8),

                // 🔷 Message d'erreur
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 24),
                // Dans le Column de LoginScreen, avant le bouton "Se connecter"
                SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => SignupScreen()),
                    );
                  },
                  child: Text(
                    'Pas encore de compte ? S’inscrire',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                ),
                SizedBox(height: 24),

                // 🔷 Bouton de connexion
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () async {
                            if (_formKey.currentState!.validate()) {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });

                              final username = _usernameController.text.trim();
                              final password = _passwordController.text;

                              // 1. Vérifier les identifiants
                              final success = await AuthService().login(
                                username,
                                password,
                                rememberMe: _rememberMe,
                              );

                              if (!mounted) return;

                              if (success) {
                                // 2. Récupérer l'utilisateur complet (avec id)
                                final dbHelper = DbHelper();
                                final User? user = await dbHelper
                                    .getUserByUsername(username);

                                if (user?.id != null) {
                                  // 3. Naviguer vers HomePage avec username + userId
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => HomePage(
                                        username: username,
                                        userId: user!.id!,
                                      ),
                                    ),
                                  );
                                } else {
                                  // Cas très improbable, mais sécurisé
                                  setState(() {
                                    _errorMessage =
                                        'Erreur interne : utilisateur introuvable';
                                  });
                                }
                              } else {
                                setState(() {
                                  _errorMessage =
                                      'Identifiant ou mot de passe incorrect';
                                });
                              }

                              if (mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          )
                        : Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
