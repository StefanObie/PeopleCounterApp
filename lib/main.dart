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

  ThemeData _buildTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F6FB3),
      brightness: Brightness.light,
    );
    const chromeColor = Color(0xFF9FC2E8);
    const chromeForeground = Color(0xFF0E2A47);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: chromeColor,
        foregroundColor: chromeForeground,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: chromeColor,
        indicatorColor: colorScheme.primaryContainer.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.primary
              : chromeForeground.withValues(alpha: 0.82);
          return TextStyle(color: color, fontWeight: FontWeight.w600);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final color = states.contains(WidgetState.selected)
              ? colorScheme.primary
              : chromeForeground.withValues(alpha: 0.82);
          return IconThemeData(color: color);
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: colorScheme.inverseSurface,
        valueIndicatorTextStyle: TextStyle(
          color: colorScheme.onInverseSurface,
        ),
      ),
      dividerColor: colorScheme.outlineVariant,
    );
  }

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
        theme: _buildTheme(),
        home: const HomeShell(),
      ),
    );
  }
}
