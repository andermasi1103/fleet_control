import '../../companies/data/dtos/company_dto.dart';
import '../data/dtos/vehicle_dto.dart';

class VehiclesState {
  const VehiclesState({
    this.isLoading = false,
    this.isSaving = false,
    this.vehicles = const [],
    this.companies = const [],
    this.searchQuery = '',
    this.errorMessage,
  });
  final bool isLoading, isSaving;
  final List<VehicleDto> vehicles;
  final List<CompanyDto> companies;
  final String searchQuery;
  final String? errorMessage;
  List<VehicleDto> get filteredVehicles {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return vehicles;
    return vehicles
        .where(
          (vehicle) =>
              vehicle.plate.toLowerCase().contains(query) ||
              (vehicle.brand?.toLowerCase().contains(query) ?? false) ||
              (vehicle.model?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);
  }

  VehiclesState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<VehicleDto>? vehicles,
    List<CompanyDto>? companies,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) => VehiclesState(
    isLoading: isLoading ?? this.isLoading,
    isSaving: isSaving ?? this.isSaving,
    vehicles: vehicles ?? this.vehicles,
    companies: companies ?? this.companies,
    searchQuery: searchQuery ?? this.searchQuery,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
  );
}
