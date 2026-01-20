import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models/word.dart';
import 'models/grammar_topic.dart';
import 'providers/word_provider.dart';
import 'providers/grammar_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(WordAdapter());
  Hive.registerAdapter(GrammarTopicAdapter());
  Hive.registerAdapter(GrammarFormulaAdapter());
  Hive.registerAdapter(GrammarUsageAdapter());
  await Hive.openBox<Word>('words');
  await Hive.openBox<GrammarTopic>('grammar');
  await Hive.openBox('settings');
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    // .env file is optional now
    debugPrint("No .env file found, using Settings.");
  }
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
      home: const HomeScreen(),
    );
  }
}
