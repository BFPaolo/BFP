import 'package:flutter/material.dart';

import 'screens/library_screen.dart';
import 'services/library_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = await LibraryRepository.open();
  runApp(BfpEReaderApp(repository: repository));
}

class BfpEReaderApp extends StatelessWidget {
  const BfpEReaderApp({super.key, required this.repository});

  final LibraryRepository repository;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF3F51B5);
    return MaterialApp(
      title: 'BFP-eReader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: LibraryScreen(repository: repository),
    );
  }
}
