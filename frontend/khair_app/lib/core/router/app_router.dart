import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../widgets/main_scaffold.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/events/presentation/bloc/events_bloc.dart';
import '../../features/events/presentation/pages/events_page.dart';
import '../../features/events/presentation/pages/event_details_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/organizer/presentation/pages/organizer_dashboard_page.dart';
import '../../features/organizer/presentation/pages/create_event_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/reports_page.dart';
import '../../features/admin/presentation/pages/audit_logs_page.dart';
import '../../features/admin/presentation/pages/organizer_trust_page.dart';
import '../../features/organizer/presentation/bloc/organizer_bloc.dart';
import '../../features/static/presentation/pages/static_page.dart';
import '../../features/verification/presentation/pages/verification_page.dart';
import '../../features/home/presentation/pages/discover_page.dart';
import '../../features/owner_posts/presentation/bloc/owner_posts_bloc.dart';
import '../../features/owner_posts/presentation/pages/owner_dashboard_page.dart' as owner;

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Landing page (public marketing page)
    GoRoute(
      path: '/landing',
      builder: (context, state) => const LandingPage(),
    ),
    // Shell route for pages with bottom navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => getIt<EventsBloc>()),
            BlocProvider(
              create: (_) => getIt<AuthBloc>()..add(CheckAuthStatus()),
            ),
            BlocProvider(
              create: (_) => getIt<OwnerPostsBloc>()..add(LoadActivePosts()),
            ),
          ],
          child: MainScaffold(child: child),
        );
      },
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: DiscoverPage(),
          ),
        ),
        GoRoute(
          path: '/events',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: EventsPage(),
          ),
        ),
        GoRoute(
          path: '/map',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MapPage(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfilePage(),
          ),
        ),
      ],
    ),
    // Event details (without bottom nav)
    GoRoute(
      path: '/events/:id',
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
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      path: '/verification',
      builder: (context, state) => const VerificationPage(),
    ),
    // Organizer routes
    GoRoute(
      path: '/organizer',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<OrganizerBloc>(),
        child: const OrganizerDashboardPage(),
      ),
      routes: [
        GoRoute(
          path: 'events/create',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<EventsBloc>(),
            child: const CreateEventPage(),
          ),
        ),
      ],
    ),
    // /organizer/apply redirects to /register (organizer onboarding handled by registration wizard)
    GoRoute(
      path: '/organizer/apply',
      redirect: (context, state) => '/register',
    ),
    // Admin routes
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminDashboardPage(),
      routes: [
        GoRoute(
          path: 'reports',
          builder: (context, state) => const ReportsPage(),
        ),
        GoRoute(
          path: 'audit-logs',
          builder: (context, state) => const AuditLogsPage(),
        ),
        GoRoute(
          path: 'organizers/:id/trust',
          builder: (context, state) {
            final organizerId = state.pathParameters['id']!;
            return OrganizerTrustPage(organizerId: organizerId);
          },
        ),
      ],
    ),
    // Static pages
    GoRoute(
      path: '/about',
      builder: (context, state) => const StaticPage(pageType: 'about'),
    ),
    GoRoute(
      path: '/privacy',
      builder: (context, state) => const StaticPage(pageType: 'privacy'),
    ),
    GoRoute(
      path: '/terms',
      builder: (context, state) => const StaticPage(pageType: 'terms'),
    ),
    GoRoute(
      path: '/content-policy',
      builder: (context, state) => const StaticPage(pageType: 'content'),
    ),
    GoRoute(
      path: '/verification-policy',
      builder: (context, state) =>
          const StaticPage(pageType: 'verification'),
    ),
    // Owner Dashboard (admin-only)
    GoRoute(
      path: '/owner-dashboard',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<OwnerPostsBloc>(),
        child: const owner.OwnerDashboardPage(),
      ),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Page not found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);
