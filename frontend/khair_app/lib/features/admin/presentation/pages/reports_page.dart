import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _filter = 'pending';
  List<Map<String, dynamic>> _reports = [];
  bool _loading = true;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _loading = true);
    try {
      final dio = getIt<Dio>();
      final response = await dio.get('/admin/reports', queryParameters: {
        'status': _filter,
      });
      final data = response.data;
      if (data['success'] == true) {
        setState(() {
          _reports = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _total = data['total'] ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reports: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Reports Management ($_total)'),
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
                _buildFilterChip('resolved', 'Resolved'),
                const SizedBox(width: 8),
                _buildFilterChip('dismissed', 'Dismissed'),
              ],
            ),
          ),
          // Reports list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No $_filter reports',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _reports.length,
                          itemBuilder: (context, index) =>
                              _buildReportCard(_reports[index]),
                        ),
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
      onSelected: (_) {
        setState(() => _filter = value);
        _fetchReports();
      },
      selectedColor: AppTheme.primaryColor.withAlpha(51),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : null,
        fontWeight: isSelected ? FontWeight.bold : null,
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final targetType = report['target_type'] ?? '';
    final reasonCategory = report['reason_category'] ?? '';
    final description = report['description'];
    final createdAt = DateTime.tryParse(report['created_at'] ?? '') ?? DateTime.now();
    final reportId = report['id'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _getReasonColor(reasonCategory).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  targetType == 'event' ? Icons.event : Icons.business,
                  color: _getReasonColor(reasonCategory),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$targetType #${reportId.toString().substring(0, 8)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatReasonCategory(reasonCategory),
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getReasonColor(reasonCategory).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatReasonCategory(reasonCategory),
                  style: TextStyle(
                    color: _getReasonColor(reasonCategory),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (description != null && description.toString().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                description.toString(),
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMM d, y • HH:mm').format(createdAt),
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
              if (_filter == 'pending')
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _dismissReport(reportId),
                      child: const Text('Dismiss'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showResolveDialog(reportId),
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
    if (reason.isEmpty) return 'Unknown';
    return reason.replaceAll('_', ' ').split(' ').map((w) =>
      w[0].toUpperCase() + w.substring(1)
    ).join(' ');
  }

  Future<void> _dismissReport(String reportId) async {
    try {
      final dio = getIt<Dio>();
      await dio.post('/admin/reports/$reportId/dismiss');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report dismissed')),
        );
      }
      _fetchReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to dismiss: $e')),
        );
      }
    }
  }

  void _showResolveDialog(String reportId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppTheme.successColor),
              title: const Text('Approve (No Action)'),
              onTap: () {
                Navigator.pop(context);
                _resolveWithAction(reportId, 'approve');
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning, color: AppTheme.warningColor),
              title: const Text('Issue Warning'),
              onTap: () {
                Navigator.pop(context);
                _resolveWithAction(reportId, 'warn');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppTheme.errorColor),
              title: const Text('Remove Content'),
              onTap: () {
                Navigator.pop(context);
                _resolveWithAction(reportId, 'reject');
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

  Future<void> _resolveWithAction(String reportId, String action) async {
    try {
      final dio = getIt<Dio>();
      await dio.post('/admin/reports/$reportId/resolve', data: {
        'action': action,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report resolved with action: $action')),
        );
      }
      _fetchReports();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resolve: $e')),
        );
      }
    }
  }
}
