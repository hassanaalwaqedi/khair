import 'package:khair_app/core/locale/l10n_extension.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/injection.dart';
import 'navigation.dart';
import '../widgets/main_scaffold.dart';
import '../../features/admin/presentation/bloc/admin_bloc.dart';
import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/admin/presentation/pages/audit_logs_page.dart';
import '../../features/admin/presentation/pages/organizer_application_list_page.dart';
import '../../features/admin/presentation/pages/organizer_application_review_page.dart';
import '../../features/admin/presentation/pages/organizer_trust_page.dart';
import '../../features/admin/presentation/pages/reports_page.dart';
import '../../features/admin/presentation/pages/admin_event_review_page.dart';
import '../../features/admin/presentation/pages/admin_support_inbox_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/email_verification_page.dart';
import '../../features/events/presentation/bloc/events_bloc.dart';
import '../../features/events/presentation/pages/event_details_page.dart';
import '../../features/events/domain/entities/event.dart';
import '../../features/events/presentation/pages/my_events_page.dart';
import '../../features/events/presentation/pages/saved_events_page.dart';
import '../../features/home/presentation/pages/discover_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/location/presentation/bloc/location_bloc.dart';
import '../../features/map/presentation/pages/map_page.dart';
import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../../features/notifications/presentation/pages/notification_center_page.dart';
import '../../features/organizer/presentation/bloc/organizer_bloc.dart';
import '../../features/organizer/presentation/pages/create_event_page.dart';
import '../../features/organizer/presentation/pages/organizer_access_page.dart';
import '../../features/organizer/presentation/pages/organizer_analytics_page.dart';
import '../../features/organizer/presentation/pages/organizer_hub_page.dart';
import '../../features/organizer/presentation/pages/organizer_events_page.dart';
import '../../features/organizer/presentation/pages/organizer_event_status_page.dart';
import '../../features/organizer/presentation/pages/organizer_profile_edit_page.dart';
import '../../features/organizer/presentation/pages/organizer_public_profile_page.dart';
import '../../features/owner_posts/presentation/bloc/owner_posts_bloc.dart';
import '../../features/owner_posts/presentation/pages/owner_dashboard_page.dart'
    as owner;
import '../../features/profile/presentation/pages/profile_edit_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/static/presentation/pages/static_page.dart';
import '../../features/support/presentation/bloc/support_cubit.dart';
import '../../features/support/presentation/pages/support_chat_page.dart';
import '../../features/verification/presentation/pages/verification_page.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();
final AuthBloc _authBloc = getIt<AuthBloc>();

