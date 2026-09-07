import 'package:flutter/material.dart';

import '../chauffeur/chauffeur_screen.dart';
import '../search/search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedDestination = "Thiès"; // défaut

  final List<String> destinations = ["Thiès", "Touba"];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // En-tête adaptatif Hero
            Container(
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
                      // Logo et bouton accès Chef de bord
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Image.asset(
                            'assets/logo.jpeg',
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ChauffeurScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.qr_code_scanner,
                                color: Color(0xFFFBBF24)),
                            label: const Text(
                              "Chef de bord",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Dioufy-TS",
                          style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      const Text("Fo nek sa gare fek lafa",
                          style: TextStyle(
                              fontSize: 18, color: Color(0xFFFBBF24))),
                      const SizedBox(height: 20),

                      // Formulaire amélioré
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              const TextField(
                                decoration: InputDecoration(
                                    labelText: "Départ",
                                    hintText: "Dakar (Baux Maraîchers)"),
                                readOnly: true,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                // `value` was deprecated in Flutter 3.33.0-1.0.pre;
                                // use `initialValue` to set the field's starting value.
                                initialValue: selectedDestination,
                                items: destinations
                                    .map((city) => DropdownMenuItem(
                                        value: city, child: Text(city)))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => selectedDestination = val!),
                                decoration: const InputDecoration(
                                    labelText: "Destination"),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SearchResultsScreen(
                                          destination: selectedDestination),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text("RECHERCHER",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 18)),
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

            // Carte SVG (inchangée)

            // pied de page avec logo
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Image.asset('assets/logo.jpeg', height: 40),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  height: 380,
                  color: const Color(0xFF0F172A),
                  child: const Center(
                      child: Text("Carte Sénégal Live\n(Dakar → Touba ajouté)",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 18))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
