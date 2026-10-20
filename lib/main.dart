import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/persistence.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final persistence = await Persistence.create();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(persistence),
      child: const TapCookApp(),
    ),
  );
}

class TapCookApp extends StatelessWidget {
  const TapCookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return MaterialApp(
          title: 'TapCook',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.of(state.settings.theme),
          home: state.onboarded ? const HomeShell() : const OnboardingScreen(),
        );
      },
    );
  }
}
