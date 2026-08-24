import 'package:flutter/material.dart';

import '../../data/dtos/company_dto.dart';

class CompanyCard extends StatelessWidget {
  const CompanyCard({super.key, required this.company, required this.onEdit});

  final CompanyDto company;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.business_outlined),
      title: Text(company.nombre),
      subtitle: Text(company.isActive ? 'Activa' : 'Inactiva'),
      trailing: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        children: [
          Chip(
            label: Text(company.isActive ? 'Activa' : 'Inactiva'),
            backgroundColor: (company.isActive ? Colors.green : Colors.grey)
                .withValues(alpha: 0.15),
          ),
          IconButton(
            tooltip: 'Editar',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    ),
  );
}
