import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart' as provider;
import 'package:firebase_core/firebase_core.dart';
import 'providers/theme_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'firebase_options.dart'; // Import this

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with generated options
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: Consumer2<ThemeProvider, AuthProvider>(
        builder: (context, themeProvider, authProvider, child) {
          return Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              // Initialize ChatProvider with userId when auth state changes
              if (authProvider.userId != null) {
                if (chatProvider.currentUserId == null || chatProvider.currentUserId != authProvider.userId) {
                  debugPrint(' Main: Setting ChatProvider user ID from AuthProvider: ${authProvider.userId}');
                  chatProvider.setUserId(authProvider.userId!);
                }
              } else if (authProvider.userId == null && chatProvider.currentUserId != null) {
                debugPrint(' Main: Clearing ChatProvider data - user logged out');
                // Clear chat data when user logs out
                chatProvider.clearMessages();
              }
              
              return MaterialApp(
                title: 'AI Chatbot',
                debugShowCheckedModeBanner: false,
                theme: themeProvider.currentTheme,
                darkTheme: themeProvider.currentDarkTheme,
                themeMode: themeProvider.themeMode,
                home: const SplashScreen(),
                routes: {
                  '/login': (context) => const LoginScreen(),
                  '/home': (context) => const HomeScreen(),
                },
              );
            },
          );
        },
      ),
    );
  }
}