import 'package:flutter/material.dart';
import 'qr_demo_screen.dart';
import 'map_demo_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('GOGDELY • Laboratório')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Prévia de componentes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Dados fictícios. Nenhum pedido, pagamento ou serviço de produção está conectado.'),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code_scanner),
                title: const Text('Leitor QR Code'),
                subtitle: const Text('Ler código de mesa em modo de demonstração'),
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                  builder: (_) => const QrDemoScreen(),
                )),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Mapa'),
                subtitle: const Text('Prévia do componente Flutter Map sem GPS real'),
                onTap: () => Navigator.push(context, MaterialPageRoute<void>(
                  builder: (_) => const MapDemoScreen(),
                )),
              ),
            ),
          ],
        ),
      );
}
