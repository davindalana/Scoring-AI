import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/services/api_service.dart';
import 'providers/scoring_provider.dart';
import 'ui/core/theme.dart';
import 'ui/features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final apiService = ApiService();
  await apiService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ScoringProvider(apiService: apiService)..init(),
        ),
      ],
      child: const ArcheryScoringApp(),
    ),
  );
}

class ArcheryScoringApp extends StatelessWidget {
  const ArcheryScoringApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Archery Score Pro',
      debugShowCheckedModeBanner: false,
      theme: ArcheryTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
