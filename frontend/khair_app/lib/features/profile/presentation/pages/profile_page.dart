import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/di/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/profile_overview_datasource.dart';

const _rose = Color(0xFFF43F75);
const _roseSoft = Color(0xFFFFF1F5);
const _warm = Color(0xFFFCFAFB);
const _ink = Color(0xFF171126);
const _muted = Color(0xFF726B7B);
const _border = Color(0xFFEAE5E8);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<ProfileOverview> _overview;

  @override
  void initState() {
    super.initState();
    _overview = getIt<ProfileOverviewDataSource>().load();
  }

  void _reload() {
    final newFuture = getIt<ProfileOverviewDataSource>().load();
    setState(() {
      _overview = newFuture;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) {
        if (state.status == AuthStatus.unauthenticated) context.go('/');
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF101014)
            : _warm,
        body: SafeArea(
          child: FutureBuilder<ProfileOverview>(
            future: _overview,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _ProfileSkeleton();
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return _ProfileError(onRetry: _reload);
              }
              final overview = snapshot.data!;
              final authBloc = context.read<AuthBloc>();
              if (overview.organizer.status == 'approved' &&
                  authBloc.state.organizer?.status != 'approved') {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    authBloc.add(CheckAuthStatus());
                  }
                });
              }
              return _ProfileContent(
                overview: overview,
                onRefresh: () async => _reload(),
                onUpdated: _reload,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent(
      {required this.overview,
      required this.onRefresh,
      required this.onUpdated});
  final ProfileOverview overview;
  final Future<void> Function() onRefresh;
  final VoidCallback onUpdated;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return RefreshIndicator(
      color: _rose,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      wide ? 32 : 20, 18, wide ? 32 : 20, 100),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TopBar(onEdit: () => _openEdit(context, onUpdated)),
                        const SizedBox(height: 22),
                        _ProfileHero(
                            overview: overview,
                            onEdit: () => _openEdit(context, onUpdated)),
                        const SizedBox(height: 28),
                        _SectionTitle('Quick actions'),
                        const SizedBox(height: 12),
                        _QuickActions(overview: overview, onUpdated: onUpdated),
                        const SizedBox(height: 30),
                        if (wide)
                          Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: _DetailsColumn(
                                        overview: overview,
                                        onUpdated: onUpdated)),
                                const SizedBox(width: 20),
                                Expanded(
                                    child: _UpcomingEvents(
                                        events: overview.upcomingEvents)),
                              ])
                        else ...[
                          _UpcomingEvents(events: overview.upcomingEvents),
                          const SizedBox(height: 20),
                          _DetailsColumn(
                              overview: overview, onUpdated: onUpdated),
                        ],
                        const SizedBox(height: 20),
                        _AccountSafety(),
                      ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, VoidCallback onUpdated) async {
    final changed = await context.push<bool>('/profile/edit');
    if (changed == true) {
      onUpdated();
      if (context.mounted) context.read<AuthBloc>().add(CheckAuthStatus());
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onEdit});
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text('Profile',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: _text(context))),
        const Spacer(),
        IconButton(
            onPressed: onEdit,
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined, color: _rose)),
      ]);
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.overview, required this.onEdit});
  final ProfileOverview overview;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final user = overview.user;
    final compact = MediaQuery.sizeOf(context).width < 620;
    final intro = Wrap(
        spacing: 18,
        runSpacing: 16,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _Avatar(user: user, size: compact ? 76 : 92, onEdit: onEdit),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(user.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700, color: _text(context))),
                const SizedBox(height: 5),
                Text(user.email, style: TextStyle(color: _muted, fontSize: 14)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _Badge(label: user.accountType),
                  Text(
                      'Member since ${DateFormat('MMM y').format(user.createdAt)}',
                      style: TextStyle(color: _muted, fontSize: 13)),
                ]),
              ]),
        ]);
    final stats = _Stats(overview: overview, onEdit: onEdit);
    return _Surface(
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF21171E)
          : _roseSoft,
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 22), stats])
          : Row(children: [
              Expanded(child: intro),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: stats)
            ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, required this.size, required this.onEdit});
  final ProfileUser user;
  final double size;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(size),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_rose, Color(0xFFFF8AAF)])),
              child: ClipOval(
                  child: user.avatarUrl?.isNotEmpty == true
                      ? Image.network(ApiConfig.resolveUrl(user.avatarUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _Initials(user: user, size: size))
                      : _Initials(user: user, size: size))),
          PositionedDirectional(
              end: -2,
              bottom: -2,
              child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: _rose,
                      shape: BoxShape.circle,
                      border: Border.all(color: _surface(context), width: 3)),
                  child: const Icon(Icons.camera_alt_outlined,
                      size: 15, color: Colors.white))),
        ]),
      );
}

