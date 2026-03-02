import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://TON-PROJET.supabase.co',
    anonKey: 'TON_ANON_KEY',
  );

  runApp(const DioufyApp());
}

class DioufyApp extends StatelessWidget {
  const DioufyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dioufy-TS',
      theme: DioufyTheme.light,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
