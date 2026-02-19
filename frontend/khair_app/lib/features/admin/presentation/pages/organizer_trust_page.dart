import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

class OrganizerTrustPage extends StatefulWidget {
  final String organizerId;

  const OrganizerTrustPage({super.key, required this.organizerId});

  @override
  State<OrganizerTrustPage> createState() => _OrganizerTrustPageState();
}

class _OrganizerTrustPageState extends State<OrganizerTrustPage> {
  // Mock data for demonstration
  late _OrganizerTrustData _trust;

  @override
  void initState() {
    super.initState();
    _trust = _OrganizerTrustData(
      organizerName: 'Community Events Co.',
      trustScore: 85,
      trustState: 'active',
      approvedEvents: 12,
      rejectedEvents: 1,
      reportsReceived: 2,
      cancellations: 0,
      warnings: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organizer Trust Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            _buildHeaderCard(),
            const SizedBox(height: 24),
            
            // Trust score gauge
            _buildTrustScoreCard(),
            const SizedBox(height: 24),
            
            // Metrics grid
            _buildMetricsGrid(),
            const SizedBox(height: 24),
            
            // Actions
            const Text(
              'Trust Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildActionButtons(),
          ],
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
            _getStateColor(_trust.trustState),
            _getStateColor(_trust.trustState).withAlpha(179),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
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
                  _trust.organizerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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
                    _formatState(_trust.trustState),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

  Widget _buildTrustScoreCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Trust Score',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CircularProgressIndicator(
                  value: _trust.trustScore / 100,
                  strokeWidth: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation(_getTrustScoreColor(_trust.trustScore)),
                ),
              ),
              Column(
                children: [
                  Text(
                    '${_trust.trustScore}',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: _getTrustScoreColor(_trust.trustScore),
                    ),
                  ),
                  Text(
                    _getTrustLevel(_trust.trustScore),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Approved Events', '${_trust.approvedEvents}', Icons.check_circle, AppTheme.successColor),
        _buildMetricCard('Rejected Events', '${_trust.rejectedEvents}', Icons.cancel, AppTheme.errorColor),
        _buildMetricCard('Reports Received', '${_trust.reportsReceived}', Icons.flag, AppTheme.warningColor),
        _buildMetricCard('Warnings Issued', '${_trust.warnings}', Icons.warning, Colors.orange),
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
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        if (_trust.trustState == 'active') ...[
          _buildActionButton('Issue Warning', Icons.warning, AppTheme.warningColor, () => _changeState('warning')),
          const SizedBox(height: 8),
          _buildActionButton('Suspend Organizer', Icons.pause_circle, Colors.orange, () => _changeState('suspended')),
          const SizedBox(height: 8),
          _buildActionButton('Ban Organizer', Icons.block, AppTheme.errorColor, () => _changeState('banned')),
        ],
        if (_trust.trustState == 'warning') ...[
          _buildActionButton('Clear Warning', Icons.check_circle, AppTheme.successColor, () => _changeState('active')),
          const SizedBox(height: 8),
          _buildActionButton('Suspend Organizer', Icons.pause_circle, Colors.orange, () => _changeState('suspended')),
        ],
        if (_trust.trustState == 'suspended' || _trust.trustState == 'banned') ...[
          _buildActionButton('Reinstate Organizer', Icons.restore, AppTheme.successColor, () => _changeState('active')),
        ],
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showConfirmDialog(label, color, onPressed),
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
      case 'active':
        return AppTheme.successColor;
      case 'warning':
        return AppTheme.warningColor;
      case 'suspended':
        return Colors.orange;
      case 'banned':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  String _formatState(String state) {
    return state.toUpperCase();
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

  void _changeState(String newState) {
    setState(() {
      _trust = _OrganizerTrustData(
        organizerName: _trust.organizerName,
        trustScore: _trust.trustScore,
        trustState: newState,
        approvedEvents: _trust.approvedEvents,
        rejectedEvents: _trust.rejectedEvents,
        reportsReceived: _trust.reportsReceived,
        cancellations: _trust.cancellations,
        warnings: newState == 'warning' ? _trust.warnings + 1 : _trust.warnings,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Organizer state changed to ${_formatState(newState)}')),
    );
  }

  void _showConfirmDialog(String action, Color color, VoidCallback onConfirm) {
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Are you sure you want to $action?'),
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
              onConfirm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: color),
            child: Text(action, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _OrganizerTrustData {
  final String organizerName;
  final int trustScore;
  final String trustState;
  final int approvedEvents;
  final int rejectedEvents;
  final int reportsReceived;
  final int cancellations;
  final int warnings;

  _OrganizerTrustData({
    required this.organizerName,
    required this.trustScore,
    required this.trustState,
    required this.approvedEvents,
    required this.rejectedEvents,
    required this.reportsReceived,
    required this.cancellations,
    required this.warnings,
  });
}
