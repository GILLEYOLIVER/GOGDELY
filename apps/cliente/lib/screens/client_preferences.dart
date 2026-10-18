import 'dart:convert';

import 'client_preferences_stub.dart'
    if (dart.library.js_interop) 'client_preferences_web.dart' as platform;

/// Only manual address fields and favorite store IDs are saved on this device.
/// Map coordinates and device location are deliberately excluded.
class ClientPreferences {
  const ClientPreferences({
    this.street = 'Rua das Flores',
    this.number = '123',
    this.complement = '',
    this.reference = '',
    this.kind = 'Casa',
    this.favoriteStoreIds = const {},
  });

  final String street;
  final String number;
  final String complement;
  final String reference;
  final String kind;
  final Set<String> favoriteStoreIds;

  String get addressLabel => [
        '$street, $number',
        if (complement.isNotEmpty) complement,
        if (reference.isNotEmpty) 'Referência: $reference',
      ].join(' · ');

  String encode() => jsonEncode({
        'street': street,
        'number': number,
        'complement': complement,
        'reference': reference,
        'kind': kind,
        'favoriteStoreIds': favoriteStoreIds.toList()..sort(),
      });

  static ClientPreferences decode(String? value) {
    if (value == null) return const ClientPreferences();
    try {
      final data = jsonDecode(value);
      if (data is! Map<String, dynamic>) return const ClientPreferences();
      String field(String name, int maxLength, String fallback) {
        final raw = data[name];
        if (raw is! String) return fallback;
        final text = raw.trim();
        return text.length <= maxLength ? text : fallback;
      }

      final street = field('street', 80, 'Rua das Flores');
      final number = field('number', 20, '123');
      final complement = field('complement', 60, '');
      final reference = field('reference', 100, '');
      final kind = field('kind', 20, 'Casa');
      final favorites = data['favoriteStoreIds'];
      return ClientPreferences(
        street: street.length >= 3 ? street : 'Rua das Flores',
        number: number.isNotEmpty ? number : '123',
        complement: complement,
        reference: reference,
        kind: {'Casa', 'Trabalho'}.contains(kind) ? kind : 'Casa',
        favoriteStoreIds: favorites is List
            ? favorites
                .whereType<String>()
                .where((id) => id.isNotEmpty && id.length <= 80)
                .take(100)
                .toSet()
            : const {},
      );
    } catch (_) {
      return const ClientPreferences();
    }
  }
}

abstract interface class ClientPreferencesStore {
  String? read();
  bool write(String value);
}

class DeviceClientPreferencesStore implements ClientPreferencesStore {
  const DeviceClientPreferencesStore();

  @override
  String? read() => platform.readClientPreferences();

  @override
  bool write(String value) => platform.writeClientPreferences(value);
}
