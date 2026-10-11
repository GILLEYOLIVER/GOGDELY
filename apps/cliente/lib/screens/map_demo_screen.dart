import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapDemoScreen extends StatelessWidget {
  const MapDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sample = LatLng(-16.6869, -49.2648); // Coordenada fictícia para demonstração.
    return Scaffold(
      appBar: AppBar(title: const Text('Mapa • Demonstração')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Marcador de teste. Sem rastreamento, GPS, geocodificação ou mapas de produção.'),
          ),
          Expanded(
            child: FlutterMap(
              options: const MapOptions(initialCenter: sample, initialZoom: 12),
              children: [
                MarkerLayer(markers: [
                  Marker(
                    point: sample,
                    width: 52,
                    height: 52,
                    child: const Icon(Icons.location_on, color: Colors.red, size: 42),
                  ),
                ]),
                const RichAttributionWidget(attributions: [
                  TextSourceAttribution('Dados demonstrativos — sem provedor de tiles configurado'),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