class _Initials extends StatelessWidget {
  const _Initials({required this.user, required this.size});
  final ProfileUser user;
  final double size;
  @override
  Widget build(BuildContext context) => Center(
      child: Text(user.initials,
          style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * .34)));
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: _rose.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: const TextStyle(
              color: _rose, fontWeight: FontWeight.w700, fontSize: 12)));
}

class _Stats extends StatelessWidget {
  const _Stats({required this.overview, required this.onEdit});
  final ProfileOverview overview;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final items = [
      (overview.stats.savedEvents.toString(), 'Saved events'),
      (overview.stats.joinedEvents.toString(), 'Joined events'),
      (overview.user.accountType, 'Account type')
    ];
    return Row(children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) Container(width: 1, height: 42, color: _border),
        Expanded(child: _Metric(value: items[i].$1, label: items[i].$2)),
      ],
      InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(99),
          child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: _Completion(value: overview.stats.completion))),
    ]);
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: _text(context),
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 11))
      ]);
}

class _Completion extends StatelessWidget {
  const _Completion({required this.value});
  final int value;
  @override
  Widget build(BuildContext context) =>
      Stack(alignment: Alignment.center, children: [
        SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
                value: value / 100,
                color: _rose,
                backgroundColor: _rose.withValues(alpha: .14),
                strokeWidth: 5)),
        Text('$value%',
            style: TextStyle(
                color: _text(context),
                fontSize: 12,
                fontWeight: FontWeight.w800))
      ]);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.overview, required this.onUpdated});
  final ProfileOverview overview;
  final VoidCallback onUpdated;
  @override
  Widget build(BuildContext context) {
    final organizer = overview.organizer;
    final organizerAction = switch (organizer.status) {
      'approved' => _Action(Icons.dashboard_outlined, 'Organizer dashboard',
          'Manage your events', '/organizer'),
      'pending' => _Action(
          Icons.hourglass_top_rounded,
          'Application under review',
          'We will let you know',
          '/organizer/apply'),
      'needs_revision' => _Action(
          Icons.edit_note_outlined,
          'Update application',
          'A few details need attention',
          '/organizer/apply'),
      'rejected' => _Action(
          Icons.refresh_rounded,
          'Resubmit application',
          organizer.rejectionReason ?? 'Review feedback and apply again',
          '/organizer/apply'),
      'suspended' => _Action(
          Icons.block_flipped,
          'Account suspended',
          'Contact Khair support',
          '/organizer/apply'),
      'draft' => _Action(
          Icons.edit_document,
          'Continue application',
          'Finish your organizer profile',
          '/organizer/apply'),
      _ => const _Action(
          Icons.volunteer_activism_outlined,
          'Become an organizer',
          'Create events for your community',
          '/organizer/apply'),
    };
    final actions = [
      const _Action(Icons.edit_outlined, 'Edit profile', 'Personal details',
          '/profile/edit'),
      _Action(Icons.bookmark_border_rounded, 'Saved events',
          '${overview.stats.savedEvents} saved', '/saved'),
      _Action(Icons.event_available_outlined, 'My events',
          '${overview.stats.joinedEvents} joined', '/my-events'),
      const _Action(Icons.explore_outlined, 'Browse events',
          'Find something meaningful', '/'),
      organizerAction,
      if (overview.user.email == 'hassan@khair.com' || context.read<AuthBloc>().state.isAdmin)
        const _Action(Icons.admin_panel_settings_outlined, 'Admin Dashboard',
            'Khair platform management', '/admin'),
      const _Action(Icons.help_outline_rounded, 'Help & Support',
          'Chat with Khair AI or agents', '/support'),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth >= 800
          ? 5
          : constraints.maxWidth >= 500
              ? 3
              : 2;
      return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: cols == 2 ? 1.22 : 1.3),
          itemBuilder: (_, i) => _ActionCard(
              action: actions[i],
              onTap: () async {
                if (actions[i].route == '/profile/edit') {
                  final changed = await context.push<bool>(actions[i].route);
                  if (changed == true) onUpdated();
                } else {
                  context.go(actions[i].route);
                }
              }));
    });
  }
}

