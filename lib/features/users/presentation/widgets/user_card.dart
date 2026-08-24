import 'package:flutter/material.dart';

import '../../../../shared/utils/role_label.dart';
import '../../data/dtos/user_dto.dart';

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    required this.onEdit,
    required this.onResetPassword,
    required this.onAssignLocations,
  });

  final UserDto user;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onAssignLocations;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  user.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Chip(
                label: Text(user.isActive ? 'Activo' : 'Inactivo'),
                backgroundColor: (user.isActive ? Colors.green : Colors.grey)
                    .withValues(alpha: 0.15),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Usuario: ${user.usuario}'),
          Text('Empresa: ${user.companyName ?? 'Sin empresa asignada'}'),
          Text('Rol: ${roleLabel(user.role ?? '')}'),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('EDITAR'),
              ),
              TextButton.icon(
                onPressed: onResetPassword,
                icon: const Icon(Icons.lock_reset_outlined),
                label: const Text('RESTABLECER CONTRASEÑA'),
              ),
              TextButton.icon(
                onPressed: onAssignLocations,
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('ASIGNAR LOCALES'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
