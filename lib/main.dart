import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'firebase_options.dart';

import 'providers/word_provider.dart';
import 'providers/grammar_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (Required for Firebase)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Error loading .env file: $e");
  }

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive for Settings
  await Hive.initFlutter();
  await Hive.openBox('settings');

  // Initialize TTS Service (loads saved settings)
  await TtsService.instance.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WordProvider()),
        ChangeNotifierProvider(create: (_) => GrammarProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English Vocabulary',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper that checks auth state and shows appropriate screen
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _notificationsInitialized = false;
  
  @override
  void initState() {
    super.initState();
  }

  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;
    _notificationsInitialized = true;
    
    try {
      final notificationService = NotificationService();
      
      // Initialize first
      await notificationService.initialize();
      debugPrint('NotificationService: Initialized');
      
      // Small delay to ensure plugin is ready (important for release builds)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Request permissions
      final granted = await notificationService.requestPermissions();
      debugPrint('NotificationService: Permissions granted = $granted');
      
      if (granted) {
        await notificationService.scheduleNext7Days();
        final pending = await notificationService.getPendingNotifications();
        debugPrint('NotificationService: ${pending.length} notifications scheduled');
      } else {
        debugPrint('NotificationService: Permissions not granted');
      }
    } catch (e) {
      debugPrint('NotificationService: Error initializing - $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is logged in
        if (snapshot.hasData && snapshot.data != null) {
          // Initialize notifications after frame is rendered
          if (!_notificationsInitialized) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeNotifications();
            });
          }
          return const HomeScreen();
        }

        // User is not logged in - reset notification flag
        _notificationsInitialized = false;
        return const LoginScreen();
      },
    );
  }
}
