import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/authentication/providers/session_provider.dart';
import '../features/authentication/widgets/login_card.dart';
import '../features/attendance/presentation/attendance_history_screen.dart';
import '../features/attendance/presentation/attendance_screen.dart';
import '../features/attendance/data/dtos/location_dto.dart';
import '../features/companies/data/dtos/company_dto.dart';
import '../features/companies/presentation/company_form_screen.dart';
import '../features/companies/presentation/companies_screen.dart';
import '../features/dashboard/user_dashboard.dart';
import '../features/driver_orders/presentation/driver_orders_screen.dart';
import '../features/fleet_tracking/presentation/fleet_map_screen.dart';
import '../features/locations/presentation/location_form_screen.dart';
import '../features/locations/presentation/locations_screen.dart';
import '../features/locations/presentation/locations_import_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/profile/presentation/change_password_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/role_views/app_view_code.dart';
import '../features/role_views/presentation/role_views_screen.dart';
import '../features/role_views/providers/current_user_views_provider.dart';
import '../features/reports/presentation/reports_screen.dart';
import '../features/users/data/dtos/user_dto.dart';
import '../features/users/presentation/user_form_screen.dart';
import '../features/users/presentation/user_locations_screen.dart';
import '../features/users/presentation/users_screen.dart';
import '../features/vehicles/presentation/vehicles_screen.dart';
import '../features/vehicles/data/dtos/vehicle_dto.dart';
import '../features/vehicles/presentation/vehicle_form_screen.dart';
import '../features/orders/data/dtos/order_dto.dart';
import '../features/orders/presentation/order_form_screen.dart';
import '../features/orders/presentation/order_descriptions_screen.dart';
import '../features/orders/presentation/orders_screen.dart';
import '../features/managements/presentation/managements_screen.dart';
import '../features/managements/presentation/assign_management_screen.dart';
import '../shared/widgets/app_loading.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);
  final currentUserViews = ref.watch(currentUserViewsProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) {
          return const Scaffold(body: AppLoading());
        },
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) {
          return const Scaffold(
            body: SafeArea(child: Center(child: LoginCard())),
          );
        },
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) {
          return const UserDashboard();
        },
      ),
      GoRoute(
        path: '/fleet-map',
        builder: (context, state) => const FleetMapScreen(),
      ),
      GoRoute(
        path: '/attendance',
        builder: (context, state) => const AttendanceScreen(),
      ),
      GoRoute(
        path: '/attendance/history',
        builder: (context, state) => const AttendanceHistoryScreen(),
      ),
      GoRoute(
        path: '/vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: '/vehicles/new',
        builder: (context, state) => const VehicleFormScreen(),
      ),
      GoRoute(
        path: '/vehicles/:id/edit',
        builder: (context, state) =>
            VehicleFormScreen(initialVehicle: state.extra! as VehicleDto),
      ),
      GoRoute(path: '/users', builder: (context, state) => const UsersScreen()),
      GoRoute(
        path: '/users/new',
        builder: (context, state) => const UserFormScreen(),
      ),
      GoRoute(
        path: '/users/:id/edit',
        builder: (context, state) => UserFormScreen(
          initialUser: state.extra is UserDto ? state.extra! as UserDto : null,
        ),
      ),
      GoRoute(
        path: '/users/:id/locations',
        builder: (context, state) =>
            UserLocationsScreen(user: state.extra! as UserDto),
      ),
      GoRoute(
        path: '/companies',
        builder: (context, state) => const CompaniesScreen(),
      ),
      GoRoute(
        path: '/companies/new',
        builder: (context, state) => const CompanyFormScreen(),
      ),
      GoRoute(
        path: '/companies/:id/edit',
        builder: (context, state) => CompanyFormScreen(
          initialCompany: state.extra is CompanyDto
              ? state.extra! as CompanyDto
              : null,
        ),
      ),
      GoRoute(
        path: '/locations',
        builder: (context, state) => const LocationsScreen(),
      ),
      GoRoute(
        path: '/locations/new',
        builder: (context, state) => const LocationFormScreen(),
      ),
      GoRoute(
        path: '/locations/import',
        builder: (context, state) => const LocationsImportScreen(),
      ),
      GoRoute(
        path: '/locations/:id/edit',
        builder: (context, state) => LocationFormScreen(
          initialLocation: state.extra is LocationDto
              ? state.extra! as LocationDto
              : null,
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/role-views',
        builder: (context, state) => const RoleViewsScreen(),
      ),
      GoRoute(path: '/reports', builder: (context, state) => const ReportsScreen()),
      GoRoute(
        path: '/orders',
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        path: '/driver-orders',
        builder: (context, state) => const DriverOrdersScreen(),
      ),
      GoRoute(
        path: '/managements',
        builder: (context, state) => const ManagementsScreen(),
      ),
      GoRoute(
        path: '/managements/:id',
        builder: (context, state) {
          final managementId = state.pathParameters['id'];
          if (managementId == null || managementId.isEmpty) {
            return _invalidRouteScreen('gestión');
          }
          return ManagementDetailScreen(managementId: managementId);
        },
      ),
      GoRoute(
        path: '/orders/:id/assign-management',
        builder: (context, state) {
          final order = state.extra;
          if (order is! OrderDto) return _invalidRouteScreen('pedido');
          return AssignManagementScreen(order: order);
        },
      ),
      GoRoute(
        path: '/orders/new',
        builder: (context, state) => const OrderFormScreen(),
      ),
      GoRoute(
        path: '/orders/descriptions',
        builder: (context, state) =>
            OrderDescriptionsScreen(initialCompanyId: state.extra as String?),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (context, state) {
          final orderId = state.pathParameters['id'];
          if (orderId == null || orderId.isEmpty) {
            return _invalidRouteScreen('pedido');
          }
          return OrderDetailScreen(orderId: orderId);
        },
      ),
    ],
    redirect: (context, state) {
      final path = state.uri.path;
      final isSplash = path == '/splash';
      final isLogin = path == '/login';

      if (session.isInitializing) {
        return isSplash ? null : '/splash';
      }

      if (!session.isAuthenticated) {
        return isLogin ? null : '/login';
      }

      if (currentUserViews.isLoading) {
        return isSplash ? null : '/splash';
      }

      if (isSplash || isLogin) {
        return '/home';
      }

      if (!currentUserViews.isReady) {
        return path == '/home' ? null : '/home';
      }

      final requiredView = requiredViewForPath(path);
      if (requiredView != null && !currentUserViews.canView(requiredView)) {
        return '/home';
      }

      return null;
    },
  );
});

AppViewCode? requiredViewForPath(String path) {
  if (path == '/home') return AppViewCode.home;
  if (path.startsWith('/attendance')) return AppViewCode.attendance;
  if (path.startsWith('/companies')) return AppViewCode.companies;
  if (path.startsWith('/locations')) return AppViewCode.locations;
  if (path.startsWith('/users')) return AppViewCode.users;
  if (path.startsWith('/vehicles')) return AppViewCode.vehicles;
  if (path.startsWith('/driver-orders')) return AppViewCode.driverOrders;
  if (path.startsWith('/managements')) return AppViewCode.managements;
  if (path == '/fleet-map') return AppViewCode.fleetMap;
  if (path == '/settings/role-views') {
    return AppViewCode.roleViewsManagement;
  }
  if (path.startsWith('/settings') || path.startsWith('/profile')) {
    return AppViewCode.settings;
  }
  if (path.startsWith('/orders')) return AppViewCode.orders;
  if (path.startsWith('/reports')) return AppViewCode.reports;
  return null;
}

Widget _invalidRouteScreen(String resource) => Scaffold(
  appBar: AppBar(title: const Text('Ruta no disponible')),
  body: Center(child: Text('No se pudo abrir el $resource solicitado.')),
);
