import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Success page shown after joining an event
class ReservationSuccessPage extends StatelessWidget {
  final String eventId;

  const ReservationSuccessPage({super.key, required this.eventId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.successColor.withValues(alpha: 0.2),
                      AppTheme.primaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.successColor.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Islamic message
              const Text(
                'بسم الله الرحمن الرحيم',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'serif',
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              const Text(
                'You are registered!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              Text(
                'May this gathering benefit you.\nYour seat has been confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Add to calendar button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: Implement add to calendar
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Calendar integration coming soon!')),
                    );
                  },
                  icon: const Icon(Icons.calendar_today_rounded),
                  label: const Text('Add to Calendar',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // View my events button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/my-events');
                  },
                  icon: const Icon(Icons.event_rounded, color: Colors.white),
                  label: const Text('View My Events',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Back to browse
              TextButton(
                onPressed: () => context.go('/'),
                child: Text('Back to Events',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
