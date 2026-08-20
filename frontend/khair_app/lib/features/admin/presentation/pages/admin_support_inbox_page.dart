import 'package:khair_app/core/locale/l10n_extension.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.adminActionFailed)));
      }
    }
  }

  Future<void> _assignTicket(String ticketId) async {
    try {
      final apiClient = getIt<ApiClient>();
      await apiClient.post('/admin/support/tickets/$ticketId/assign');
      _loadTickets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.ticketAssigned)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.adminActionFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.supportInbox),
        actions: [
          DropdownButton<String>(
            value: _statusFilter,
            items: [
              DropdownMenuItem(value: 'open', child: Text(context.l10n.open)),
              DropdownMenuItem(value: 'waiting_for_support', child: Text(context.l10n.waitingForSupport)),
              DropdownMenuItem(value: 'in_progress', child: Text(context.l10n.inProgress)),
              DropdownMenuItem(value: 'resolved', child: Text(context.l10n.resolved)),
              DropdownMenuItem(value: 'all', child: Text(context.l10n.mapFilterAll)),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _statusFilter = val);
                _loadTickets();
              }
            },
          ),
          SizedBox(width: 16),
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadTickets),
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator())
        : ListView.builder(
            itemCount: _tickets.length,
            itemBuilder: (context, index) {
              final t = _tickets[index];
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(t['subject'] ?? ''),
                  subtitle: Text(context.l10n.supportTicketSummary(
                    t['user_name']?.toString() ?? '',
                    t['user_email']?.toString() ?? '',
                    t['status']?.toString() ?? '',
                    t['priority']?.toString() ?? '',
                  )),
                  isThreeLine: true,
                  trailing: t['status'] == 'waiting_for_support'
                    ? ElevatedButton(
                        onPressed: () => _assignTicket(t['id']),
                        child: Text(context.l10n.assignToMe),
                      )
                    : (t['assigned_to_name'] != null
                        ? Text(context.l10n.assignedTo(
                            t['assigned_to_name'].toString()))
                        : SizedBox()),
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
              leading: CloseButton(),
            ),
            if (widget.ticket['ai_summary'] != null)
              Container(
                padding: EdgeInsets.all(8),
                color: KhairColors.neutral100,
                width: double.infinity,
                child: Text(
                  context.l10n.aiSummary(
                      widget.ticket['ai_summary']?.toString() ?? ''),
                  style: TextStyle(fontSize: 12),
                ),
              ),
            Expanded(
              child: _isLoading && _messages.isEmpty
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final m = _messages[index];
                      final isAgent = m.senderType == 'support_agent' || m.senderType == 'system';
                      final isInternal = m.senderType == 'system';
                      return Align(
                        alignment: isAgent ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
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
                              Text(m.senderName ?? m.senderType, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(m.body),
                              Text(DateFormat.yMd().add_jm().format(m.createdAt), style: TextStyle(fontSize: 10, color: Colors.black54)),
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
                      decoration: InputDecoration(hintText: context.l10n.typeReply, border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Column(
                    children: [
                      ElevatedButton(onPressed: () => _sendMessage(false), child: Text(context.l10n.replyToUser)),
                      SizedBox(height: 8),
                      TextButton(onPressed: () => _sendMessage(true), child: Text(context.l10n.internalNote)),
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
