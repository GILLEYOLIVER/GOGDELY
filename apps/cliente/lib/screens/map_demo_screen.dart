import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gogdely_design_system/gogdely_design_system.dart';
import 'package:latlong2/latlong.dart';

import 'demo_catalog.dart';
import 'local_location.dart';

/// Interactive map for the local PWA. Store coordinates are fictional; a
/// device position is requested only when the customer taps the location button.
class MapDemoScreen extends StatefulWidget {
  const MapDemoScreen({
    super.key,
    this.stores = const [],
    this.initialLocation,
    this.pickLocation = false,
    this.onStoreSelected,
    this.locationProvider = requestDeviceLocation,
  });

  final List<DemoStore> stores;
  final DeviceLocation? initialLocation;
  final bool pickLocation;
  final ValueChanged<DemoStore>? onStoreSelected;
  final Future<DeviceLocation> Function() locationProvider;

  @override
  State<MapDemoScreen> createState() => _MapDemoScreenState();
}

class _MapDemoScreenState extends State<MapDemoScreen> {
  final MapController _mapController = MapController();
  DeviceLocation? _deviceLocation;
  LatLng? _selectedPoint;
  DemoStore? _selectedStore;
  String? _locationError;
  bool _locating = false;

  static const _goiania = LatLng(-16.6869, -49.2648);

  List<DemoStore> get _mappedStores => widget.stores
      .where((store) => store.latitude != null && store.longitude != null)
      .toList();

  @override
  void initState() {
    super.initState();
    final point = widget.initialLocation;
    if (point != null) _selectedPoint = LatLng(point.latitude, point.longitude);
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final position = await widget.locationProvider();
      if (!mounted) return;
      final point = LatLng(position.latitude, position.longitude);
      setState(() {
        _deviceLocation = position;
        if (widget.pickLocation) _selectedPoint = point;
      });
      _mapController.move(point, 16);
    } catch (error) {
      if (mounted) {
        setState(() => _locationError = error
            .toString()
            .replaceFirst(RegExp(r'^(Bad state|Unsupported operation): '), ''));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _centerStores() {
    final first = _mappedStores.firstOrNull;
    if (first != null) {
      _mapController.move(LatLng(first.latitude!, first.longitude!), 13);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialLocation;
    final first = _mappedStores.firstOrNull;
    final center = initial != null
        ? LatLng(initial.latitude, initial.longitude)
        : first != null
            ? LatLng(first.latitude!, first.longitude!)
            : _goiania;
    return Scaffold(
      appBar: AppBar(
          title:
              Text(widget.pickLocation ? 'Escolher ponto' : 'Mapa de lojas')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _locating ? null : _useMyLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: Text(_locating ? 'Localizando...' : 'Minha localização'),
              ),
            ),
            if (_mappedStores.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Mostrar lojas de teste',
                onPressed: _centerStores,
                icon: const Icon(Icons.storefront_outlined),
              ),
            ],
          ]),
        ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_locationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        Expanded(
          child: Stack(children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13,
                minZoom: 3,
                maxZoom: 18,
                onTap: widget.pickLocation
                    ? (_, point) => setState(() => _selectedPoint = point)
                    : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.gogdely.cliente.local',
                ),
                MarkerLayer(markers: [
                  for (final store in _mappedStores)
                    Marker(
                      point: LatLng(store.latitude!, store.longitude!),
                      width: 44,
                      height: 44,
                      child: Tooltip(
                        message: store.name,
                        child: IconButton.filled(
                          onPressed: () => setState(() {
                            _selectedStore = store;
                            _mapController.move(
                                LatLng(store.latitude!, store.longitude!), 15);
                          }),
                          icon: const Icon(Icons.storefront, size: 21),
                        ),
                      ),
                    ),
                  if (_deviceLocation != null)
                    Marker(
                      point: LatLng(_deviceLocation!.latitude,
                          _deviceLocation!.longitude),
                      width: 34,
                      height: 34,
                      child: const Tooltip(
                        message: 'Sua localização aproximada',
                        child: Icon(Icons.my_location,
                            color: GogdelyColors.blue, size: 32),
                      ),
                    ),
                  if (_selectedPoint != null)
                    Marker(
                      point: _selectedPoint!,
                      width: 46,
                      height: 46,
                      child: const Icon(Icons.location_pin,
                          color: GogdelyColors.blue, size: 44),
                    ),
                ]),
              ],
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(5)),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text('© OpenStreetMap contributors',
                      style: TextStyle(fontSize: 10)),
                ),
              ),
            ),
          ]),
        ),
        if (_selectedStore != null && !widget.pickLocation)
          ListTile(
            leading: const Icon(Icons.storefront, color: GogdelyColors.blue),
            title: Text(_selectedStore!.name),
            subtitle:
                Text('${_selectedStore!.category} · ${_selectedStore!.eta}'),
            trailing: widget.onStoreSelected == null
                ? null
                : TextButton(
                    onPressed: () => widget.onStoreSelected!(_selectedStore!),
                    child: const Text('Ver loja')),
          ),
        if (widget.pickLocation)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(children: [
              Text(_selectedPoint == null
                  ? 'Toque no mapa ou use sua localização para marcar o ponto.'
                  : 'Ponto: ${_selectedPoint!.latitude.toStringAsFixed(5)}, '
                      '${_selectedPoint!.longitude.toStringAsFixed(5)}'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selectedPoint == null
                      ? null
                      : () => Navigator.pop(
                            context,
                            DeviceLocation(_selectedPoint!.latitude,
                                _selectedPoint!.longitude,
                                accuracyMeters:
                                    _deviceLocation?.accuracyMeters),
                          ),
                  child: const Text('Usar este ponto'),
                ),
              ),
            ]),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Text(
            'Lojas e endereços deste laboratório são fictícios. Sua posição é '
            'usada apenas nesta sessão; a região vista é carregada do OpenStreetMap.',
            style: TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ]),
    );
  }
}
