import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

class TableQrPage extends StatelessWidget {
  const TableQrPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!localDemoEnabled) {
      return const Center(
          child: Text(
              'Abra com o perfil F5 de banco local para usar as mesas QR.'));
    }
    return ListView(padding: const EdgeInsets.all(20), children: [
      const Text('Mesas QR · Burger House',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text(
          'Cada mesa tem seu link. Abra a ficha no navegador para imprimir o QR. '
          'Nesta prévia, use o navegador do próprio computador; acesso por celular na rede ainda será preparado.'),
      const SizedBox(height: 14),
      for (var number = 1; number <= 10; number++)
        Builder(builder: (context) {
          final code = 'M${number.toString().padLeft(2, '0')}';
          final menu = '$localDemoBaseUrl/api/v1/local/mesa/burger-house/$code';
          final print =
              '$localDemoBaseUrl/api/v1/local/tables/burger-house/$code/print';
          return Card(
              child: Padding(
            padding: const EdgeInsets.all(10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Mesa $code',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              SelectableText(menu,
                  style: Theme.of(context).textTheme.bodySmall),
              Wrap(spacing: 8, children: [
                TextButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Copiar cardápio'),
                  onPressed: () => _copy(context, menu),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Copiar ficha QR'),
                  onPressed: () => _copy(context, print),
                ),
              ]),
            ]),
          ));
        }),
    ]);
  }

  Future<void> _copy(BuildContext context, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Link copiado. Cole no navegador deste computador.')));
    }
  }
}
