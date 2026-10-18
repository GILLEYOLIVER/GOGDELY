class DeviceLocation {
  const DeviceLocation(this.latitude, this.longitude, {this.accuracyMeters});

  final double latitude;
  final double longitude;
  final double? accuracyMeters;
}
