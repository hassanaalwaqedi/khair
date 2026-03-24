import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../core/utils/share_helper.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/sheikh_profile.dart';

/// Preply-inspired Sheikh Profile Page — modern, dark, blue accents.
/// All data is fetched from the backend via the [SheikhProfile] entity.
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
    final location = [sheikh.city, sheikh.country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Stack(
        children: [
          // Subtle gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF111827),
                  Color(0xFF0B0F14),
                ],
              ),
            ),
          ),
          // Blue glow behind avatar area
          Positioned(
            top: -60,
            left: 0,
            right: 0,
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.2,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── HERO: Avatar + Name + Badges ──
                        _buildHeroSection(context, avatarUrl, location),
                        const SizedBox(height: 24),
                        // ── STATS ROW ──
                        _buildStatsRow(context, location),
                        const SizedBox(height: 24),
                        // ── CTA BUTTONS ──
                        _buildCTAButtons(context),
                        const SizedBox(height: 28),
                        // ── ABOUT ──
                        if (sheikh.bio != null && sheikh.bio!.isNotEmpty) ...[
                          _buildSectionTitle(context.l10n.sheikhAboutMe),
                          const SizedBox(height: 10),
                          _buildAboutCard(),
                          const SizedBox(height: 24),
                        ],
                        // ── SPECIALIZATION & CREDENTIALS ──
                        if (_hasCredentials()) ...[
                          _buildSectionTitle(context.l10n.sheikhQualifications),
                          const SizedBox(height: 10),
                          _buildCredentialsCard(context),
                          const SizedBox(height: 24),
                        ],
                        // ── REVIEWS ──
                        _buildSectionTitle(context.l10n.sheikhStudentReviews),
                        const SizedBox(height: 10),
                        _ReviewsSection(
                          sheikhId: sheikh.id,
                          averageRating: sheikh.averageRating,
                          totalReviews: sheikh.totalReviews,
                        ),
                        const SizedBox(height: 32),
                        // ── REPORT ──
                        _buildReportButton(context),
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

  // ═══════════════════════════════════
  //  APP BAR
  // ═══════════════════════════════════
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 18),
            ),
            onPressed: () => context.pop(),
          ),
          const Spacer(),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.share_outlined,
                  color: Colors.white, size: 18),
            ),
            onPressed: () => _shareSheikh(context),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════
  //  HERO SECTION (Avatar, Name, Badges)
  // ═══════════════════════════════════
  Widget _buildHeroSection(
      BuildContext context, String avatarUrl, String location) {
    return Center(
      child: Column(
        children: [
          // Avatar with online indicator
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.3),
                      AppColors.primary.withValues(alpha: 0.1),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: avatarUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          width: 110,
                          height: 110,
                          errorBuilder: (_, __, ___) => _buildInitials(),
                        ),
                      )
                    : _buildInitials(),
              ),
              // Verified badge
              if (sheikh.isVerified)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0F14),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0B0F14), width: 2),
                    ),
                    child: Icon(Icons.verified_rounded,
                        size: 20, color: AppColors.primary),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Name
          Text(
            sheikh.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Specialization badge
          if (sheikh.specialization != null &&
              sheikh.specialization!.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Text(
                sheikh.specialization!,
                style: TextStyle(
                  color: AppColors.primaryLight,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          // Rating + New badge row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (sheikh.totalReviews > 0) ...[
                const Icon(Icons.star_rounded,
                    size: 20, color: Color(0xFFFFC107)),
                const SizedBox(width: 4),
                Text(
                  sheikh.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                    '(${context.l10n.sheikhReviewsCount(sheikh.totalReviews)})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
              if (sheikh.isNew) ...[
                if (sheikh.totalReviews > 0) const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color:
                            const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '🆕 ${context.l10n.sheikhNew}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF34D399),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════
  //  STATS ROW (Location, Experience, Verification)
  // ═══════════════════════════════════
  Widget _buildStatsRow(BuildContext context, String location) {
    final stats = <_StatItem>[];

    if (location.isNotEmpty) {
      stats.add(_StatItem(
        icon: Icons.location_on_outlined,
        label: context.l10n.sheikhLocation,
        value: location,
      ));
    }
    if (sheikh.yearsOfExperience != null) {
      stats.add(_StatItem(
        icon: Icons.workspace_premium_outlined,
        label: context.l10n.sheikhExperience,
        value: context.l10n.sheikhYearsExperience(sheikh.yearsOfExperience!),
      ));
    }
    stats.add(_StatItem(
      icon: sheikh.isVerified
          ? Icons.verified_outlined
          : Icons.pending_outlined,
      label: context.l10n.sheikhStatus,
      value: sheikh.isVerified ? context.l10n.sheikhVerified : context.l10n.sheikhPending,
      valueColor:
          sheikh.isVerified ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
    ));

    if (stats.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: stats
            .expand((stat) => [
                  Expanded(
                    child: Column(
                      children: [
                        Icon(stat.icon,
                            size: 20,
                            color: stat.valueColor ??
                                Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(height: 6),
                        Text(
                          stat.value,
                          style: TextStyle(
                            color: stat.valueColor ?? Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stat.label,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (stat != stats.last)
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                ])
            .toList(),
      ),
    );
  }

  // ═══════════════════════════════════
  //  CTA BUTTONS
  // ═══════════════════════════════════
  Widget _buildCTAButtons(BuildContext context) {
    return Column(
      children: [
        // Primary: Request Lesson
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => _showRequestLessonModal(context),
            icon: const Icon(Icons.school_rounded, size: 20),
            label: Text(
              context.l10n.sheikhRequestLesson,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Secondary: Contact
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _showContactInfo(context),
            icon: Icon(Icons.mail_outline_rounded,
                size: 18, color: AppColors.primaryLight),
            label: Text(
              context.l10n.sheikhContact,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                  fontSize: 14),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  void _showContactInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).padding.bottom + 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1F2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(context.l10n.sheikhContactInfo,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _ContactRow(
                icon: Icons.email_outlined, label: context.l10n.email, value: sheikh.email),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════
  //  ABOUT CARD
  // ═══════════════════════════════════
  Widget _buildAboutCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        sheikh.bio!,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.75),
          fontSize: 14,
          height: 1.7,
        ),
      ),
    );
  }

  // ═══════════════════════════════════
  //  CREDENTIALS CARD
  // ═══════════════════════════════════
  bool _hasCredentials() {
    return (sheikh.ijazahInfo != null && sheikh.ijazahInfo!.isNotEmpty) ||
        sheikh.certifications.isNotEmpty;
  }

  Widget _buildCredentialsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ijazah
          if (sheikh.ijazahInfo != null && sheikh.ijazahInfo!.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.sheikhIjazahCredentials,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sheikh.ijazahInfo!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (sheikh.certifications.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(
                    color: Colors.white.withValues(alpha: 0.06), height: 1),
              ),
          ],
          // Certifications
          if (sheikh.certifications.isNotEmpty)
            ...sheikh.certifications.map((cert) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC107).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.workspace_premium_rounded,
                            color: Color(0xFFFFC107), size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          cert,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  // ═══════════════════════════════════
  //  SECTION TITLE
  // ═══════════════════════════════════
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }

  // ═══════════════════════════════════
  //  REPORT BUTTON
  // ═══════════════════════════════════
  Widget _buildReportButton(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: () => _showReportModal(context),
        icon: Icon(Icons.flag_outlined,
            size: 16, color: Colors.white.withValues(alpha: 0.3)),
        label: Text(
          context.l10n.sheikhReportProfile,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════
  //  MODALS (Report, Request Lesson)
  // ═══════════════════════════════════
  void _showReportModal(BuildContext context) {
    final reasonController = TextEditingController();
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F2E),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(context.l10n.sheikhReportTitle,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                      context.l10n.sheikhReportDesc,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: context.l10n.sheikhReportHint,
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (reasonController.text.trim().isEmpty) return;
                              setModalState(() => isLoading = true);
                              try {
                                final api = getIt<ApiClient>();
                                await api.post(
                                    '/sheikhs/${sheikh.id}/report',
                                    data: {
                                      'reason': reasonController.text.trim()
                                    });
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text(
                                            context.l10n.sheikhReportSubmitted)),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isLoading = false);
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE53935),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text(context.l10n.sheikhSubmitReport,
                              style:
                                  TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showRequestLessonModal(BuildContext context) {
    final msgController = TextEditingController();
    DateTime? selectedTime;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1F2E),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(context.l10n.sheikhRequestLesson,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                      context.l10n.sheikhSendLessonRequest(sheikh.name),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 13)),
                  const SizedBox(height: 20),
                  // Message field
                  TextField(
                    controller: msgController,
                    maxLines: 3,
                    maxLength: 500,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: context.l10n.sheikhWhatToLearn,
                      labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5)),
                      hintText: context.l10n.sheikhWhatToLearnHint,
                      hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      counterStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3)),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Preferred time
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate:
                            DateTime.now().add(const Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate:
                            DateTime.now().add(const Duration(days: 90)),
                      );
                      if (date != null && ctx.mounted) {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          setModalState(() {
                            selectedTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                            color:
                                Colors.white.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedTime != null
                                  ? DateFormat('EEE, MMM d • h:mm a')
                                      .format(selectedTime!)
                                  : context.l10n.sheikhPreferredTime,
                              style: TextStyle(
                                color: selectedTime != null
                                    ? Colors.white
                                    : Colors.white
                                        .withValues(alpha: 0.35),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final msg = msgController.text.trim();
                              if (msg.isEmpty) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Please enter a message')),
                                );
                                return;
                              }
                              setModalState(() => isLoading = true);
                              try {
                                final api = getIt<ApiClient>();
                                await api
                                    .post('/lesson-requests', data: {
                                  'sheikh_id': sheikh.id,
                                  'message': msg,
                                  if (selectedTime != null)
                                    'preferred_time': selectedTime!
                                        .toUtc()
                                        .toIso8601String(),
                                });
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          context.l10n.sheikhRequestSent),
                                      backgroundColor: KhairColors.success,
                                    ),
                                  );
                                }
                              } on DioException catch (e) {
                                setModalState(() => isLoading = false);
                                final errMsg = e.response?.data?['message'] ??
                                    'Failed to send request';
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                        content:
                                            Text(errMsg.toString())),
                                  );
                                }
                              } catch (e) {
                                setModalState(() => isLoading = false);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(context.l10n.sheikhSendRequest,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
      shareText
          .writeln('⭐ ${sheikh.yearsOfExperience} years experience');
    }
    if (sheikh.isVerified) shareText.writeln('✅ Verified Sheikh');
    shareText.writeln();
    shareText.write(
        'Discover on Khair: https://khair.it.com/api/v1/sheikhs/${sheikh.id}');
    ShareHelper.share(context, shareText.toString());
  }

  Widget _buildInitials() {
    return Center(
      child: Text(
        sheikh.name.isNotEmpty ? sheikh.name[0].toUpperCase() : '?',
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════
//  STAT ITEM (data class)
// ═══════════════════════════════════
class _StatItem {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
}

// ═══════════════════════════════════
//  CONTACT ROW
// ═══════════════════════════════════
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _ContactRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 11)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════
//  REVIEWS SECTION (live from API)
// ═══════════════════════════════════
class _ReviewsSection extends StatefulWidget {
  final String sheikhId;
  final double averageRating;
  final int totalReviews;
  const _ReviewsSection({
    required this.sheikhId,
    required this.averageRating,
    required this.totalReviews,
  });

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  List<dynamic>? _reviews;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final api = getIt<ApiClient>();
      final res =
          await api.get('/sheikhs/${widget.sheikhId}/reviews');
      if (mounted) {
        setState(() {
          _reviews = (res.data['data'] as List?) ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rating summary bar
    final summaryBar = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          // Big rating number
          Column(
            children: [
              Text(
                widget.averageRating > 0
                    ? widget.averageRating.toStringAsFixed(1)
                    : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < widget.averageRating.round()
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 16,
                    color: const Color(0xFFFFC107),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.sheikhReviewsCount(widget.totalReviews),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Vertical divider
          Container(
            width: 1,
            height: 60,
            color: Colors.white.withValues(alpha: 0.06),
          ),
          const SizedBox(width: 24),
          // Trust indicators
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TrustRow(
                    emoji: '📚',
                    text: widget.totalReviews > 0
                        ? context.l10n.sheikhVerified
                        : context.l10n.sheikhNewScholar),
                const SizedBox(height: 8),
                _TrustRow(
                    emoji: '⏰',
                    text: widget.totalReviews > 5
                        ? context.l10n.sheikhVerified
                        : context.l10n.sheikhBuildingReputation),
              ],
            ),
          ),
        ],
      ),
    );

    if (_loading) {
      return Column(
        children: [
          summaryBar,
          const SizedBox(height: 16),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            ),
          ),
        ],
      );
    }

    if (_reviews == null || _reviews!.isEmpty) {
      return Column(
        children: [
          summaryBar,
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Icon(Icons.rate_review_outlined,
                    size: 32, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 8),
                Text(context.l10n.sheikhNoReviewsYet,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(context.l10n.sheikhNoReviewsYet,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        summaryBar,
        const SizedBox(height: 16),
        ..._reviews!.map<Widget>((r) {
          final rating = (r['rating'] as num?)?.toInt() ?? 5;
          final name = r['student_name'] as String? ?? 'Student';
          final comment = r['comment'] as String? ?? '';
          final date =
              DateTime.tryParse(r['created_at'] as String? ?? '');

          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14)),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              ...List.generate(
                                  5,
                                  (i) => Icon(
                                        i < rating
                                            ? Icons.star_rounded
                                            : Icons.star_outline_rounded,
                                        size: 14,
                                        color: const Color(0xFFFFC107),
                                      )),
                              if (date != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('MMM d, y').format(date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (comment.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    comment,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _TrustRow extends StatelessWidget {
  final String emoji;
  final String text;
  const _TrustRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
