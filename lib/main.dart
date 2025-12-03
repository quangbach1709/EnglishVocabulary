import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/word.dart';

import 'package:provider/provider.dart';
import 'providers/word_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(WordAdapter());
  await Hive.openBox<Word>('words');
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => WordProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English Learning',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
