import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:khair_app/core/config/api_config.dart';
import 'package:khair_app/core/network/api_client.dart';
import 'package:khair_app/core/di/injection.dart';
import 'package:khair_app/features/support/data/models/support_model.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:intl/intl.dart';

class AdminSupportInboxPage extends StatefulWidget {
  const AdminSupportInboxPage({super.key});

  @override
  State<AdminSupportInboxPage> createState() => _AdminSupportInboxPageState();
}

class _AdminSupportInboxPageState extends State<AdminSupportInboxPage> {
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  String _statusFilter = 'open';

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.get('/admin/support/tickets?status=$_statusFilter');
      setState(() {
        _tickets = response.data['tickets'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load tickets: $e')));
      }
    }
  }

  Future<void> _assignTicket(String ticketId) async {
    try {
      final apiClient = getIt<ApiClient>();
      await apiClient.post('/admin/support/tickets/$ticketId/assign');
      _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ticket assigned')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to assign ticket: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Inbox'),
        actions: [
          DropdownButton<String>(
            value: _statusFilter,
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Open')),
              DropdownMenuItem(value: 'waiting_for_support', child: Text('Waiting for Support')),
              DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              DropdownMenuItem(value: 'all', child: Text('All')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _statusFilter = val);
                _loadTickets();
              }
            },
          ),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTickets),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _tickets.length,
            itemBuilder: (context, index) {
              final t = _tickets[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(t['subject'] ?? ''),
                  subtitle: Text('${t['user_name']} (${t['user_email']})\nStatus: ${t['status']} | Priority: ${t['priority']}'),
                  isThreeLine: true,
                  trailing: t['status'] == 'waiting_for_support'
                    ? ElevatedButton(
                        onPressed: () => _assignTicket(t['id']),
                        child: const Text('Assign to me'),
                      )
                    : (t['assigned_to_name'] != null ? Text('Assigned: ${t['assigned_to_name']}') : const SizedBox()),
                  onTap: () {
                    // Open a dialog or new page for chat
                    _showChatDialog(t);
                  },
                ),
              );
            },
          ),
    );
  }

  void _showChatDialog(Map<String, dynamic> ticket) {
    showDialog(
      context: context,
      builder: (context) => _AdminChatDialog(ticket: ticket),
    ).then((_) => _loadTickets());
  }
}

class _AdminChatDialog extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const _AdminChatDialog({required this.ticket});

  @override
  State<_AdminChatDialog> createState() => _AdminChatDialogState();
}

class _AdminChatDialogState extends State<_AdminChatDialog> {
  List<SupportMessage> _messages = [];
  bool _isLoading = true;
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final apiClient = getIt<ApiClient>();
      final response = await apiClient.get('/support/tickets/${widget.ticket['id']}/messages');
      final List list = response.data['messages'] ?? [];
      setState(() {
        _messages = list.map((e) => SupportMessage.fromJson(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage(bool isInternal) async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final apiClient = getIt<ApiClient>();
      await apiClient.post('/support/tickets/${widget.ticket['id']}/messages', data: {
        'body': text,
        'message_type': isInternal ? 'internal_note' : 'text',
      });
      _msgController.clear();
      _loadMessages();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 600,
        height: 800,
        child: Column(
          children: [
            AppBar(
              title: Text(widget.ticket['subject']),
              leading: const CloseButton(),
            ),
            if (widget.ticket['ai_summary'] != null)
              Container(
                padding: const EdgeInsets.all(8),
                color: KhairColors.neutral100,
                width: double.infinity,
                child: Text('AI Summary: ${widget.ticket['ai_summary']}', style: const TextStyle(fontSize: 12)),
              ),
            Expanded(
              child: _isLoading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isAgent = m.senderType == 'support_agent' || m.senderType == 'system';
                      final isInternal = m.senderType == 'system';
                      return Align(
                        alignment: isAgent ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isInternal ? KhairColors.warningLight : (isAgent ? KhairColors.primaryLight : KhairColors.neutral100),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.senderName ?? m.senderType, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(m.body),
                              Text(DateFormat.yMd().add_jm().format(m.createdAt), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(hintText: 'Type reply...', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      ElevatedButton(onPressed: () => _sendMessage(false), child: const Text('Reply to User')),
                      const SizedBox(height: 8),
                      TextButton(onPressed: () => _sendMessage(true), child: const Text('Internal Note')),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
