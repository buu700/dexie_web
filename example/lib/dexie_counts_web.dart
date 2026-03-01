// ignore_for_file: implementation_imports

import 'package:dexie_web/src/dexie_web_impl.dart';

Future<({int adultsCount, int friendsCount})> loadDexieCounts() async {
  await ensureDexieInitialized();

  final db = DexieDatabase('myAppDb');
  await db.open({
    'friends': '++id, name, age',
    'todos': '++id, title, completed',
  });

  await db.put('friends', {'name': 'Alice', 'age': 30});

  final friends = await db.getAll<Map>('friends');
  final adults = await db.whereEquals<Map>('friends', 'age', 18);
  return (adultsCount: adults.length, friendsCount: friends.length);
}
