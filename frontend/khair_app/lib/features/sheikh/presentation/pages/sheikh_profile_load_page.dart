import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/locale/l10n_extension.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/loading_states.dart';
import '../../domain/entities/sheikh_profile.dart';
import 'sheikh_profile_page.dart';

/// Wrapper page that loads a sheikh by ID and shows the profile.
/// Used for deep linking: /sheikhs/:id
class SheikhProfileLoadPage extends StatefulWidget {
  final String sheikhId;
  const SheikhProfileLoadPage({super.key, required this.sheikhId});

  @override
  State<SheikhProfileLoadPage> createState() => _SheikhProfileLoadPageState();
}

class _SheikhProfileLoadPageState extends State<SheikhProfileLoadPage> {
  SheikhProfile? _sheikh;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSheikh();
  }

  Future<void> _loadSheikh() async {
    try {
      final api = getIt<ApiClient>();
      final res = await api.get('/sheikhs/${widget.sheikhId}');
      final data = res.data['data'] ?? res.data;
      if (mounted) {
        setState(() {
          _sheikh = SheikhProfile.fromJson(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Sheikh not found';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: SheikhProfileSkeleton(),
      );
    }

    if (_error != null || _sheikh == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1117),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_off_rounded,
                  size: 40,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                context.l10n.sheikhProfileNotFound,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.sheikhProfileUnavailableMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(context.l10n.browseEvents),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KhairColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SheikhProfilePage(sheikh: _sheikh!);
  }
}
