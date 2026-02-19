import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:khair_app/core/di/injection.dart';
import 'package:khair_app/features/landing/presentation/pages/landing_page.dart';
import 'package:khair_app/features/events/presentation/pages/events_explorer_page.dart';
import 'package:khair_app/features/events/presentation/bloc/events_bloc.dart';
import 'package:khair_app/features/map/presentation/pages/map_page.dart';
import 'package:khair_app/features/auth/presentation/pages/login_page.dart';
import 'package:khair_app/features/auth/presentation/pages/register_page.dart';
import 'package:khair_app/features/organizer/presentation/pages/organizer_application_page.dart';
import 'package:khair_app/features/organizer/presentation/pages/organizer_dashboard_new.dart';
import 'package:khair_app/features/organizer/presentation/bloc/organizer_bloc.dart';
import 'package:khair_app/features/admin/presentation/pages/admin_panel_page.dart';
import 'package:khair_app/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:khair_app/features/static/presentation/pages/static_page.dart';
import 'package:khair_app/features/events/presentation/pages/event_details_page.dart';
import 'package:khair_app/features/events/presentation/pages/create_event_page.dart';
import 'package:khair_app/features/profile/presentation/pages/profile_page.dart';

/// App Navigation Configuration
class AppNavigation {
  AppNavigation._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      // Public routes
      GoRoute(
        path: '/',
        name: 'landing',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/events',
        name: 'events',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<EventsBloc>(),
          child: const EventsExplorerPage(),
        ),
      ),
      GoRoute(
        path: '/events/:id',
        name: 'event-detail',
        builder: (context, state) {
          final eventId = state.pathParameters['id']!;
          return BlocProvider(
            create: (_) => getIt<EventsBloc>(),
            child: EventDetailsPage(eventId: eventId),
          );
        },
      ),
      // Auth routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterPage(),
      ),

      GoRoute(
        path: '/map',
        name: 'map',
        builder: (context, state) => const MapPage(),
      ),

      // Organizer routes
      GoRoute(
        path: '/organizer/apply',
        name: 'organizer-apply',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<OrganizerBloc>(),
          child: const OrganizerApplicationPage(),
        ),
      ),
      GoRoute(
        path: '/organizer/dashboard',
        name: 'organizer-dashboard',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<OrganizerBloc>(),
          child: const OrganizerDashboardPageNew(),
        ),
      ),
      GoRoute(
        path: '/organizer/events/create',
        name: 'create-event',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<EventsBloc>(),
          child: const CreateEventPage(),
        ),
      ),

      // Profile route
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),

      // Admin routes
      GoRoute(
        path: '/admin',
        name: 'admin',
        builder: (context, state) => BlocProvider(
          create: (_) => getIt<AdminBloc>(),
          child: const AdminPanelPage(),
        ),
      ),

      // Static pages
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const StaticPage(pageType: 'about'),
      ),
      GoRoute(
        path: '/verification-policy',
        name: 'verification-policy',
        builder: (context, state) => const StaticPage(pageType: 'verification'),
      ),
      GoRoute(
        path: '/content-policy',
        name: 'content-policy',
        builder: (context, state) => const StaticPage(pageType: 'content'),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const StaticPage(pageType: 'privacy'),
      ),
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const StaticPage(pageType: 'terms'),
      ),
    ],

    // Error page
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Page Not Found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'The page "${state.uri}" does not exist.',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
}

