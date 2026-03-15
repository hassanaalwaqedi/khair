import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_theme.dart';

class OrganizerTrustPage extends StatefulWidget {
  final String organizerId;

  const OrganizerTrustPage({super.key, required this.organizerId});

  @override
  State<OrganizerTrustPage> createState() => _OrganizerTrustPageState();
}

class _OrganizerTrustPageState extends State<OrganizerTrustPage> {
  Map<String, dynamic>? _trustScore;
  String _trustState = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrustData();
  }

  Future<void> _fetchTrustData() async {
    setState(() => _loading = true);
    try {
      final dio = getIt<Dio>();
      final response = await dio.get('/admin/organizers/${widget.organizerId}/trust');
      final data = response.data;
      if (data['success'] == true) {
        setState(() {
          _trustScore = data['data']?['trust_score'] as Map<String, dynamic>?;
          _trustState = (data['data']?['state'] ?? '').toString();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load trust data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Organizer Trust Profile')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final score = _trustScore?['trust_score'] ?? 0;
    final approved = _trustScore?['approved_events_count'] ?? 0;
    final rejected = _trustScore?['rejected_events_count'] ?? 0;
    final reports = _trustScore?['reports_received_count'] ?? 0;
    final warnings = _trustScore?['warnings_count'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Trust Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTrustData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 24),
              _buildTrustScoreCard(score),
              const SizedBox(height: 24),
              _buildMetricsGrid(approved, rejected, reports, warnings),
              const SizedBox(height: 24),
              const Text('Trust Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getStateColor(_trustState),
            _getStateColor(_trustState).withAlpha(179),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(51),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.business, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Organizer #${widget.organizerId.substring(0, 8)}',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(51),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _trustState.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustScoreCard(dynamic score) {
    final numScore = (score is int) ? score : int.tryParse(score.toString()) ?? 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10)],
      ),
      child: Column(
        children: [
          const Text('Trust Score',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150, height: 150,
                child: CircularProgressIndicator(
                  value: numScore / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(_getTrustScoreColor(numScore)),
                ),
              ),
              Column(
                children: [
                  Text('$numScore',
                    style: TextStyle(
                      fontSize: 40, fontWeight: FontWeight.bold,
                      color: _getTrustScoreColor(numScore),
                    ),
                  ),
                  Text(_getTrustLevel(numScore),
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(dynamic approved, dynamic rejected, dynamic reports, dynamic warnings) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Approved Events', '$approved', Icons.check_circle, AppTheme.successColor),
        _buildMetricCard('Rejected Events', '$rejected', Icons.cancel, AppTheme.errorColor),
        _buildMetricCard('Reports Received', '$reports', Icons.flag, AppTheme.warningColor),
        _buildMetricCard('Warnings Issued', '$warnings', Icons.warning, Colors.orange),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(51)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(value,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 4),
          Text(label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_trustState == 'active') ...[
          _buildActionButton('Issue Warning', Icons.warning, AppTheme.warningColor, 'warn'),
          const SizedBox(height: 8),
          _buildActionButton('Suspend', Icons.pause_circle, Colors.orange, 'suspend'),
          const SizedBox(height: 8),
          _buildActionButton('Ban', Icons.block, AppTheme.errorColor, 'ban'),
        ],
        if (_trustState == 'warning') ...[
          _buildActionButton('Reinstate', Icons.check_circle, AppTheme.successColor, 'reinstate'),
          const SizedBox(height: 8),
          _buildActionButton('Suspend', Icons.pause_circle, Colors.orange, 'suspend'),
        ],
        if (_trustState == 'suspended' || _trustState == 'banned') ...[
          _buildActionButton('Reinstate', Icons.restore, AppTheme.successColor, 'reinstate'),
        ],
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, String action) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showConfirmDialog(label, color, action),
        icon: Icon(icon, color: color),
        label: Text(label, style: TextStyle(color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.withAlpha(128)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'active': return AppTheme.successColor;
      case 'warning': return AppTheme.warningColor;
      case 'suspended': return Colors.orange;
      case 'banned': return AppTheme.errorColor;
      default: return Colors.grey;
    }
  }

  Color _getTrustScoreColor(int score) {
    if (score >= 70) return AppTheme.successColor;
    if (score >= 40) return AppTheme.warningColor;
    return AppTheme.errorColor;
  }

  String _getTrustLevel(int score) {
    if (score >= 70) return 'Excellent';
    if (score >= 40) return 'Fair';
    return 'Poor';
  }

  void _showConfirmDialog(String label, Color color, String action) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $label this organizer?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performAction(action, reasonController.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(label, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _performAction(String action, String reason) async {
    try {
      final dio = getIt<Dio>();
      await dio.post(
        '/admin/organizers/${widget.organizerId}/$action',
        data: {'reason': reason},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action completed: $action')),
        );
      }
      _fetchTrustData(); // Refresh
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }
}
