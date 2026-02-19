import 'dart:async';
import 'package:flutter/material.dart';
import '../network/connectivity_service.dart';

/// A widget that wraps the app content and shows an offline banner
/// when the device loses network connectivity.
class OfflineIndicator extends StatefulWidget {
  final Widget child;

  const OfflineIndicator({super.key, required this.child});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with SingleTickerProviderStateMixin {
  late bool _isOnline;
  StreamSubscription<bool>? _subscription;
  late AnimationController _animController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    final connectivity = ConnectivityService.instance;
    _isOnline = connectivity.isOnline;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    if (!_isOnline) {
      _animController.value = 1.0;
    }

    _subscription = connectivity.onConnectivityChanged.listen((online) {
      setState(() => _isOnline = online);
      if (online) {
        // Show "back online" briefly then hide
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _animController.reverse();
        });
      } else {
        _animController.forward();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            if (_slideAnimation.value < -0.99) {
              return const SizedBox.shrink();
            }
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: (_slideAnimation.value + 1.0).clamp(0.0, 1.0),
                child: child,
              ),
            );
          },
          child: Material(
            color: _isOnline ? Colors.green[600] : Colors.red[700],
            child: SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isOnline ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline
                          ? 'Back online'
                          : 'No internet connection',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: widget.child),
      ],
    );
  }
}