/// Bridges AuthBloc changes to GoRouter. The router, not individual screens,
/// owns all access decisions including manual URL entry and deep links.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<AuthState> _subscription;
  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  debugLogDiagnostics: kDebugMode,
  refreshListenable: _AuthRefresh(_authBloc.stream),
  redirect: _guardRoute,
  routes: [
    GoRoute(path: '/auth-loading', builder: (_, __) => _AuthLoadingPage()),
    GoRoute(
      path: '/landing',
      builder: (_, __) =>
          RouteBackFallback(fallbackLocation: '/', child: LandingPage()),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => getIt<EventsBloc>()),
          BlocProvider(
              create: (_) => getIt<OwnerPostsBloc>()..add(LoadActivePosts())),
          BlocProvider.value(value: getIt<NotificationBloc>()),
          BlocProvider(
              create: (_) =>
                  getIt<LocationBloc>()..add(LoadCachedLocationEvent())),
        ],
        child: MainScaffold(child: child),
      ),
      routes: [
        GoRoute(
            path: '/',
            pageBuilder: (_, __) => NoTransitionPage(child: DiscoverPage())),
        GoRoute(
            path: '/map',
            pageBuilder: (_, __) => NoTransitionPage(child: MapPage())),
        GoRoute(
            path: '/profile',
            pageBuilder: (_, __) => NoTransitionPage(child: ProfilePage())),
        GoRoute(
            path: '/my-events',
            pageBuilder: (_, __) => NoTransitionPage(child: MyEventsPage())),
        GoRoute(
            path: '/saved',
            pageBuilder: (_, __) => NoTransitionPage(child: SavedEventsPage())),
      ],
    ),
    GoRoute(
      path: '/events/:id',
      builder: (context, state) => RouteBackFallback(
        fallbackLocation: '/',
        child: BlocProvider(
          create: (_) => getIt<EventsBloc>(),
          child: EventDetailsPage(eventId: state.pathParameters['id']!),
        ),
      ),
    ),
    GoRoute(
      path: '/organizers/:id',
      builder: (_, state) => RouteBackFallback(
        fallbackLocation: '/',
        child: OrganizerPublicProfilePage(
          organizerId: state.pathParameters['id']!,
        ),
      ),
    ),
    GoRoute(
      path: '/login',
      builder: (_, __) =>
          RouteBackFallback(fallbackLocation: '/', child: LoginPage()),
    ),
    GoRoute(
      path: '/register',
      builder: (_, __) =>
          RouteBackFallback(fallbackLocation: '/', child: RegisterPage()),
    ),
    GoRoute(
      path: '/register/verify',
      builder: (_, __) => RouteBackFallback(
        fallbackLocation: '/register',
        child: EmailVerificationPage(),
      ),
    ),
    GoRoute(
      path: '/verification',
      builder: (_, __) =>
          RouteBackFallback(fallbackLocation: '/', child: VerificationPage()),
    ),
    GoRoute(
      path: '/organizer/apply',
      builder: (_, __) => OrganizerAccessPage(),
    ),
    GoRoute(
      path: '/create-event',
      redirect: (_, __) => '/organizer/events/create',
    ),
    GoRoute(
      path: '/organizer',
      builder: (_, __) =>
          RouteBackFallback(fallbackLocation: '/', child: OrganizerHubPage()),
      routes: [
        GoRoute(
            path: 'events/create',
            builder: (_, __) => BlocProvider(
                create: (_) => getIt<EventsBloc>(), child: CreateEventPage())),
        GoRoute(
          path: 'events/:id/edit',
          redirect: (_, state) => state.extra is Event
              ? null
              : '/organizer/events/${state.pathParameters['id']}',
          builder: (_, state) => BlocProvider(
            create: (_) => getIt<EventsBloc>(),
            child: CreateEventPage(initialEvent: state.extra as Event),
          ),
        ),
        GoRoute(
            path: 'events',
            builder: (_, __) => RouteBackFallback(
                  fallbackLocation: '/organizer',
                  child: BlocProvider(
                    create: (_) => getIt<OrganizerBloc>(),
                    child: OrganizerEventsPage(),
                  ),
                )),
        GoRoute(
            path: 'events/:id',
            builder: (_, state) => RouteBackFallback(
                  fallbackLocation: '/organizer/events',
                  child: BlocProvider(
                    create: (_) =>
                        getIt<OrganizerBloc>()..add(LoadOrganizerEvents()),
                    child: OrganizerEventStatusPage(
                        eventId: state.pathParameters['id']!),
                  ),
                )),
        GoRoute(
            path: 'profile',
            builder: (_, __) => BlocProvider(
                create: (_) =>
                    getIt<OrganizerBloc>()..add(LoadOrganizerProfile()),
                child: OrganizerProfileEditPage())),
        GoRoute(
            path: 'analytics',
            builder: (_, __) => RouteBackFallback(
                  fallbackLocation: '/organizer',
                  child: BlocProvider(
                    create: (_) =>
                        getIt<OrganizerBloc>()..add(LoadOrganizerEvents()),
                    child: OrganizerAnalyticsPage(),
                  ),
                )),
      ],
    ),
    GoRoute(
      path: '/admin',
      builder: (_, __) => RouteBackFallback(
        fallbackLocation: '/',
        child: BlocProvider(
          create: (_) => getIt<AdminBloc>()..add(LoadAdminData()),
          child: AdminDashboardPage(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'events/:id',
          builder: (context, state) {
            final event = state.extra as Event?;
            if (event == null) {
              return Scaffold(
                  body: Center(child: Text(context.l10n.eventNotFound)));
            }
            return BlocProvider.value(
              value: getIt<AdminBloc>(),
              child: AdminEventReviewPage(event: event),
            );
          },
        ),
        GoRoute(
          path: 'organizer-applications',
          builder: (_, __) => OrganizerApplicationListPage(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (_, state) => OrganizerApplicationReviewPage(
                applicationId: state.pathParameters['id']!,
              ),
            ),
          ],
        ),
        GoRoute(
          path: 'reports',
          builder: (_, __) => RouteBackFallback(
            fallbackLocation: '/admin',
            child: ReportsPage(),
          ),
        ),
        GoRoute(
          path: 'audit-logs',
          builder: (_, __) => RouteBackFallback(
            fallbackLocation: '/admin',
            child: AuditLogsPage(),
          ),
        ),
        GoRoute(
            path: 'organizers/:id/trust',
            builder: (_, state) =>
                OrganizerTrustPage(organizerId: state.pathParameters['id']!)),
        GoRoute(
          path: 'support',
          builder: (_, __) => RouteBackFallback(
            fallbackLocation: '/admin',
            child: AdminSupportInboxPage(),
          ),
        ),
      ],
    ),
    GoRoute(
        path: '/owner-dashboard',
        builder: (_, __) => RouteBackFallback(
              fallbackLocation: '/',
              child: BlocProvider(
                create: (_) => getIt<OwnerPostsBloc>(),
                child: const owner.OwnerDashboardPage(),
              ),
            )),
    GoRoute(
      path: '/notifications',
      builder: (_, __) => RouteBackFallback(
        fallbackLocation: '/',
        child: NotificationCenterPage(),
      ),
    ),
    GoRoute(path: '/profile/edit', builder: (_, __) => ProfileEditPage()),
    GoRoute(
      path: '/about',
      builder: (_, __) => RouteBackFallback(
          fallbackLocation: '/', child: StaticPage(pageType: 'about')),
    ),
    GoRoute(
      path: '/privacy',
      builder: (_, __) => RouteBackFallback(
        fallbackLocation: '/',
        child: StaticPage(pageType: 'privacy'),
      ),
    ),
    GoRoute(
      path: '/terms',
      builder: (_, __) => RouteBackFallback(
          fallbackLocation: '/', child: StaticPage(pageType: 'terms')),
    ),
    GoRoute(
        path: '/content-policy',
        builder: (_, __) => RouteBackFallback(
              fallbackLocation: '/',
              child: StaticPage(pageType: 'content'),
            )),
    GoRoute(
        path: '/verification-policy',
        builder: (_, __) => RouteBackFallback(
              fallbackLocation: '/',
              child: StaticPage(pageType: 'verification'),
            )),
    GoRoute(
        path: '/support',
        builder: (_, state) => RouteBackFallback(
              fallbackLocation: '/',
              child: BlocProvider(
                create: (_) => getIt<SupportCubit>(),
                child: SupportChatPage(
                  initialTicketId: state.uri.queryParameters['conversation'],
                  contextType: state.uri.queryParameters['context_type'],
                  contextId: state.uri.queryParameters['context_id'],
                ),
              ),
            )),
  ],
  errorBuilder: (context, state) =>
      _NotFoundPage(message: state.error?.toString()),
);

