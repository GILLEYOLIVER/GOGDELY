import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrDemoScreen extends StatefulWidget {
  const QrDemoScreen({super.key});

  @override
  State<QrDemoScreen> createState() => _QrDemoScreenState();
}

class _QrDemoScreenState extends State<QrDemoScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  String? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Leitor QR • Demonstração')),
        body: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                  'A câmera requer permissão. Códigos são mostrados localmente; nenhum pedido será criado.'),
            ),
            Expanded(
              child: MobileScanner(
                controller: _controller,
                onDetect: (capture) {
                  if (capture.barcodes.isEmpty) return;
                  final value = capture.barcodes.first.rawValue;
                  if (value == null || value.isEmpty || !mounted) return;
                  setState(() => _result = value);
                  _controller.stop();
                },
                errorBuilder: (context, error) => Center(
                  child: Text('Câmera indisponível: ${error.errorCode.name}'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SelectableText(_result == null
                      ? 'Aguardando leitura'
                      : 'Lido (não validado): $_result'),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () {
                      setState(() => _result = null);
                      _controller.start();
                    },
                    child: const Text('Ler novamente'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
