import 'package:flutter/material.dart';

/// Shared password feedback used by attendee signup and event join flows.
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  const PasswordStrengthIndicator({super.key, required this.password});
  @override
  Widget build(BuildContext context) {
    final score = [password.length >= 8, RegExp(r'[A-Z]').hasMatch(password), RegExp(r'[0-9]').hasMatch(password), RegExp(r'[^A-Za-z0-9]').hasMatch(password)].where((value) => value).length;
    if (password.isEmpty) return const SizedBox.shrink();
    final color = score < 2 ? Colors.red : score < 4 ? Colors.orange : Colors.green;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(child: LinearProgressIndicator(value: score / 4, color: color, backgroundColor: color.withValues(alpha: .15))),
        const SizedBox(width: 8), Text(score < 2 ? 'Weak' : score < 4 ? 'Good' : 'Strong', style: TextStyle(color: color, fontSize: 12)),
      ]),
    );
  }
}
