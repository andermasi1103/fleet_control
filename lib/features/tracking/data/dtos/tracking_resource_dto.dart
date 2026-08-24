class TrackingResourceDto {
  const TrackingResourceDto(this.data);

  final Map<String, dynamic> data;

  factory TrackingResourceDto.fromJson(Map<String, dynamic> json) {
    return TrackingResourceDto(Map<String, dynamic>.unmodifiable(json));
  }
}
