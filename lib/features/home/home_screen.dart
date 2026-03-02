import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../search/search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final depController = TextEditingController(text: 'Dakar');
  final arrController = TextEditingController(text: 'Thies');

  @override
  void dispose() {
    depController.dispose();
    arrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 420,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text(
                        'Dioufy-TS',
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Fo nek sa gare fek lafa',
                        style: TextStyle(
                          fontSize: 18,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              TextField(
                                controller: depController,
                                decoration: const InputDecoration(
                                  labelText: 'Depart',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: arrController,
                                decoration: const InputDecoration(
                                  labelText: 'Destination',
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SearchResultsScreen(),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                                child: const Text(
                                  'RECHERCHER',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  height: 380,
                  color: const Color(0xFF0F172A),
                  child: SvgPicture.asset(
                    'assets/svg/carte_senegal.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
