bool canManageUsers(String? roleCode) =>
    roleCode == 'super_admin' || roleCode == 'admin';

bool canManageUserLocations(String? roleCode) =>
    canManageUsers(roleCode) || roleCode == 'supervisor';