class _Action {
  const _Action(this.icon, this.title, this.subtitle, this.route);
  final IconData icon;
  final String title, subtitle, route;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});
  final _Action action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _Surface(
      padding: const EdgeInsets.all(13),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: _roseSoft, borderRadius: BorderRadius.circular(10)),
            child: Icon(action.icon, color: _rose, size: 19)),
        const Spacer(),
        Text(action.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: _text(context),
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(action.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: _muted, fontSize: 11))
      ]));
}

class _DetailsColumn extends StatelessWidget {
  const _DetailsColumn({required this.overview, required this.onUpdated});
  final ProfileOverview overview;
  final VoidCallback onUpdated;
  @override
  Widget build(BuildContext context) => Column(children: [
        _AccountInfo(user: overview.user, onUpdated: onUpdated),
        const SizedBox(height: 20),
        _Preferences(overview: overview, onUpdated: onUpdated)
      ]);
}

class _AccountInfo extends StatelessWidget {
  const _AccountInfo({required this.user, required this.onUpdated});
  final ProfileUser user;
  final VoidCallback onUpdated;
  @override
  Widget build(BuildContext context) => _Panel(
          title: 'Account information',
          action: TextButton(
              onPressed: () async {
                final changed = await context.push<bool>('/profile/edit');
                if (changed == true) onUpdated();
              },
              child: const Text('Edit')),
          children: [
            _DetailRow(Icons.mail_outline, 'Email', user.email),
            _DetailRow(Icons.badge_outlined, 'Account type', user.accountType),
            _DetailRow(Icons.calendar_today_outlined, 'Member since',
                DateFormat('MMMM d, y').format(user.createdAt))
          ]);
}

class _Preferences extends StatelessWidget {
  const _Preferences({required this.overview, required this.onUpdated});
  final ProfileOverview overview;
  final VoidCallback onUpdated;
  @override
  Widget build(BuildContext context) => _Panel(title: 'Preferences', children: [
        _PreferenceSwitch(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: overview.preferences.pushNotifications
                ? 'Push notifications on'
                : 'Push notifications off',
            value: overview.preferences.pushNotifications,
            onChanged: (value) => _save(context, push: value)),
        _PreferenceSwitch(
            icon: Icons.email_outlined,
            title: 'Email updates',
            subtitle: overview.preferences.emailNotifications
                ? 'Email notifications on'
                : 'Email notifications off',
            value: overview.preferences.emailNotifications,
            onChanged: (value) => _save(context, email: value)),
        _DetailRow(Icons.language_outlined, 'Language',
            _language(overview.preferences.language), onTap: () async {
          final changed = await context.push<bool>('/profile/edit');
          if (changed == true) onUpdated();
        }),
        _DetailRow(Icons.location_on_outlined, 'Location',
            overview.preferences.locationLabel, onTap: () async {
          final changed = await context.push<bool>('/profile/edit');
          if (changed == true) onUpdated();
        }),
      ]);
  Future<void> _save(BuildContext context, {bool? push, bool? email}) async {
    try {
      await getIt<ProfileOverviewDataSource>().updatePreferences(
          pushNotifications: push, emailNotifications: email);
      onUpdated();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not update your preference. Please try again.')));
      }
    }
  }

  String _language(String value) =>
      switch (value) { 'ar' => 'Arabic', 'tr' => 'Turkish', _ => 'English' };
}

