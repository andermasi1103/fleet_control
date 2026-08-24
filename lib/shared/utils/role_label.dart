String roleLabel(String role) {
  switch (role) {
    case 'super_admin':
      return 'Super administrador';
    case 'admin':
      return 'Administrador';
    case 'supervisor':
      return 'Supervisor';
    case 'chofer':
      return 'Chofer';
    case 'user':
      return 'Usuario';
    case 'local':
      return 'Local';
    default:
      return role.isEmpty ? 'Sin rol asignado' : role;
  }
}
