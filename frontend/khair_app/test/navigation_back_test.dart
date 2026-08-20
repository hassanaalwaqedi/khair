import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khair_app/core/router/navigation.dart';

void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(body: Text('Discover')),
        ),
        GoRoute(
          path: '/events/:id',
          builder: (_, __) => RouteBackFallback(
            fallbackLocation: '/',
            child: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    const Text('Event details'),
                    FilledButton(
                      onPressed: () => context.push('/organizers/42'),
                      child: const Text('Open organizer'),
                    ),
                    FilledButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const SizedBox(
                          height: 120,
                          child: Center(child: Text('Share sheet')),
                        ),
                      ),
                      child: const Text('Share'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/organizers/:id',
          builder: (_, __) => RouteBackFallback(
            fallbackLocation: '/',
            child: const Scaffold(body: Text('Organizer profile')),
          ),
        ),
      ],
    );
  });

  tearDown(() => router.dispose());

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('nested event and organizer routes pop one screen at a time',
      (tester) async {
    await pumpRouter(tester);

    router.push('/events/1');
    await tester.pumpAndSettle();
    expect(find.text('Event details'), findsOneWidget);

    await tester.tap(find.text('Open organizer'));
    await tester.pumpAndSettle();
    expect(find.text('Organizer profile'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Event details'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsOneWidget);
  });

  testWidgets('a direct event link returns to Discover instead of exiting',
      (tester) async {
    router.go('/events/1');
    await pumpRouter(tester);
    expect(find.text('Event details'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
  });

  testWidgets('system Back closes a modal before leaving the event page',
      (tester) async {
    router.go('/events/1');
    await pumpRouter(tester);

    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    expect(find.text('Share sheet'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Share sheet'), findsNothing);
    expect(find.text('Event details'), findsOneWidget);
  });
}