String? _guardRoute(BuildContext context, GoRouterState routerState) {
  final path = routerState.uri.path;
  final state = _authBloc.state;
  final isLoadingPage = path == '/auth-loading';
  if (state.status == AuthStatus.initial) {
    return isLoadingPage
        ? null
        : '/auth-loading?next=${Uri.encodeComponent(_internalLocation(routerState))}';
  }
  if (isLoadingPage) {
    return _safeNext(routerState.uri.queryParameters['next']) ?? '/';
  }

  final publicPath = path == '/' ||
      path == '/landing' ||
      path == '/map' ||
      path.startsWith('/events/') ||
      path.startsWith('/organizers/') ||
      path == '/login' ||
      path == '/register' ||
      path.startsWith('/register/') ||
      path == '/verification' ||
      path == '/about' ||
      path == '/privacy' ||
      path == '/terms' ||
      path == '/content-policy' ||
      path == '/verification-policy';
  final authPath = path == '/login' || path == '/register';
  if (!state.isAuthenticated) {
    if (publicPath) return null;
    return '/login?next=${Uri.encodeComponent(_internalLocation(routerState))}';
  }

  if (authPath) {
    final next = routerState.uri.queryParameters['next'];
    return _safeNext(next) ?? '/';
  }
  if (path == '/admin' ||
      path.startsWith('/admin/') ||
      path == '/owner-dashboard') {
    return state.isAdmin ? null : '/';
  }
  if (path.startsWith('/organizer/') && path != '/organizer/apply') {
    return state.isAuthenticated
        ? null
        : '/login?next=${Uri.encodeComponent(_internalLocation(routerState))}';
  }
  if (path == '/organizer') {
    return state.isAuthenticated
        ? null
        : '/login?next=${Uri.encodeComponent(_internalLocation(routerState))}';
  }
  return null;
}

/// Converts a platform URL (for example `khair:///events/123`) into the
/// internal path GoRouter uses after auth hydration. Never carry an external
/// host into `next`, otherwise deep links silently fall back to Discover.
String _internalLocation(GoRouterState state) {
  final uri = state.uri;
  final path = uri.path.isEmpty ? '/' : uri.path;
  return uri.hasQuery ? '$path?${uri.query}' : path;
}

String? _safeNext(String? next) =>
    next != null && next.startsWith('/') && !next.startsWith('//')
        ? next
        : null;

class _AuthLoadingPage extends StatelessWidget {
  const _AuthLoadingPage();
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _NotFoundPage extends StatelessWidget {
  final String? message;
  const _NotFoundPage({this.message});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
            child: FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: Icon(Icons.explore_outlined),
                label: Text(context.l10n.discoverEvents))),
      );
}
