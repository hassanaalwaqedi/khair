import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import '../widgets/main_scaffold.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/events/presentation/bloc/events_bloc.dart';
import '../../features/events/presentation/pages/event_details_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/organizer/presentation/pages/organizer_dashboard_page.dart';
import '../../features/organizer/presentation/pages/organizer_events_page.dart';
import '../../features/organizer/presentation/pages/organizer_profile_edit_page.dart';
import '../../features/organizer/presentation/pages/organizer_analytics_page.dart';
import '../../features/organizer/presentation/pages/create_event_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/admin/presentation/bloc/admin_bloc.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/reports_page.dart';
import '../../features/admin/presentation/pages/audit_logs_page.dart';
import '../../features/admin/presentation/pages/organizer_trust_page.dart';
import '../../features/organizer/presentation/bloc/organizer_bloc.dart';
import '../../features/static/presentation/pages/static_page.dart';
import '../../features/verification/presentation/pages/verification_page.dart';
import '../../features/home/presentation/pages/discover_page.dart';
import '../../features/notifications/presentation/pages/notification_center_page.dart';

import '../../features/owner_posts/presentation/bloc/owner_posts_bloc.dart';
import '../../features/owner_posts/presentation/pages/owner_dashboard_page.dart' as owner;
import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../../features/location/presentation/bloc/location_bloc.dart';
import '../../features/sheikh/presentation/bloc/sheikh_bloc.dart';
import '../../features/chat/presentation/bloc/chat_bloc.dart';
import '../../features/chat/presentation/pages/conversations_page.dart';
import '../../features/chat/presentation/pages/chat_page.dart';
import '../../features/sheikh_dashboard/presentation/bloc/sheikh_dashboard_bloc.dart';
import '../../features/sheikh_dashboard/presentation/pages/sheikh_dashboard_page.dart';

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
            BlocProvider(
              create: (_) => getIt<NotificationBloc>()..add(const LoadUnreadCount()),
            ),
            BlocProvider(
              create: (_) => getIt<LocationBloc>(),
            ),
            BlocProvider(
              create: (_) => getIt<SheikhBloc>()..add(const LoadSheikhs()),
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
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => getIt<EventsBloc>()),
            BlocProvider(
              create: (_) => getIt<AuthBloc>()..add(CheckAuthStatus()),
            ),
          ],
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
        GoRoute(
          path: 'events',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<OrganizerBloc>(),
            child: const OrganizerEventsPage(),
          ),
        ),
        GoRoute(
          path: 'profile',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<OrganizerBloc>()..add(const LoadOrganizerProfile()),
            child: const OrganizerProfileEditPage(),
          ),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => BlocProvider(
            create: (_) => getIt<OrganizerBloc>()..add(const LoadOrganizerEvents()),
            child: const OrganizerAnalyticsPage(),
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
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<AdminBloc>()..add(const LoadAdminData()),
        child: const AdminDashboardPage(),
      ),
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
    // Notification Center
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterPage(),
    ),
    // Profile Edit
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const ProfileEditPage(),
    ),
    // Conversations list
    GoRoute(
      path: '/conversations',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<ChatBloc>(),
        child: const ConversationsPage(),
      ),
    ),
    // Chat page
    GoRoute(
      path: '/conversations/:id',
      builder: (context, state) {
        final convId = state.pathParameters['id']!;
        return BlocProvider(
          create: (_) => getIt<ChatBloc>(),
          child: ChatPage(conversationId: convId),
        );
      },
    ),
    // Sheikh Dashboard
    GoRoute(
      path: '/sheikh-dashboard',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<SheikhDashboardBloc>(),
        child: const SheikhDashboardPage(),
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