class _UpcomingEvents extends StatelessWidget {
  const _UpcomingEvents({required this.events});
  final List<UpcomingProfileEvent> events;
  @override
  Widget build(BuildContext context) => _Panel(
      title: 'Upcoming events',
      action: TextButton(
          onPressed: () => context.go('/my-events'),
          child: const Text('View all')),
      children: events.isEmpty
          ? [_EmptyUpcoming()]
          : events.map((event) => _UpcomingRow(event: event)).toList());
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.event});
  final UpcomingProfileEvent event;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: () => context.push('/events/${event.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                    width: 62,
                    height: 62,
                    child: event.imageUrl?.isNotEmpty == true
                        ? Image.network(ApiConfig.resolveUrl(event.imageUrl),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _EventFallback())
                        : _EventFallback())),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _text(context),
                          fontSize: 14)),
                  const SizedBox(height: 5),
                  Text(
                      DateFormat('EEE, MMM d · h:mm a').format(event.startDate),
                      style: TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Icon(
                        event.isOnline
                            ? Icons.videocam_outlined
                            : Icons.location_on_outlined,
                        color: _rose,
                        size: 13),
                    const SizedBox(width: 3),
                    Expanded(
                        child: Text(event.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _muted, fontSize: 12)))
                  ]),
                ])),
            const SizedBox(width: 8),
            _Badge(label: event.status == 'confirmed' ? 'Going' : event.status)
          ])));
}

class _EventFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      color: _roseSoft, child: const Icon(Icons.event_outlined, color: _rose));
}

class _EmptyUpcoming extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('No upcoming events yet',
            style:
                TextStyle(color: _text(context), fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Discover something worth showing up for.',
            style: TextStyle(color: _muted, fontSize: 13)),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: () => context.go('/'),
            child: const Text('Explore events'))
      ]));
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.children, this.action});
  final String title;
  final List<Widget> children;
  final Widget? action;
  @override
  Widget build(BuildContext context) => _Surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(title,
              style: TextStyle(
                  color: _text(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          if (action != null) action!
        ]),
        const SizedBox(height: 8),
        ...children
      ]));
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.icon, this.label, this.value, {this.onTap});
  final IconData icon;
  final String label, value;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Icon(icon, color: _rose, size: 19),
            const SizedBox(width: 11),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label, style: TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _text(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600))
                ])),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: _muted)
          ])));
}

class _PreferenceSwitch extends StatelessWidget {
  const _PreferenceSwitch(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.value,
      required this.onChanged});
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: _rose, size: 19),
        const SizedBox(width: 11),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  color: _text(context),
                  fontWeight: FontWeight.w600,
                  fontSize: 13)),
          Text(subtitle, style: TextStyle(color: _muted, fontSize: 11))
        ])),
        Switch(
            value: value,
            activeTrackColor: _rose.withValues(alpha: .5),
            activeThumbColor: _rose,
            onChanged: onChanged)
      ]));
}

class _AccountSafety extends StatelessWidget {
  @override
  Widget build(BuildContext context) => TextButton.icon(
      onPressed: () => context.read<AuthBloc>().add(LogoutRequested()),
      icon: const Icon(Icons.logout_outlined),
      label: const Text('Sign out'));
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: _text(context), fontSize: 20, fontWeight: FontWeight.w800));
}

class _Surface extends StatelessWidget {
  const _Surface(
      {required this.child,
      this.color,
      this.padding = const EdgeInsets.all(20),
      this.onTap});
  final Widget child;
  final Color? color;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
        color: color ?? (dark ? const Color(0xFF19181E) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
                padding: padding,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: dark ? const Color(0xFF302D35) : _border)),
                child: child)));
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 18),
        _Skeleton(height: 28, width: 110),
        const SizedBox(height: 22),
        const _Skeleton(height: 190),
        const SizedBox(height: 28),
        _Skeleton(height: 24, width: 150),
        const SizedBox(height: 12),
        const _Skeleton(height: 170),
        const SizedBox(height: 20),
        const _Skeleton(height: 240)
      ]);
}

class _Skeleton extends StatelessWidget {
  const _Skeleton({required this.height, this.width = double.infinity});
  final double height, width;
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF211F26)
              : const Color(0xFFF2EDF0),
          borderRadius: BorderRadius.circular(18)));
}

class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 42, color: _rose),
            const SizedBox(height: 14),
            Text('We couldn’t load your profile.',
                style: TextStyle(
                    color: _text(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Check your connection and try again.',
                style: TextStyle(color: _muted)),
            const SizedBox(height: 18),
            FilledButton(
                onPressed: onRetry,
                style: FilledButton.styleFrom(backgroundColor: _rose),
                child: const Text('Try again'))
          ])));
}

Color _text(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFF9F7FA)
        : _ink;
Color _surface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF101014)
        : Colors.white;
