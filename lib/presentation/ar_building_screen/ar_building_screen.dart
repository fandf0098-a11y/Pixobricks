import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../theme/app_theme.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

enum PlacementStatus { correct, rotate, incorrect, pending }

enum VoiceCommand { next, back, pause, repeat, showAnimation, unknown }

class BrickStep {
  final int stepNumber;
  final String brickType;
  final String brickColor;
  final String instruction;
  final Color displayColor;
  final String position; // e.g. "Top-Left", "Center", "Right"

  const BrickStep({
    required this.stepNumber,
    required this.brickType,
    required this.brickColor,
    required this.instruction,
    required this.displayColor,
    required this.position,
  });
}

// ─── Static Build Data ────────────────────────────────────────────────────────

const List<BrickStep> _buildSteps = [
  BrickStep(
    stepNumber: 1,
    brickType: '2×4 Plate',
    brickColor: 'Red',
    instruction: 'Place the red 2×4 plate as the base foundation',
    displayColor: Color(0xFFE74C3C),
    position: 'Center-Bottom',
  ),
  BrickStep(
    stepNumber: 2,
    brickType: '2×2 Brick',
    brickColor: 'Blue',
    instruction: 'Stack the blue 2×2 brick on the left side of the base',
    displayColor: Color(0xFF3498DB),
    position: 'Left',
  ),
  BrickStep(
    stepNumber: 3,
    brickType: '1×4 Brick',
    brickColor: 'Yellow',
    instruction: 'Attach the yellow 1×4 brick horizontally across the top',
    displayColor: Color(0xFFF1C40F),
    position: 'Top-Center',
  ),
  BrickStep(
    stepNumber: 4,
    brickType: '2×2 Slope',
    brickColor: 'White',
    instruction: 'Place the white 2×2 slope piece for the roof angle',
    displayColor: Color(0xFFECF0F1),
    position: 'Top-Right',
  ),
  BrickStep(
    stepNumber: 5,
    brickType: '1×2 Tile',
    brickColor: 'Green',
    instruction: 'Snap the green 1×2 tile onto the right wall section',
    displayColor: Color(0xFF2ECC71),
    position: 'Right',
  ),
  BrickStep(
    stepNumber: 6,
    brickType: '2×4 Brick',
    brickColor: 'Orange',
    instruction: 'Place the orange 2×4 brick to form the second floor',
    displayColor: Color(0xFFE67E22),
    position: 'Center',
  ),
  BrickStep(
    stepNumber: 7,
    brickType: '1×1 Round',
    brickColor: 'Purple',
    instruction: 'Add the purple 1×1 round stud as a chimney detail',
    displayColor: Color(0xFF9B59B6),
    position: 'Top-Left',
  ),
  BrickStep(
    stepNumber: 8,
    brickType: '2×6 Plate',
    brickColor: 'Dark Grey',
    instruction: 'Lay the dark grey 2×6 plate as the roof base',
    displayColor: Color(0xFF7F8C8D),
    position: 'Top',
  ),
  BrickStep(
    stepNumber: 9,
    brickType: '1×3 Brick',
    brickColor: 'Tan',
    instruction: 'Place the tan 1×3 brick for the window frame',
    displayColor: Color(0xFFD4A574),
    position: 'Center-Left',
  ),
  BrickStep(
    stepNumber: 10,
    brickType: '2×2 Corner',
    brickColor: 'Red',
    instruction:
        'Finish with the red 2×2 corner piece to complete the structure',
    displayColor: Color(0xFFE74C3C),
    position: 'Corner',
  ),
];

// ─── Main Screen ──────────────────────────────────────────────────────────────

class ArBuildingScreen extends StatefulWidget {
  const ArBuildingScreen({super.key});

  @override
  State<ArBuildingScreen> createState() => _ArBuildingScreenState();
}

