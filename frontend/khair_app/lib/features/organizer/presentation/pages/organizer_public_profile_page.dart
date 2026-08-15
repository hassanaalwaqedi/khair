import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/media_url_helper.dart';
import '../../../../tokens/tokens.dart';
import '../../data/datasources/organizer_remote_datasource.dart';
import '../../domain/entities/organizer.dart';

/// Public organizer profile reached from an event's "Hosted by" section.
/// Only approved organizer data returned by the API is shown.
class OrganizerPublicProfilePage extends StatefulWidget {
  final String organizerId;

  const OrganizerPublicProfilePage({super.key, required this.organizerId});

  @override
  State<OrganizerPublicProfilePage> createState() =>
      _OrganizerPublicProfilePageState();
}

class _OrganizerPublicProfilePageState
    extends State<OrganizerPublicProfilePage> {
  late Future<Organizer> _organizer;

  @override
  void initState() {
    super.initState();
    _organizer =
        getIt<OrganizerRemoteDataSource>().getOrganizerById(widget.organizerId);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? AppColors.darkBackground : AppColors.background;
    final surface = dark ? AppColors.darkSurface : AppColors.surface;
    final primary = dark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondary =
        dark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final border = dark ? AppColors.darkBorder : AppColors.border;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        foregroundColor: primary,
        elevation: 0,
        title: const Text('Organizer profile'),
      ),
      body: FutureBuilder<Organizer>(
        future: _organizer,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return Center(
              child: Text('Organizer profile not found.',
                  style: TextStyle(color: secondary)),
            );
          }
          final organizer = snapshot.data!;
          final logo = resolveMediaUrl(organizer.logoUrl);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    _avatar(organizer, logo),
                    const SizedBox(height: 16),
                    Text(organizer.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: primary,
                            fontSize: 28,
                            fontWeight: FontWeight.w800)),
                    if (organizer.isVerified) ...[
                      const SizedBox(height: 8),
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded,
                              color: AppColors.primary, size: 17),
                          SizedBox(width: 5),
                          Text('Verified organizer',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (organizer.description?.trim().isNotEmpty == true)
                            Text(organizer.description!,
                                style: TextStyle(
                                    color: secondary,
                                    fontSize: 15,
                                    height: 1.65)),
                          if (_location(organizer).isNotEmpty) ...[
                            const SizedBox(height: 20),
                            _info(Icons.location_on_outlined,
                                _location(organizer), secondary),
                          ],
                          if (organizer.website?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 14),
                            _info(Icons.language_outlined, organizer.website!,
                                secondary),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _avatar(Organizer organizer, String logo) {
    if (logo.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: logo,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initial(organizer.name),
        ),
      );
    }
    return _initial(organizer.name);
  }

  Widget _initial(String name) => Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
            color: AppColors.primary, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase(),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800)),
      );

  Widget _info(IconData icon, String text, Color secondary) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
              child:
                  Text(text, style: TextStyle(color: secondary, fontSize: 14))),
        ],
      );

  String _location(Organizer organizer) => [organizer.city, organizer.country]
      .whereType<String>()
      .where((value) => value.trim().isNotEmpty)
      .join(', ');
}
