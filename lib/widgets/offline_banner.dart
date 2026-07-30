import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../core/app_export.dart';

/// OfflineBanner — shows a non-intrusive banner when the device is offline.
/// Automatically hides when connectivity is restored.
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _isOffline = false;
  late AnimationController _animController;
  late Animation<double> _slideAnim;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _checkInitial();
    _sub = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.contains(ConnectivityResult.none);
    if (mounted && offline) {
      setState(() => _isOffline = true);
      _animController.forward();
    }
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final offline = results.contains(ConnectivityResult.none);
    if (offline == _isOffline) return;
    if (mounted) {
      setState(() => _isOffline = offline);
      if (offline) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(_slideAnim),
            child: SafeArea(
              bottom: false,
              child: Container(
                color: AppTheme.warning,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'No internet connection',
                      style: TextStyle(
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
      ],
    );
  }
}
