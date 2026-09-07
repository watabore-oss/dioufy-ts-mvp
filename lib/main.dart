import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'features/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://yrarlatdoulyfyjpqzlp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InlyYXJsYXRkb3VseWZ5anBxemxwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI0MTg2NjgsImV4cCI6MjA4Nzk5NDY2OH0.OTg9l-nIRyffeUqkTG6DKhPquB7dPPj0_70FwWQXszM',
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
