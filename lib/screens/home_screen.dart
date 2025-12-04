import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/word_provider.dart';
import 'add_word_screen.dart';
import 'learning_screen.dart';
import 'review_screen.dart';
import 'edit_word_screen.dart';
import 'game_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vocabulary'),
        actions: [
          Consumer<WordProvider>(
            builder: (context, provider, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.videogame_asset),
                    tooltip: 'Play Game',
                    onPressed: provider.words.length < 4
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    GameScreen(words: provider.words),
                              ),
                            );
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.school),
                    tooltip: 'Review All',
                    onPressed: provider.words.isEmpty
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReviewScreen(words: provider.words),
                              ),
                            );
                          },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<WordProvider>(
        builder: (context, provider, child) {
          if (provider.words.isEmpty) {
            return const Center(child: Text('No words yet. Add some!'));
          }
          return ListView.builder(
            itemCount: provider.words.length,
            itemBuilder: (context, index) {
              final word = provider.words[index];
              return ListTile(
                title: Text(word.word),
                subtitle: Text(word.meaningVi),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EditWordScreen(word: word, index: index),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        provider.deleteWord(index);
                      },
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => LearningScreen(word: word),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddWordScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
