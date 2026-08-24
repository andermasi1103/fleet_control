import '../data/dtos/company_dto.dart';

class CompaniesState {
  const CompaniesState({
    this.isLoading = false,
    this.isSaving = false,
    this.companies = const [],
    this.errorMessage,
    this.successMessage,
  });

  final bool isLoading;
  final bool isSaving;
  final List<CompanyDto> companies;
  final String? errorMessage;
  final String? successMessage;

  CompaniesState copyWith({
    bool? isLoading,
    bool? isSaving,
    List<CompanyDto>? companies,
    String? errorMessage,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return CompaniesState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      companies: companies ?? this.companies,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      successMessage: clearSuccess
          ? null
          : successMessage ?? this.successMessage,
    );
  }
}
