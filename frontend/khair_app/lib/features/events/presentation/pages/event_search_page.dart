import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../data/datasources/events_remote_datasource.dart';
import '../../domain/entities/event.dart';
import '../widgets/event_card.dart';
import '../pages/event_details_page.dart';

/// Full‑screen search page that queries the backend as the user types.
class EventSearchPage extends StatefulWidget {
  const EventSearchPage({super.key});

  @override
  State<EventSearchPage> createState() => _EventSearchPageState();
}

class _EventSearchPageState extends State<EventSearchPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<Event> _results = [];
  bool _loading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // Auto‑focus the text field on page open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(query));
  }

  Future<void> _search(String query) async {
    try {
      final ds = GetIt.instance<EventsRemoteDataSource>();
      final models = await ds.getEvents({'search': query.trim(), 'limit': 20});
      if (!mounted) return;
      setState(() {
        _results = models.cast<Event>();
        _loading = false;
        _hasSearched = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _hasSearched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? KhairColors.darkBackground : KhairColors.background;
    final searchBg = isDark ? KhairColors.darkSurfaceVariant : KhairColors.surfaceVariant;
    final bdr = isDark ? KhairColors.darkBorder : KhairColors.border;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search header ──
            Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 12),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: tp),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: searchBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: bdr),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: ts, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              onChanged: _onSearchChanged,
                              style: TextStyle(color: tp, fontSize: 14),
                              decoration: InputDecoration(
                                hintText: context.l10n.searchEventsHint,
                                hintStyle: TextStyle(color: ts, fontSize: 14),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (_controller.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                _controller.clear();
                                _onSearchChanged('');
                              },
                              child: Icon(Icons.close_rounded, color: ts, size: 18),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ──
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_hasSearched
                      ? _buildInitialState(ts)
                      : _results.isEmpty
                          ? _buildEmptyState(ts)
                          : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialState(Color ts) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 64, color: ts.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            context.l10n.searchEventsHint,
            style: TextStyle(color: ts, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color ts) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: ts.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            context.l10n.noEventsFound,
            style: TextStyle(color: ts, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.searchEventsHint,
            style: TextStyle(color: ts, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final event = _results[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SizedBox(
            height: 340,
            child: EventCard(
              event: event,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EventDetailsPage(eventId: event.id),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
