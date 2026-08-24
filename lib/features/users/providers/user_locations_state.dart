import '../data/dtos/user_location_option_dto.dart';

class UserLocationsState {
  const UserLocationsState({
    this.isLoading = false,
    this.isSaving = false,
    this.locations = const [],
    this.selectedLocationIds = const {},
    this.errorMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final List<UserLocationOptionDto> locations;
  final Set<String> selectedLocationIds;
  final String? errorMessage;

  UserLocationsState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<UserLocationOptionDto>? locations,
    Set<String>? selectedLocationIds,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UserLocationsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      locations: locations ?? this.locations,
      selectedLocationIds: selectedLocationIds ?? this.selectedLocationIds,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
