import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/utils/share_helper.dart';
import '../../domain/entities/sheikh_profile.dart';

/// Full-page sheikh profile detail page.
class SheikhProfilePage extends StatelessWidget {
  final SheikhProfile sheikh;
  const SheikhProfilePage({super.key, required this.sheikh});

  String _resolveUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'https://khair.it.com$url';
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _resolveUrl(sheikh.avatarUrl);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A2E1C),
                  Color(0xFF0D3D26),
                  Color(0xFF0B2E23),
                  Color(0xFF071E18),
                ],
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _SubtlePatternPainter()),
          ),
          SafeArea(
            child: Column(
              children: [
                // App bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white),
                        onPressed: () => context.pop(),
                      ),
                      const Spacer(),
                      Text(
                        'Sheikh Profile',
                        style: KhairTypography.headlineSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined,
                            color: Colors.white),
                        onPressed: () => _shareSheikh(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    child: Column(
                      children: [
                        // Avatar
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF0B5F50),
                                    Color(0xFF2D8E75)
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFFD4A84B)
                                      .withValues(alpha: 0.5),
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0B5F50)
                                        .withValues(alpha: 0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                        errorBuilder: (_, __, ___) =>
                                            _buildInitials(),
                                      ),
                                    )
                                  : _buildInitials(),
                            ),
                            if (sheikh.isVerified)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD4A84B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.verified,
                                      size: 22, color: Color(0xFF0A2E1C)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Name
                        Text(
                          sheikh.name,
                          style: KhairTypography.h2.copyWith(
                            color: Colors.white,
                            fontSize: 26,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

                        // Specialization badge
                        if (sheikh.specialization != null &&
                            sheikh.specialization!.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4A84B)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFD4A84B)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              sheikh.specialization!,
                              style: KhairTypography.labelMedium.copyWith(
                                color: const Color(0xFFD4A84B),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),

                        // Info cards row
                        Row(
                          children: [
                            if (sheikh.city != null ||
                                sheikh.country != null) ...[
                              Expanded(
                                child: _InfoTile(
                                  icon: Icons.location_on_outlined,
                                  label: 'Location',
                                  value: [
                                    if (sheikh.city != null) sheikh.city!,
                                    if (sheikh.country != null)
                                      sheikh.country!,
                                  ].join(', '),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (sheikh.yearsOfExperience != null)
                              Expanded(
                                child: _InfoTile(
                                  icon: Icons.star_outline_rounded,
                                  label: 'Experience',
                                  value:
                                      '${sheikh.yearsOfExperience} years',
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Verification status
                        _InfoTile(
                          icon: sheikh.isVerified
                              ? Icons.verified_rounded
                              : Icons.pending_outlined,
                          label: 'Verification',
                          value: sheikh.isVerified
                              ? 'Verified Sheikh'
                              : 'Pending Verification',
                          valueColor: sheikh.isVerified
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFFF9800),
                        ),
                        const SizedBox(height: 20),

                        // Bio section
                        if (sheikh.bio != null &&
                            sheikh.bio!.isNotEmpty) ...[
                          _SectionHeader(title: 'About'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Text(
                              sheikh.bio!,
                              style: KhairTypography.bodyMedium.copyWith(
                                color:
                                    Colors.white.withValues(alpha: 0.75),
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Ijazah / Credentials
                        if (sheikh.ijazahInfo != null &&
                            sheikh.ijazahInfo!.isNotEmpty) ...[
                          _SectionHeader(title: 'Ijazah & Credentials'),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Text(
                              sheikh.ijazahInfo!,
                              style: KhairTypography.bodyMedium.copyWith(
                                color:
                                    Colors.white.withValues(alpha: 0.75),
                                height: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Certifications
                        if (sheikh.certifications.isNotEmpty) ...[
                          _SectionHeader(title: 'Certifications'),
                          const SizedBox(height: 8),
                          ...sheikh.certifications.map(
                            (cert) => Padding(
                              padding:
                                  const EdgeInsets.only(bottom: 8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.05),
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.08)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.workspace_premium_rounded,
                                        color: const Color(0xFFD4A84B),
                                        size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        cert,
                                        style: KhairTypography.bodySmall
                                            .copyWith(
                                          color: Colors.white
                                              .withValues(alpha: 0.8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Contact / Email
                        _SectionHeader(title: 'Contact'),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.email_outlined,
                                  color: Colors.white
                                      .withValues(alpha: 0.5),
                                  size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  sheikh.email,
                                  style:
                                      KhairTypography.bodyMedium.copyWith(
                                    color: Colors.white
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  void _shareSheikh(BuildContext context) {
    final shareText = StringBuffer();
    shareText.writeln('🕌 Sheikh ${sheikh.name}');
    if (sheikh.specialization != null && sheikh.specialization!.isNotEmpty) {
      shareText.writeln('📚 ${sheikh.specialization}');
    }
    final location = [sheikh.city, sheikh.country]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');
    if (location.isNotEmpty) shareText.writeln('📍 $location');
    if (sheikh.yearsOfExperience != null) {
      shareText.writeln('⭐ ${sheikh.yearsOfExperience} years experience');
    }
    if (sheikh.isVerified) shareText.writeln('✅ Verified Sheikh');
    shareText.writeln();
    shareText.write('Discover on Khair: https://khair.it.com/api/v1/sheikhs/${sheikh.id}');

    ShareHelper.share(context, shareText.toString());
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        sheikh.name[0].toUpperCase(),
        style: const TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16, color: Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(label,
                  style: KhairTypography.labelSmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: KhairTypography.bodySmall.copyWith(
              color: valueColor ?? Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Text(
        title,
        style: KhairTypography.labelLarge.copyWith(
          color: Colors.white.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SubtlePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    const spacing = 70.0;
    final cols = (size.width / spacing).ceil() + 1;
    final rows = (size.height / spacing).ceil() + 1;

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final cx = col * spacing + (row.isOdd ? spacing / 2 : 0);
        final cy = row * spacing;
        final path = Path();
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4) - math.pi / 8;
          final x = cx + 14 * math.cos(angle);
          final y = cy + 14 * math.sin(angle);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
