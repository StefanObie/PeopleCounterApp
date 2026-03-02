import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/people_counter.dart';
import 'providers/collection_provider.dart';
import 'providers/counter_provider.dart';
import 'repositories/collection_repository.dart';
import 'screens/home_shell.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final counter = PeopleCounter();
  try {
    await counter.loadModel();
  } catch (e, st) {
    debugPrint('[main] Failed to load model: $e\n$st');
  }

  runApp(MyApp(peopleCounter: counter));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.peopleCounter});

  final PeopleCounter peopleCounter;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CounterProvider>(
          create: (_) =>
              CounterProvider(peopleCounter, SettingsService())..initialize(),
        ),
        ChangeNotifierProvider<CollectionProvider>(
          create: (_) => CollectionProvider(CollectionRepository()),
        ),
      ],
      child: MaterialApp(
        title: 'People Counter',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
