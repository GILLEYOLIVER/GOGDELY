// Explicit local-only smoke test of the same HTTP client used by all apps.
// Start the opt-in API on 127.0.0.1:8765 before running this script.
import 'dart:io';
import 'package:gogdely_local_demo_api/gogdely_local_demo_api.dart';

Future<void> main() async {
  final api = LocalDemoApi();
  try {
    final created = await api.createOrder(
      requestKey: newDemoRequestKey(),
      storeId: 'pizzaria-napoli',
      addressLabel: 'Av. Paulista, 1000 (teste local)',
      items: [
        {
          'product_id': 'margherita',
          'quantity': 1,
          'size': 'Tradicional',
          'extras': <String>[]
        },
      ],
    );
    if (created.status != 'created' || created.totalCents != 3889) {
      throw StateError('Pedido criado incorretamente: ${created.id}');
    }
    final managementView = await api.orders(storeId: 'pizzaria-napoli');
    if (!managementView.any((order) => order.id == created.id)) {
      throw StateError('Gestão não encontra pedido ${created.id}');
    }
    await api.updateStatus(created.id, 'preparing', 'management');
    await api.updateStatus(created.id, 'ready', 'management');
    final courierView = await api.orders(status: 'ready');
    if (!courierView.any((order) => order.id == created.id)) {
      throw StateError('Entregador não encontra pedido ${created.id}');
    }
    await api.updateStatus(created.id, 'in_delivery', 'courier');
    await api.updateStatus(created.id, 'delivered', 'courier');
    final clientView = await api.order(created.id);
    if (clientView.status != 'delivered') {
      throw StateError('Cliente não vê entrega concluída');
    }
    stdout.writeln(
        'Fluxo local OK: pedido #${created.id}, salvo e entregue, total ${created.totalCents} centavos.');
  } finally {
    api.close();
  }
}
