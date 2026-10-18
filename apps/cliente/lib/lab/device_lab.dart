import 'package:flutter/material.dart';

enum LabDevice { iphone, android, tablet }

enum LabNetwork { online, offline }

enum LabOrder { created, accepted, preparing, delivering, completed }

class DeviceLab extends StatefulWidget {
  const DeviceLab({super.key, required this.child});
  final Widget child;

  @override
  State<DeviceLab> createState() => _DeviceLabState();
}

class _DeviceLabState extends State<DeviceLab> {
  LabDevice device = LabDevice.iphone;
  LabNetwork network = LabNetwork.online;
  LabOrder order = LabOrder.created;
  bool landscape = false;
  bool notification = false;

  Size get portraitSize => switch (device) {
        LabDevice.iphone => const Size(390, 844),
        LabDevice.android => const Size(412, 915),
        LabDevice.tablet => const Size(800, 1100),
      };

  @override
  Widget build(BuildContext context) {
    final base = portraitSize;
    final size = landscape ? Size(base.height, base.width) : base;
    return Scaffold(
      backgroundColor: const Color(0xff101522),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final wide = availableWidth >= 1050;
          final controls = _controls();
          final preview = _preview(size, constraints.biggest, wide);
          return wide
              ? Row(children: [
                  SizedBox(width: 290, child: controls),
                  Expanded(child: preview),
                ])
              : Column(children: [
                  SizedBox(height: 205, child: controls),
                  Expanded(child: preview),
                ]);
        }),
      ),
    );
  }

  Widget _controls() => Container(
        color: const Color(0xff151B2B),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('GOGDELY • Laboratório',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Somente dados fictícios',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            DropdownButtonFormField<LabDevice>(
              key: ValueKey(device),
              initialValue: device,
              decoration: const InputDecoration(
                  labelText: 'Dispositivo', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: LabDevice.iphone, child: Text('iPhone')),
                DropdownMenuItem(
                    value: LabDevice.android, child: Text('Android')),
                DropdownMenuItem(
                    value: LabDevice.tablet, child: Text('Tablet')),
              ],
              onChanged: (value) => setState(() => device = value ?? device),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => landscape = !landscape),
                icon: const Icon(Icons.screen_rotation),
                label: const Text('Girar'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => network =
                    network == LabNetwork.online
                        ? LabNetwork.offline
                        : LabNetwork.online),
                icon: Icon(
                    network == LabNetwork.online ? Icons.wifi : Icons.wifi_off),
                label:
                    Text(network == LabNetwork.online ? 'Online' : 'Offline'),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(() => notification = !notification),
                icon: const Icon(Icons.notifications),
                label: const Text('Notificação'),
              ),
            ]),
            const Divider(),
            const Text('Cenário de pedido',
                style: TextStyle(fontWeight: FontWeight.w600)),
            DropdownButtonFormField<LabOrder>(
              key: ValueKey(order),
              initialValue: order,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                    value: LabOrder.created, child: Text('Recebido')),
                DropdownMenuItem(
                    value: LabOrder.accepted, child: Text('Confirmado')),
                DropdownMenuItem(
                    value: LabOrder.preparing, child: Text('Em preparo')),
                DropdownMenuItem(
                    value: LabOrder.delivering, child: Text('Em entrega')),
                DropdownMenuItem(
                    value: LabOrder.completed, child: Text('Concluído')),
              ],
              onChanged: (value) => setState(() => order = value ?? order),
            ),
            const SizedBox(height: 8),
            const Text('A simulação não altera rede, GPS ou pedidos reais.',
                style: TextStyle(fontSize: 12)),
          ],
        ),
      );

  Widget _preview(Size deviceSize, Size viewport, bool wide) {
    final maxWidth =
        (viewport.width - (wide ? 340 : 30)).clamp(100.0, double.infinity);
    final maxHeight =
        (viewport.height - (wide ? 40 : 220)).clamp(100.0, double.infinity);
    final scale = [
      1.0,
      maxWidth / (deviceSize.width + 32),
      maxHeight / (deviceSize.height + 32)
    ].reduce((a, b) => a < b ? a : b);
    final frameWidth = (deviceSize.width + 28) * scale;
    final frameHeight = (deviceSize.height + 28) * scale;
    return Center(
      child: SizedBox(
        width: frameWidth,
        height: frameHeight,
        child: FittedBox(
          fit: BoxFit.fill,
          child: Container(
            width: deviceSize.width + 28,
            height: deviceSize.height + 28,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xff202428),
              borderRadius: BorderRadius.circular(40),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 20)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(27),
              child: SizedBox(
                width: deviceSize.width,
                height: deviceSize.height,
                child: MediaQuery(
                  data: MediaQueryData(size: deviceSize, devicePixelRatio: 2),
                  child: Stack(children: [
                    Positioned.fill(child: widget.child),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Column(children: [
                          if (network == LabNetwork.offline)
                            Container(
                              width: double.infinity,
                              color: Colors.orange.shade100,
                              padding: const EdgeInsets.all(8),
                              child: const Text('SIMULAÇÃO: sem conexão',
                                  textAlign: TextAlign.center),
                            ),
                          if (notification)
                            Container(
                              color: const Color(0xffDBEAFE),
                              padding: const EdgeInsets.all(12),
                              child: const Text(
                                  'Notificação fictícia: pedido atualizado'),
                            ),
                          Container(
                            color: Colors.black87,
                            width: double.infinity,
                            padding: const EdgeInsets.all(6),
                            child: Text('Pedido de teste: ${order.name}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
