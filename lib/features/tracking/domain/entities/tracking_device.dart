class TrackingDevice {
  const TrackingDevice(this.data);

  /// Contrato sin campos tipados hasta recibir la respuesta de /devices.
  final Map<String, dynamic> data;
}
