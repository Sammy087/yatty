import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/dashboard/availability_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/dashboard/form_editor_screen.dart';
import 'screens/public/booking_screen.dart';
import 'services/services.dart';

/// Re-runs go_router redirects whenever auth state changes.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: _AuthRefresh(auth.authState),
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final loc = state.matchedLocation;
      final isPublic = loc.startsWith('/book/') ||
          loc == '/login' ||
          loc == '/signup';

      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn && (loc == '/login' || loc == '/signup')) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (c, s) => const SignupScreen()),
      GoRoute(path: '/dashboard', builder: (c, s) => const DashboardScreen()),
      GoRoute(
        path: '/form/new',
        builder: (c, s) => const FormEditorScreen(formId: null),
      ),
      GoRoute(
        path: '/form/:id',
        builder: (c, s) => FormEditorScreen(formId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/availability',
        builder: (c, s) => const AvailabilityScreen(),
      ),
      GoRoute(
        path: '/book/:formId',
        builder: (c, s) => BookingScreen(formId: s.pathParameters['formId']!),
      ),
    ],
  );
}
