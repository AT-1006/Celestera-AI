import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nicknameController = TextEditingController();
  bool _isLogin = true;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    try {
      if (_isLogin) {
        success = await authProvider.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        success = await authProvider.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
          _nicknameController.text.trim(),
        );
      }

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // Show specific error messages
        String errorMessage = _isLogin 
            ? 'Login failed. Please check your credentials.'
            : 'Sign up failed. Please try again.';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      // Handle specific Firebase errors
      String errorMessage = 'An error occurred. Please try again.';
      if (e.toString().contains('email-already-in-use')) {
        errorMessage = 'This email is already registered. Please sign in instead.';
      } else if (e.toString().contains('user-not-found')) {
        errorMessage = 'No account found with this email. Please sign up.';
      } else if (e.toString().contains('wrong-password')) {
        errorMessage = 'Incorrect password. Please try again.';
      } else if (e.toString().contains('weak-password')) {
        errorMessage = 'Password is too weak. Please choose a stronger password.';
      } else if (e.toString().contains('invalid-email')) {
        errorMessage = 'Please enter a valid email address.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your internet connection.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      debugPrint('Google Sign-In button pressed');
      final success = await authProvider.signInWithGoogle();

      if (!mounted) return;

      if (success) {
        debugPrint('Google Sign-In successful, navigating to home');
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        debugPrint('Google Sign-In failed - returned false');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in was cancelled.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Google Sign-In error in login screen: $e');
      if (!mounted) return;

      String errorMessage = 'Google sign-in failed.';

      // Check for specific Firebase error codes in the error message
      final errorString = e.toString();
      if (errorString.contains('account-exists-with-different-credential')) {
        errorMessage = 'This email is already registered with a different method.';
      } else if (errorString.contains('invalid-credential')) {
        errorMessage = 'Authentication failed. Please check your app configuration.';
      } else if (errorString.contains('operation-not-allowed')) {
        errorMessage = 'Google Sign-In is not enabled. Please contact support.';
      } else if (errorString.contains('user-disabled')) {
        errorMessage = 'This account has been disabled.';
      } else if (errorString.contains('12501')) {
        errorMessage = 'Google Play Services error. Please try again.';
      } else if (errorString.contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      } else if (e is Exception && e.toString().contains('message')) {
        errorMessage = 'Error: $errorString';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 80,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Create Account',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Email field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Nickname field (only for sign up)
                  if (!_isLogin)
                    TextFormField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(
                        labelText: 'Nickname',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a nickname';
                        }
                        return null;
                      },
                    ),
                  if (!_isLogin) const SizedBox(height: 24),

                  if (_isLogin) const SizedBox(height: 24),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _handleSubmit,
                      child: authProvider.isLoading
                          ? const CircularProgressIndicator()
                          : Text(
                              _isLogin ? 'Login' : 'Sign Up',
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Theme.of(context).dividerColor)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Sign In
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: authProvider.isLoading ? null : _handleGoogleSignIn,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggle between login and sign up
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
                    child: Text(
                      _isLogin
                          ? "Don't have an account? Sign Up"
                          : 'Already have an account? Login',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}