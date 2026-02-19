import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

class AuditLogsPage extends StatefulWidget {
  const AuditLogsPage({super.key});

  @override
  State<AuditLogsPage> createState() => _AuditLogsPageState();
}

class _AuditLogsPageState extends State<AuditLogsPage> {
  // Mock data for demonstration
  final List<_AuditLogEntry> _logs = [
    _AuditLogEntry(
      id: '1',
      actorType: 'admin',
      actorName: 'Admin User',
      action: 'organizer_approved',
      targetType: 'organizer',
      targetName: 'Tech Events Co.',
      reason: 'Verified organization credentials',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    _AuditLogEntry(
      id: '2',
      actorType: 'system',
      actorName: 'System',
      action: 'event_flagged',
      targetType: 'event',
      targetName: 'Political Rally',
      reason: 'Automated: Contains banned keywords',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _AuditLogEntry(
      id: '3',
      actorType: 'admin',
      actorName: 'Admin User',
      action: 'organizer_warned',
      targetType: 'organizer',
      targetName: 'Spam Events Ltd.',
      reason: 'Multiple spam reports received',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    _AuditLogEntry(
      id: '4',
      actorType: 'admin',
      actorName: 'Admin User',
      action: 'organizer_suspended',
      targetType: 'organizer',
      targetName: 'Fake Charity Org.',
      reason: 'Misleading charity claims confirmed',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    _AuditLogEntry(
      id: '5',
      actorType: 'admin',
      actorName: 'Admin User',
      action: 'event_approved',
      targetType: 'event',
      targetName: 'Flutter Workshop',
      reason: 'Content verified',
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Logs'),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _logs.length,
        itemBuilder: (context, index) => _buildLogEntry(_logs[index]),
      ),
    );
  }

  Widget _buildLogEntry(_AuditLogEntry log) {
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
          // Action icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getActionColor(log.action).withAlpha(26),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getActionIcon(log.action),
              color: _getActionColor(log.action),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action & target
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: Colors.grey[800], fontSize: 14),
                    children: [
                      TextSpan(
                        text: log.actorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' ${_formatAction(log.action)} ',
                      ),
                      TextSpan(
                        text: log.targetName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Reason
                if (log.reason != null)
                  Text(
                    log.reason!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                const SizedBox(height: 8),
                // Timestamp & badges
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('MMM d, y • HH:mm').format(log.createdAt),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: log.actorType == 'system' 
                          ? Colors.blue.withAlpha(26) 
                          : Colors.green.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.actorType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: log.actorType == 'system' ? Colors.blue : Colors.green,
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
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Logs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(label: const Text('All'), selected: true, onSelected: (_) {}),
                FilterChip(label: const Text('Admin'), selected: false, onSelected: (_) {}),
                FilterChip(label: const Text('System'), selected: false, onSelected: (_) {}),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Apply Filter'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuditLogEntry {
  final String id;
  final String actorType;
  final String actorName;
  final String action;
  final String targetType;
  final String targetName;
  final String? reason;
  final DateTime createdAt;

  _AuditLogEntry({
    required this.id,
    required this.actorType,
    required this.actorName,
    required this.action,
    required this.targetType,
    required this.targetName,
    this.reason,
    required this.createdAt,
  });
}
