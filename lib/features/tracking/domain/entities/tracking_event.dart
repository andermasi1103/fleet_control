class TrackingEvent {
  const TrackingEvent(this.data);

  /// Contrato sin campos tipados hasta recibir la respuesta de /events.
  final Map<String, dynamic> data;
}
