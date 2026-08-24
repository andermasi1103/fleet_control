import '../../attendance/data/dtos/location_dto.dart';
import '../data/dtos/company_option_dto.dart';

class LocationsState {
  const LocationsState({
    this.isLoading = false,
    this.isSaving = false,
    this.locations = const [],
    this.companies = const [],
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final List<LocationDto> locations;
  final List<CompanyOptionDto> companies;
  final String? errorMessage;
  final String? successMessage;

  LocationsState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<LocationDto>? locations,
    List<CompanyOptionDto>? companies,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return LocationsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      locations: locations ?? this.locations,
      companies: companies ?? this.companies,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}
