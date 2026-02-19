import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _filter = 'pending';

  // Mock data for demonstration
  final List<_ReportData> _reports = [
    _ReportData(
      id: '1',
      targetType: 'event',
      targetName: 'Tech Conference 2026',
      reporterType: 'user',
      reasonCategory: 'spam',
      description: 'This appears to be a duplicate event with fake details.',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    _ReportData(
      id: '2',
      targetType: 'organizer',
      targetName: 'Fake Events Co.',
      reporterType: 'guest',
      reasonCategory: 'misleading_charity',
      description: 'This organizer claims donations but has no transparency.',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    _ReportData(
      id: '3',
      targetType: 'event',
      targetName: 'Political Rally',
      reporterType: 'system',
      reasonCategory: 'political_content',
      description: 'Automated flag: contains political keywords.',
      status: 'pending',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Management'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Column(
        children: [
          // Filter tabs
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('pending', 'Pending'),
                const SizedBox(width: 8),
                _buildFilterChip('reviewing', 'Reviewing'),
                const SizedBox(width: 8),
                _buildFilterChip('resolved', 'Resolved'),
              ],
            ),
          ),
          // Reports list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _reports.where((r) => r.status == _filter || _filter == 'all').length,
              itemBuilder: (context, index) {
                final filteredReports = _reports.where((r) => r.status == _filter || _filter == 'all').toList();
                return _buildReportCard(filteredReports[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppTheme.primaryColor.withAlpha(51),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildReportCard(_ReportData report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getReasonColor(report.reasonCategory).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  report.targetType == 'event' ? Icons.event : Icons.business,
                  color: _getReasonColor(report.reasonCategory),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.targetName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_formatReasonCategory(report.reasonCategory)} • ${_formatReporterType(report.reporterType)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getReasonColor(report.reasonCategory).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatReasonCategory(report.reasonCategory),
                  style: TextStyle(
                    color: _getReasonColor(report.reasonCategory),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Description
          if (report.description != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                report.description!,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          // Timestamp & actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d, y • HH:mm').format(report.createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _dismissReport(report),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showResolveDialog(report),
                    child: const Text('Resolve'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getReasonColor(String reason) {
    switch (reason) {
      case 'political_content':
        return AppTheme.warningColor;
      case 'hate_speech':
        return AppTheme.errorColor;
      case 'misleading_charity':
        return Colors.orange;
      case 'spam':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatReasonCategory(String reason) {
    return reason.replaceAll('_', ' ').split(' ').map((w) => 
      w[0].toUpperCase() + w.substring(1)
    ).join(' ');
  }

  String _formatReporterType(String type) {
    switch (type) {
      case 'system':
        return '🤖 System';
      case 'user':
        return '👤 User';
      default:
        return '👥 Guest';
    }
  }

  void _dismissReport(_ReportData report) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report for "${report.targetName}" dismissed')),
    );
    setState(() => _reports.remove(report));
  }

  void _showResolveDialog(_ReportData report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose an action for "${report.targetName}":'),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppTheme.successColor),
              title: const Text('Approve (No Action)'),
              onTap: () {
                Navigator.pop(context);
                _resolveWithAction(report, 'approve');
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: AppTheme.warningColor),
              title: const Text('Issue Warning'),
              onTap: () {
                Navigator.pop(context);
                _resolveWithAction(report, 'warn');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppTheme.errorColor),
              title: const Text('Remove Content'),
              onTap: () {
                Navigator.pop(context);
                _resolveWithAction(report, 'reject');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _resolveWithAction(_ReportData report, String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report resolved with action: $action')),
    );
    setState(() => _reports.remove(report));
  }
}

class _ReportData {
  final String id;
  final String targetType;
  final String targetName;
  final String reporterType;
  final String reasonCategory;
  final String? description;
  final String status;
  final DateTime createdAt;

  _ReportData({
    required this.id,
    required this.targetType,
    required this.targetName,
    required this.reporterType,
    required this.reasonCategory,
    this.description,
    required this.status,
    required this.createdAt,
  });
}
