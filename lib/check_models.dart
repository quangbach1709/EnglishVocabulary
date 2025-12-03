import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  final apiKey = dotenv.env['API_KEY']!;
  final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

  try {
    // There isn't a direct listModels method on GenerativeModel,
    // but we can try to use the model and see if it works or if we can use a different way.
    // Actually, the Dart SDK doesn't expose listModels easily in the high-level API
    // without using the REST API directly or a specific method if available.
    // Let's just try to generate content with 'gemini-pro' to see if that works.

    print('Trying gemini-pro...');
    final modelPro = GenerativeModel(model: 'gemini-pro', apiKey: apiKey);
    final response = await modelPro.generateContent([Content.text('Hello')]);
    print('gemini-pro works: ${response.text}');

    print('Trying gemini-1.5-flash...');
    final modelFlash = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
    );
    final responseFlash = await modelFlash.generateContent([
      Content.text('Hello'),
    ]);
    print('gemini-1.5-flash works: ${responseFlash.text}');
  } catch (e) {
    print('Error: $e');
  }
}
