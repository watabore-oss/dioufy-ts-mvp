import 'package:flutter/material.dart';
import '../../services/ticket_service.dart';

class ChauffeurScreen extends StatefulWidget {
  const ChauffeurScreen({super.key});

  @override
  State<ChauffeurScreen> createState() => _ChauffeurScreenState();
}

class _ChauffeurScreenState extends State<ChauffeurScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // bouton retour explicite
              Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chef de Bord',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'ID: BY-882-SN',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(child: _stat('Passagers', '32/45', Colors.white)),
                    const VerticalDivider(color: Colors.white24),
                    Expanded(
                      child:
                          _stat('Vitesse', '82 km/h', const Color(0xFF059669)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner, size: 40),
                label: const Text(
                  'SCANNER BILLET',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  backgroundColor: const Color(0xFF2563EB),
                  minimumSize: const Size(double.infinity, 80),
                ),
                onPressed: _showQRScanner,
              ),
              const Spacer(),
              const Text(
                'Transmission Live Dioufy-TS',
                style: TextStyle(
                  color: Color(0xFF059669),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, color: Colors.white70)),
        Text(
          value,
          style: TextStyle(
              fontSize: 42, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  void _showQRScanner() {
    final ticketController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Validation billet'),
        content: TextField(
          controller: ticketController,
          decoration: const InputDecoration(
            labelText: 'Code billet (ou JSON)',
            hintText: 'Copiez/collez le contenu du QR',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = ticketController.text.trim();
              if (code.isEmpty) return;
              Navigator.pop(context);
              try {
                final decoded = TicketService.decodeTicket(code);
                final payload = decoded['payload'] as Map<String, dynamic>;
                final sig = decoded['signature'] as String;
                final valid = TicketService.verify(payload, sig);
                final msg = valid ? 'Billet valide' : 'Signature invalide';
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$msg')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Format invalide: $e')));
              }
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }
}
