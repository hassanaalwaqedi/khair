import 'package:flutter/material.dart';

/// Live password strength indicator with color-coded segments
class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({super.key, required this.password});

  @override
  Widget build(BuildContext context) {
    final strength = _calculateStrength(password);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 0; i < 4; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < strength.score
                        ? strength.color
                        : Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < 3) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strength.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: strength.color,
              ),
            ),
            if (strength.tips.isNotEmpty)
              Flexible(
                child: Text(
                  strength.tips.first,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }

  static _PasswordResult _calculateStrength(String password) {
    if (password.isEmpty) {
      return _PasswordResult(0, 'Enter a password', Colors.grey, []);
    }

    int score = 0;
    final tips = <String>[];

    if (password.length >= 8) {
      score++;
    } else {
      tips.add('Use at least 8 characters');
    }
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    } else {
      tips.add('Mix upper and lowercase');
    }
    if (RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      score++;
    } else {
      tips.add('Add numbers and symbols');
    }

    final labels = ['Weak', 'Fair', 'Good', 'Strong', 'Very Strong'];
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.amber[700]!,
      Colors.green,
      Colors.green[700]!,
    ];

    return _PasswordResult(score, labels[score], colors[score], tips);
  }
}

class _PasswordResult {
  final int score;
  final String label;
  final Color color;
  final List<String> tips;
  _PasswordResult(this.score, this.label, this.color, this.tips);
}
