import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/organizer_application_admin_api.dart';

/// The dedicated review queue for the new normalized organizer applications.
/// It does not reuse the legacy organizer summary API, so reviewers always see
/// the submitted trust dossier and its canonical status.
class OrganizerApplicationListPage extends StatefulWidget {
  const OrganizerApplicationListPage({super.key});

  @override
  State<OrganizerApplicationListPage> createState() =>
      _OrganizerApplicationListPageState();
}

class _OrganizerApplicationListPageState
    extends State<OrganizerApplicationListPage> {
  final _api = OrganizerApplicationAdminApi();
  String _filter = 'pending';
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = _api.list(status: _filter));

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Color(0xfffdfbfc),
        appBar: AppBar(
          title: Text(context.l10n.organizerApplications),
          actions: [
            IconButton(
              tooltip: context.l10n.refreshQueue,
              onPressed: _refresh,
              icon: Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'pending', label: Text(context.l10n.statusPending)),
                  ButtonSegment(
                      value: 'needs_revision', label: Text(context.l10n.needsChanges)),
                  ButtonSegment(value: 'approved', label: Text(context.l10n.orgApproved)),
                  ButtonSegment(value: 'rejected', label: Text(context.l10n.statusRejected)),
                ],
                selected: {_filter},
                onSelectionChanged: (value) {
                  _filter = value.first;
                  _refresh();
                },
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) return _QueueError(onRetry: _refresh);
                final applications = snapshot.data ?? const [];
                if (applications.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView(children: [
                      SizedBox(height: 170),
                      Icon(Icons.task_alt_outlined,
                          size: 48, color: Color(0xff8a8492)),
                      SizedBox(height: 12),
                      Center(
                          child: Text(context.l10n.noApplicationsInThisQueue,
                              style: TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 18))),
                      SizedBox(height: 6),
                      Center(
                          child: Text(context.l10n.newSubmissionsWillAppearHere,
                              style: TextStyle(color: Color(0xff716b7d)))),
                    ]),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    itemCount: applications.length,
                    separatorBuilder: (_, __) => SizedBox(height: 10),
                    itemBuilder: (context, index) => _ApplicationCard(
                      application: applications[index],
                      onTap: () async {
                        final id = applications[index]['id']?.toString();
                        if (id == null) return;
                        await context.push('/admin/organizer-applications/$id');
                        if (mounted) _refresh();
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ]),
      );
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});
  final Map<String, dynamic> application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = application['public_name']?.toString() ?? 'Unnamed organizer';
    final status = application['status']?.toString() ?? 'draft';
    final city = application['city']?.toString() ?? '';
    final country = application['country_code']?.toString() ?? '';
    final type = application['organizer_type']?.toString() ?? 'organizer';
    final submitted = application['submitted_at']?.toString();
    final initial =
        name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: Color(0xffffe7ee),
              child: Text(initial,
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xfff43f75),
                      fontSize: 19)),
            ),
            SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  SizedBox(height: 4),
                  Text(
                      '${_display(type)}${city.isEmpty ? '' : ' · $city'}${country.isEmpty ? '' : ', $country'}',
                      style: TextStyle(color: Color(0xff716b7d))),
                  if (submitted != null) ...[
                    SizedBox(height: 4),
                    Text(context.l10n.submittedOn(_shortDate(submitted)),
                        style: TextStyle(
                            fontSize: 12, color: Color(0xff8a8492))),
                  ],
                ])),
            SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              _StatusChip(status),
              SizedBox(height: 12),
              Icon(Icons.chevron_right_rounded),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _display(String value) => value
      .split('_')
      .map((part) =>
          part.isEmpty ? '' : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
  static String _shortDate(String source) {
    final date = DateTime.tryParse(source)?.toLocal();
    if (date == null) return 'recently';
    return '${date.day.toString().padLeft(2, '0')} ${_months[date.month - 1]} ${date.year}';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.status);
  final String status;
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'approved' => (Color(0xff1f9d63), 'Approved'),
      'needs_revision' => (Color(0xffbd7411), 'Needs changes'),
      'rejected' => (Color(0xffc33a54), 'Rejected'),
      _ => (Color(0xfff43f75), 'Pending'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .11),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class _QueueError extends StatelessWidget {
  const _QueueError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_outlined, size: 44),
          SizedBox(height: 12),
          Text(context.l10n.theOrganizerQueueCouldNotBeLoa),
          SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(context.l10n.tryAgain)),
        ]),
      );
}
