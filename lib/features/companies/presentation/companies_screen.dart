import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dashboard/app_shell.dart';
import '../data/dtos/company_dto.dart';
import '../providers/companies_provider.dart';
import 'widgets/company_card.dart';

class CompaniesScreen extends ConsumerStatefulWidget {
  const CompaniesScreen({super.key});

  @override
  ConsumerState<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends ConsumerState<CompaniesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companiesProvider.notifier).loadCompanies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(companiesProvider);

    return AppShell(
      title: 'Empresas',
      showHomeAction: true,
      child: RefreshIndicator(
        onRefresh: () => ref.read(companiesProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Empresas',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Administra las empresas registradas en MasiTrack.',
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: state.isLoading ? null : _createCompany,
                  icon: const Icon(Icons.add),
                  label: const Text('NUEVA EMPRESA'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (state.errorMessage != null) ...[
              _ErrorMessage(message: state.errorMessage!),
              const SizedBox(height: 16),
            ],
            if (state.isLoading && state.companies.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.companies.isEmpty && state.errorMessage == null)
              const _EmptyCompanies()
            else if (state.companies.isNotEmpty)
              ...state.companies.map(
                (company) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CompanyCard(
                    company: company,
                    onEdit: () => _editCompany(company),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _createCompany() async {
    final saved = await context.push<bool>('/companies/new');
    if (saved == true && mounted) {
      await _reloadAndNotify('Empresa creada correctamente.');
    }
  }

  Future<void> _editCompany(CompanyDto company) async {
    final saved = await context.push<bool>(
      '/companies/${company.id}/edit',
      extra: company,
    );
    if (saved == true && mounted) {
      await _reloadAndNotify('Empresa actualizada correctamente.');
    }
  }

  Future<void> _reloadAndNotify(String message) async {
    await ref.read(companiesProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EmptyCompanies extends StatelessWidget {
  const _EmptyCompanies();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 48),
    child: Center(
      child: Text('No hay empresas registradas.', textAlign: TextAlign.center),
    ),
  );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );
}
