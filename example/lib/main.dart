import 'package:flutter/material.dart';
import 'dexie_counts.dart' if (dart.library.js_interop) 'dexie_counts_web.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final counts = await loadDexieCounts();

  runApp(
    DexieExampleApp(
      friendsCount: counts.friendsCount,
      adultsCount: counts.adultsCount,
    ),
  );
}

class DexieExampleApp extends StatelessWidget {
  const DexieExampleApp({
    required this.friendsCount,
    required this.adultsCount,
    super.key,
  });

  final int friendsCount;
  final int adultsCount;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('dexie_web example')),
        body: Center(
          child: Text('friends: $friendsCount, adults(18): $adultsCount'),
        ),
      ),
    );
  }
}
