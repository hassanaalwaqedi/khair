import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../events/domain/entities/event.dart';
import '../bloc/admin_bloc.dart';

class AdminEventReviewPage extends StatelessWidget {
  final Event event;

  const AdminEventReviewPage({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('EEEE, MMMM d, yyyy • h:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Event'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (event.imageUrl != null)
              Image.network(
                ApiConfig.resolveUrl(event.imageUrl),
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildImagePlaceholder(),
              )
            else
              _buildImagePlaceholder(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: KhairColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          event.eventType.toUpperCase(),
                          style: TextStyle(
                            color: KhairColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (event.category != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            event.category!.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    event.title,
                    style: KhairTypography.headlineLarge.copyWith(
                      color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'by ${event.organizerName ?? 'Unknown Organizer'}',
                    style: KhairTypography.bodyLarge.copyWith(
                      color: KhairColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSection(
                    icon: Icons.calendar_today,
                    title: 'Date & Time',
                    content: dateFormat.format(event.startDate),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: event.isOnline ? Icons.laptop_mac : Icons.location_on,
                    title: event.isOnline ? 'Online Event' : 'Location',
                    content: event.isOnline
                        ? (event.onlinePlatform ?? 'Virtual Platform')
                        : (event.fullAddress ?? [event.city, event.country].where((e) => e != null).join(', ')),
                  ),
                  if (event.capacity != null) ...[
                    const SizedBox(height: 16),
                    _buildSection(
                      icon: Icons.people_outline,
                      title: 'Capacity',
                      content: '${event.capacity} attendees',
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  Text(
                    'Description',
                    style: KhairTypography.labelLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    event.description ?? 'No description provided.',
                    style: KhairTypography.bodyMedium,
                  ),
                  if (event.tags.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: event.tags.map((tag) => Chip(
                        label: Text(tag),
                        backgroundColor: KhairColors.surfaceVariant,
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: BlocBuilder<AdminBloc, AdminState>(
            builder: (context, state) {
              final isLoading = state.isActionLoading;
              
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading ? null : () => _showRejectDialog(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: KhairColors.error,
                        side: const BorderSide(color: KhairColors.error),
                        shape: RoundedRectangleBorder(
                          borderRadius: KhairRadius.medium,
                        ),
                      ),
                      child: const Text('Reject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : () {
                        context.read<AdminBloc>().add(ApproveEvent(event.id));
                        context.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: KhairColors.success,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: KhairRadius.medium,
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Approve', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      height: 250,
      color: KhairColors.surfaceVariant,
      child: const Center(
        child: Icon(Icons.event, size: 64, color: KhairColors.textTertiary),
      ),
    );
  }

  Widget _buildSection({required IconData icon, required String title, required String content}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: KhairColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KhairTypography.labelMedium.copyWith(color: KhairColors.textSecondary)),
              const SizedBox(height: 4),
              Text(content, style: KhairTypography.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.adminRejectTitle(event.title)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.adminRejectConfirm(event.title)),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection reason',
                hintText: 'Provide a reason...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return; // Basic validation
              context.read<AdminBloc>().add(RejectEvent(event.id, reason));
              Navigator.pop(dialogContext);
              context.pop(); // pop the review page
            },
            style: FilledButton.styleFrom(backgroundColor: KhairColors.error),
            child: Text(context.l10n.adminReject),
          ),
        ],
      ),
    );
  }
}
