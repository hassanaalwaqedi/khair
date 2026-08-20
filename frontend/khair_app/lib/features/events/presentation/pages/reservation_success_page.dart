import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';

/// Success page shown after joining an event
class ReservationSuccessPage extends StatelessWidget {
  final String eventId;
  final bool isPaid;

  const ReservationSuccessPage({
    super.key,
    required this.eventId,
    this.isPaid = false,
  });

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
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
              SizedBox(height: 32),

              // Islamic message
              Text(
                'بسم الله الرحمن الرحيم',
                style: TextStyle(
                  fontSize: 18,
                  fontFamily: 'serif',
                  color: AppTheme.primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),

              Text(
                'You are registered!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),

              Text(
                'May this gathering benefit you.\nYour seat has been confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              if (isPaid) ...[
                SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.amber),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This is a paid event. Please remember to bring payment to the venue.',
                          style: TextStyle(
                            color: Colors.amber[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 40),



              // View my events button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/my-events');
                  },
                  icon: Icon(Icons.event_rounded, color: Colors.white),
                  label: Text(context.l10n.viewMyEvents,
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
              SizedBox(height: 12),

              // Back to browse
              TextButton(
                onPressed: () => context.go('/'),
                child: Text(context.l10n.eventDetailsBack,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
