import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  int _total = 0;
  String? _actorTypeFilter;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    try {
      final dio = getIt<Dio>();
      final params = <String, dynamic>{};
      if (_actorTypeFilter != null) params['actor_type'] = _actorTypeFilter;

      final response = await dio.get('/admin/audit-logs', queryParameters: params);
      final data = response.data;
      if (data['success'] == true) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _total = data['total'] ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load audit logs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audit Logs ($_total)'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No audit logs found',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) => _buildLogEntry(_logs[index]),
                  ),
                ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final actorType = log['actor_type'] ?? '';
    final action = (log['action'] ?? '').toString();
    final targetType = log['target_type'] ?? '';
    final targetId = (log['target_id'] ?? '').toString();
    final reason = log['reason'];
    final createdAt = DateTime.tryParse(log['created_at'] ?? '') ?? DateTime.now();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withAlpha(51)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getActionColor(action).withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getActionIcon(action),
              color: _getActionColor(action),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    children: [
                      TextSpan(
                        text: actorType == 'system' ? 'System' : 'Admin',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' ${_formatAction(action)} '),
                      TextSpan(
                        text: '$targetType #${targetId.length > 8 ? targetId.substring(0, 8) : targetId}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                if (reason != null && reason.toString().isNotEmpty)
                  Text(
                    reason.toString(),
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, y • HH:mm').format(createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: actorType == 'system'
                            ? Colors.blue.withAlpha(26)
                            : Colors.green.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        actorType.toString().toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: actorType == 'system' ? Colors.blue : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String action) {
    if (action.contains('approved')) return Icons.check_circle;
    if (action.contains('rejected')) return Icons.cancel;
    if (action.contains('warned')) return Icons.warning;
    if (action.contains('suspended')) return Icons.pause_circle;
    if (action.contains('banned')) return Icons.block;
    if (action.contains('reinstated')) return Icons.restore;
    if (action.contains('flagged')) return Icons.flag;
    return Icons.edit;
  }

  Color _getActionColor(String action) {
    if (action.contains('approved')) return AppTheme.successColor;
    if (action.contains('rejected')) return AppTheme.errorColor;
    if (action.contains('warned')) return AppTheme.warningColor;
    if (action.contains('suspended')) return Colors.orange;
    if (action.contains('banned')) return AppTheme.errorColor;
    if (action.contains('reinstated')) return AppTheme.successColor;
    if (action.contains('flagged')) return AppTheme.warningColor;
    return Colors.grey;
  }

  String _formatAction(String action) {
    return action.replaceAll('_', ' ');
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filter Logs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _actorTypeFilter == null,
                  onSelected: (_) {
                    setState(() => _actorTypeFilter = null);
                    Navigator.pop(ctx);
                    _fetchLogs();
                  },
                ),
                FilterChip(
                  label: const Text('Admin'),
                  selected: _actorTypeFilter == 'admin',
                  onSelected: (_) {
                    setState(() => _actorTypeFilter = 'admin');
                    Navigator.pop(ctx);
                    _fetchLogs();
                  },
                ),
                FilterChip(
                  label: const Text('System'),
                  selected: _actorTypeFilter == 'system',
                  onSelected: (_) {
                    setState(() => _actorTypeFilter = 'system');
                    Navigator.pop(ctx);
                    _fetchLogs();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