class _ArBuildingScreenState extends State<ArBuildingScreen>
    with TickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraInitialized = false;
  bool _cameraPermissionDenied = false;

  // AR State
  int _currentStep = 0;
  PlacementStatus _placementStatus = PlacementStatus.pending;
  bool _isPaused = false;
  bool _showAnimation = false;
  bool _modelDetected = false;
  Offset _overlayPosition = const Offset(0.5, 0.5); // normalized

  // Sensors
  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double _gyroX = 0, _gyroY = 0;
  double _tiltX = 0, _tiltY = 0;

  // Voice
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _lastWords = '';

  // Animations
  late AnimationController _pulseController;
  late AnimationController _overlayController;
  late AnimationController _statusController;
  late AnimationController _celebrationController;
  late Animation<double> _pulseAnim;
  late Animation<double> _overlayAnim;
  late Animation<double> _statusAnim;
  late Animation<double> _celebrationAnim;

  // Placement simulation timer
  Timer? _placementTimer;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initCamera();
    _initSensors();
    _initSpeech();
    _startPlacementSimulation();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _overlayController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _statusController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _overlayAnim = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _overlayController, curve: Curves.easeInOut),
    );

    _statusAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statusController, curve: Curves.elasticOut),
    );

    _celebrationAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.easeOut),
    );
  }

  Future<void> _initCamera() async {
    if (kIsWeb) {
      setState(() => _cameraInitialized = false);
      return;
    }

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() => _cameraPermissionDenied = true);
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      final back = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      try {
        await _cameraController!.setFocusMode(FocusMode.auto);
      } catch (_) {}

      if (mounted) setState(() => _cameraInitialized = true);
    } catch (e) {
      if (mounted) setState(() => _cameraPermissionDenied = true);
    }
  }

  void _initSensors() {
    try {
      _gyroSub = gyroscopeEventStream().listen((event) {
        if (!mounted) return;
        setState(() {
          _gyroX = event.x;
          _gyroY = event.y;
          // Shift overlay slightly based on gyro for tracking effect
          _overlayPosition = Offset(
            (_overlayPosition.dx + event.y * 0.002).clamp(0.2, 0.8),
            (_overlayPosition.dy + event.x * 0.002).clamp(0.2, 0.8),
          );
        });
      });

      _accelSub = accelerometerEventStream().listen((event) {
        if (!mounted) return;
        setState(() {
          _tiltX = event.x;
          _tiltY = event.y;
        });
      });
    } catch (_) {}
  }

  Future<void> _initSpeech() async {
    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) return;
    }
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (error) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) setState(() {});
    } catch (_) {}
  }

  void _startPlacementSimulation() {
    // Simulate model detection after 2 seconds
    _detectionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _modelDetected = true);
      _simulatePlacementCheck();
    });
  }

  void _simulatePlacementCheck() {
    _placementTimer?.cancel();
    _placementTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _isPaused) return;
      final statuses = [
        PlacementStatus.correct,
        PlacementStatus.rotate,
        PlacementStatus.incorrect,
        PlacementStatus.correct,
        PlacementStatus.correct,
      ];
      final random = math.Random();
      final newStatus = statuses[random.nextInt(statuses.length)];
      setState(() => _placementStatus = newStatus);
      _statusController.forward(from: 0);
    });
  }

  void _toggleListening() async {
    if (!_speechAvailable) {
      _showVoiceUnavailableSnack();
      return;
    }

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      await _speech.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
      );
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    setState(() => _lastWords = result.recognizedWords);
    if (result.finalResult) {
      _processVoiceCommand(result.recognizedWords.toLowerCase());
    }
  }

  VoiceCommand _parseCommand(String words) {
    if (words.contains('next')) return VoiceCommand.next;
    if (words.contains('back') || words.contains('previous')) {
      return VoiceCommand.back;
    }
    if (words.contains('pause') || words.contains('stop')) {
      return VoiceCommand.pause;
    }
    if (words.contains('repeat') || words.contains('again')) {
      return VoiceCommand.repeat;
    }
    if (words.contains('animation') || words.contains('show')) {
      return VoiceCommand.showAnimation;
    }
    return VoiceCommand.unknown;
  }

  void _processVoiceCommand(String words) {
    final cmd = _parseCommand(words);
    switch (cmd) {
      case VoiceCommand.next:
        _nextStep();
        _showCommandFeedback('▶ Next Step');
        break;
      case VoiceCommand.back:
        _prevStep();
        _showCommandFeedback('◀ Previous Step');
        break;
      case VoiceCommand.pause:
        _togglePause();
        _showCommandFeedback(_isPaused ? '⏸ Paused' : '▶ Resumed');
        break;
      case VoiceCommand.repeat:
        _showCommandFeedback('🔁 Repeating Step ${_currentStep + 1}');
        _statusController.forward(from: 0);
        break;
      case VoiceCommand.showAnimation:
        _triggerAnimation();
        _showCommandFeedback('✨ Showing Animation');
        break;
      case VoiceCommand.unknown:
        _showCommandFeedback('❓ Command not recognised');
        break;
    }
  }

  void _showCommandFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  void _showVoiceUnavailableSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Voice recognition not available on this device',
          style: GoogleFonts.dmSans(color: Colors.white),
        ),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _buildSteps.length - 1) {
      setState(() {
        _currentStep++;
        _placementStatus = PlacementStatus.pending;
        _modelDetected = false;
      });
      _detectionTimer?.cancel();
      _detectionTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _modelDetected = true);
      });
    } else {
      _triggerAnimation();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _placementStatus = PlacementStatus.pending;
      });
    }
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    if (_isPaused) {
      _placementTimer?.cancel();
    } else {
      _simulatePlacementCheck();
    }
  }

  void _triggerAnimation() {
    setState(() => _showAnimation = true);
    _celebrationController.forward(from: 0);
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showAnimation = false);
    });
  }

  double get _progressPercent => (_currentStep + 1) / _buildSteps.length;

  Color get _statusColor {
    switch (_placementStatus) {
      case PlacementStatus.correct:
        return AppTheme.success;
      case PlacementStatus.rotate:
        return AppTheme.warning;
      case PlacementStatus.incorrect:
        return AppTheme.error;
      case PlacementStatus.pending:
        return AppTheme.secondary;
    }
  }

  String get _statusLabel {
    switch (_placementStatus) {
      case PlacementStatus.correct:
        return '✓ Correct Placement';
      case PlacementStatus.rotate:
        return '↻ Rotate Piece';
      case PlacementStatus.incorrect:
        return '✗ Incorrect Placement';
      case PlacementStatus.pending:
        return '◎ Scanning...';
    }
  }

  IconData get _statusIcon {
    switch (_placementStatus) {
      case PlacementStatus.correct:
        return Icons.check_circle_rounded;
      case PlacementStatus.rotate:
        return Icons.rotate_right_rounded;
      case PlacementStatus.incorrect:
        return Icons.cancel_rounded;
      case PlacementStatus.pending:
        return Icons.radar_rounded;
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _gyroSub?.cancel();
    _accelSub?.cancel();
    _placementTimer?.cancel();
    _detectionTimer?.cancel();
    _speech.stop();
    _pulseController.dispose();
    _overlayController.dispose();
    _statusController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera / AR Background ──────────────────────────────────────
          _buildCameraBackground(),

          // ── AR Overlay Canvas ───────────────────────────────────────────
          if (_modelDetected && !_isPaused) _buildArOverlay(),

          // ── Celebration Animation ───────────────────────────────────────
          if (_showAnimation) _buildCelebrationOverlay(),

          // ── Top HUD ─────────────────────────────────────────────────────
          Positioned(top: 0, left: 0, right: 0, child: _buildTopHud()),

          // ── Status Badge ─────────────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            left: 0,
            right: 0,
            child: Center(child: _buildStatusBadge()),
          ),

          // ── Scanning Indicator ────────────────────────────────────────────
          if (!_modelDetected && !_isPaused)
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 0,
              right: 0,
              child: Center(child: _buildScanningIndicator()),
            ),

          // ── Paused Overlay ────────────────────────────────────────────────
          if (_isPaused) _buildPausedOverlay(),

          // ── Bottom Panel ──────────────────────────────────────────────────
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomPanel()),

          // ── Voice Listening Indicator ─────────────────────────────────────
          if (_isListening)
            Positioned(
              bottom: 220,
              left: 0,
              right: 0,
              child: Center(child: _buildVoiceIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraBackground() {
    if (kIsWeb || !_cameraInitialized || _cameraController == null) {
      return _buildArSimulatedBackground();
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 1,
          height: _cameraController!.value.previewSize?.width ?? 1,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildArSimulatedBackground() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                math.sin(_pulseController.value * math.pi) * 0.3,
                math.cos(_pulseController.value * math.pi) * 0.2,
              ),
              radius: 1.5,
              colors: const [
                Color(0xFF0D0B1E),
                Color(0xFF1A0B3E),
                Color(0xFF0B1A3E),
                Color(0xFF050510),
              ],
            ),
          ),
          child: CustomPaint(
            painter: _GridPainter(
              progress: _pulseController.value,
              tiltX: _tiltX,
              tiltY: _tiltY,
            ),
          ),
        );
      },
    );
  }

  Widget _buildArOverlay() {
    final size = MediaQuery.of(context).size;
    final step = _buildSteps[_currentStep];

    return AnimatedBuilder(
      animation: Listenable.merge([_overlayController, _statusController]),
      builder: (context, _) {
        final cx = _overlayPosition.dx * size.width;
        final cy = _overlayPosition.dy * size.height;

        return Stack(
          children: [
            // Tracking grid lines
            CustomPaint(
              size: size,
              painter: _TrackingPainter(
                center: Offset(cx, cy),
                color: _statusColor,
                opacity: _overlayAnim.value,
                gyroX: _gyroX,
                gyroY: _gyroY,
              ),
            ),

            // Brick overlay ghost
            Positioned(
              left: cx - 60,
              top: cy - 40,
              child: Transform.scale(
                scale: _pulseAnim.value,
                child: Transform.rotate(
                  angle: _gyroY * 0.05,
                  child: _buildBrickGhost(step),
                ),
              ),
            ),

            // Corner tracking markers
            ..._buildCornerMarkers(cx, cy, size),

            // Position label
            Positioned(
              left: cx - 60,
              top: cy + 55,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  step.position,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrickGhost(BrickStep step) {
    return Container(
      width: 120,
      height: 80,
      decoration: BoxDecoration(
        color: step.displayColor.withAlpha(80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _statusColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _statusColor.withAlpha(120),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Brick studs
          Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(
                8,
                (i) => Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: step.displayColor.withAlpha(160),
                    border: Border.all(
                      color: _statusColor.withAlpha(180),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Status icon overlay
          Positioned(
            right: 6,
            bottom: 6,
            child: Icon(_statusIcon, color: _statusColor, size: 18),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCornerMarkers(double cx, double cy, Size size) {
    const offset = 70.0;
    const markerSize = 16.0;
    final positions = [
      Offset(cx - offset, cy - offset),
      Offset(cx + offset - markerSize, cy - offset),
      Offset(cx - offset, cy + offset - markerSize),
      Offset(cx + offset - markerSize, cy + offset - markerSize),
    ];

    return positions
        .map(
          (pos) => Positioned(
            left: pos.dx,
            top: pos.dy,
            child: CustomPaint(
              size: const Size(markerSize, markerSize),
              painter: _CornerMarkerPainter(color: _statusColor),
            ),
          ),
        )
        .toList();
  }

  Widget _buildCelebrationOverlay() {
    return AnimatedBuilder(
      animation: _celebrationAnim,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _CelebrationPainter(progress: _celebrationAnim.value),
        );
      },
    );
  }

  Widget _buildTopHud() {
    final step = _buildSteps[_currentStep];
    final topPad = MediaQuery.of(context).padding.top;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, topPad + 8, 16, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(200),
                Colors.black.withAlpha(100),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Back button
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AR Building Assistant',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'Step ${_currentStep + 1} of ${_buildSteps.length} · ${step.brickType}',
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withAlpha(160),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // AR badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.view_in_ar_rounded,
                          color: Colors.white,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          kIsWeb ? 'AR SIM' : 'LIVE AR',
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Progress bar
              _buildProgressBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Build Progress',
              style: GoogleFonts.dmSans(
                color: Colors.white.withAlpha(160),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${(_progressPercent * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progressPercent,
            backgroundColor: Colors.white.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(
              _progressPercent >= 1.0 ? AppTheme.success : AppTheme.primary,
            ),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: List.generate(_buildSteps.length, (i) {
            final isCompleted = i < _currentStep;
            final isCurrent = i == _currentStep;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 3,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppTheme.success
                      : isCurrent
                      ? AppTheme.primary
                      : Colors.white.withAlpha(30),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return AnimatedBuilder(
      animation: _statusAnim,
      builder: (context, _) {
        return Transform.scale(
          scale: 0.8 + (_statusAnim.value * 0.2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _statusColor.withAlpha(220),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: _statusColor.withAlpha(100),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_statusIcon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  _statusLabel,
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanningIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(140),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.secondary.withAlpha(
                (100 + (_pulseController.value * 100)).toInt(),
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.secondary),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Scanning for model...',
                style: GoogleFonts.dmSans(
                  color: AppTheme.secondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPausedOverlay() {
    return Container(
      color: Colors.black.withAlpha(160),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withAlpha(60), width: 2),
              ),
              child: const Icon(
                Icons.pause_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Session Paused',
              style: GoogleFonts.dmSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Say "Resume" or tap ▶ to continue',
              style: GoogleFonts.dmSans(
                color: Colors.white.withAlpha(160),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceIndicator() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primary.withAlpha(220),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withAlpha(
                  (80 + (_pulseController.value * 80)).toInt(),
                ),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(5, (i) {
                final height =
                    8.0 +
                    math.sin(
                          (_pulseController.value * math.pi * 2) + (i * 0.8),
                        ) *
                        12;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 4,
                  height: height.abs() + 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 12),
              Text(
                _lastWords.isEmpty ? 'Listening...' : '"$_lastWords"',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel() {
    final step = _buildSteps[_currentStep];

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withAlpha(230),
                Colors.black.withAlpha(180),
                Colors.transparent,
              ],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Step instruction card
              _buildStepCard(step),
              const SizedBox(height: 14),

              // Control buttons row
              _buildControlRow(),
              const SizedBox(height: 12),

              // Voice commands hint
              _buildVoiceHint(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepCard(BrickStep step) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(26)),
      ),
      child: Row(
        children: [
          // Brick color swatch
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: step.displayColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: step.displayColor.withAlpha(120),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.view_in_ar_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withAlpha(60),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        step.brickType,
                        style: GoogleFonts.dmSans(
                          color: AppTheme.primaryLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: step.displayColor.withAlpha(40),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        step.brickColor,
                        style: GoogleFonts.dmSans(
                          color: step.displayColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.instruction,
                  style: GoogleFonts.dmSans(
                    color: Colors.white.withAlpha(220),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlRow() {
    return Row(
      children: [
        // Previous
        _ControlButton(
          icon: Icons.skip_previous_rounded,
          label: 'Back',
          onTap: _currentStep > 0 ? _prevStep : null,
          color: Colors.white.withAlpha(160),
        ),
        const SizedBox(width: 8),

        // Pause / Resume
        _ControlButton(
          icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: _isPaused ? 'Resume' : 'Pause',
          onTap: _togglePause,
          color: AppTheme.warning,
          isHighlighted: _isPaused,
        ),
        const SizedBox(width: 8),

        // Animation
        _ControlButton(
          icon: Icons.auto_awesome_rounded,
          label: 'Animate',
          onTap: _triggerAnimation,
          color: AppTheme.secondary,
        ),
        const SizedBox(width: 8),

        // Voice
        _ControlButton(
          icon: _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
          label: _isListening ? 'Stop' : 'Voice',
          onTap: _toggleListening,
          color: AppTheme.primary,
          isHighlighted: _isListening,
        ),
        const SizedBox(width: 8),

        // Next
        Expanded(
          child: GestureDetector(
            onTap: _nextStep,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF00D4FF)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withAlpha(80),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _currentStep < _buildSteps.length - 1 ? 'Next' : 'Finish',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic_rounded, color: Colors.white.withAlpha(100), size: 13),
          const SizedBox(width: 6),
          Text(
            'Voice: "Next" · "Back" · "Pause" · "Repeat" · "Show animation"',
            style: GoogleFonts.dmSans(
              color: Colors.white.withAlpha(100),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Control Button Widget ────────────────────────────────────────────────────

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final bool isHighlighted;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isHighlighted
              ? color.withAlpha(60)
              : Colors.white.withAlpha(isDisabled ? 10 : 20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isHighlighted
                ? color.withAlpha(160)
                : Colors.white.withAlpha(isDisabled ? 15 : 40),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isDisabled
                  ? Colors.white.withAlpha(60)
                  : isHighlighted
                  ? color
                  : Colors.white.withAlpha(200),
              size: 18,
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: isDisabled
                    ? Colors.white.withAlpha(60)
                    : isHighlighted
                    ? color
                    : Colors.white.withAlpha(160),
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Painters ──────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  final double progress;
  final double tiltX;
  final double tiltY;

  _GridPainter({
    required this.progress,
    required this.tiltX,
    required this.tiltY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6C63FF).withAlpha(30)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    final offsetX = (tiltX * 5) % spacing;
    final offsetY = (tiltY * 5) % spacing;

    for (double x = offsetX; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = offsetY; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    // Horizon glow
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [const Color(0xFF6C63FF).withAlpha(40), Colors.transparent],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height * 0.6),
              radius: size.width * 0.6,
            ),
          );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.6),
      size.width * 0.6,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.progress != progress || old.tiltX != tiltX || old.tiltY != tiltY;
}

class _TrackingPainter extends CustomPainter {
  final Offset center;
  final Color color;
  final double opacity;
  final double gyroX;
  final double gyroY;

  _TrackingPainter({
    required this.center,
    required this.color,
    required this.opacity,
    required this.gyroX,
    required this.gyroY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha((opacity * 60).toInt())
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Crosshair lines
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );

    // Concentric tracking circles
    for (int i = 1; i <= 3; i++) {
      final circlePaint = Paint()
        ..color = color.withAlpha((opacity * 30 / i).toInt())
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, 80.0 * i, circlePaint);
    }

    // Bounding box
    final boxPaint = Paint()
      ..color = color.withAlpha((opacity * 80).toInt())
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 160, height: 120),
        const Radius.circular(8),
      ),
      boxPaint,
    );
  }

  @override
  bool shouldRepaint(_TrackingPainter old) =>
      old.center != center ||
      old.color != color ||
      old.opacity != opacity ||
      old.gyroX != gyroX ||
      old.gyroY != gyroY;
}

class _CornerMarkerPainter extends CustomPainter {
  final Color color;
  _CornerMarkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const len = 10.0;
    // Top-left corner
    canvas.drawLine(Offset.zero, Offset(len, 0), paint);
    canvas.drawLine(Offset.zero, Offset(0, len), paint);
  }

  @override
  bool shouldRepaint(_CornerMarkerPainter old) => old.color != color;
}

class _CelebrationPainter extends CustomPainter {
  final double progress;
  final math.Random _rng = math.Random(42);

  _CelebrationPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final colors = [
      AppTheme.primary,
      AppTheme.secondary,
      AppTheme.success,
      AppTheme.warning,
      AppTheme.tertiary,
    ];

    for (int i = 0; i < 60; i++) {
      final x = _rng.nextDouble() * size.width;
      final startY = -20.0;
      final endY = size.height + 20;
      final y = startY + (endY - startY) * progress;
      final color = colors[i % colors.length];
      final alpha = ((1.0 - progress) * 255).toInt().clamp(0, 255);

      final paint = Paint()
        ..color = color.withAlpha(alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y + (_rng.nextDouble() * 100 - 50) * progress);
      canvas.rotate(_rng.nextDouble() * math.pi * 2 * progress);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 8 + _rng.nextDouble() * 8,
            height: 4 + _rng.nextDouble() * 4,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter old) => old.progress != progress;
}
