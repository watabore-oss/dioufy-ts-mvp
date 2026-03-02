import 'package:flutter/material.dart';

class SearchResultsScreen extends StatelessWidget {
  const SearchResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultats')),
      body: const Center(
        child: Text('Liste des trajets a brancher (Supabase).'),
      ),
    );
  }
}
