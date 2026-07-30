import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';
import 'package:go_router/go_router.dart';

class UploadCreationScreen extends StatefulWidget {
  const UploadCreationScreen({super.key});

  @override
  State<UploadCreationScreen> createState() => _UploadCreationScreenState();
}

class _UploadCreationScreenState extends State<UploadCreationScreen> {
  String _selectedType = 'Project';
  final List<String> _types = ['Project', 'Image', 'Video', 'Instructions'];

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _uploadComplete = false;
  String? _error;

  static const Map<String, String> _typeToPostType = {
    'Project': 'project',
    'Image': 'image',
    'Video': 'video',
    'Instructions': 'instructions',
  };

  final List<Map<String, dynamic>> _typeConfig = [
    {
      'type': 'Project',
      'icon': Icons.view_in_ar_rounded,
      'color': 0xFF6C63FF,
      'description': 'Share your complete LEGO build with parts list',
      'hint': 'e.g. Millennium Falcon — 7,541 pieces',
    },
    {
      'type': 'Image',
      'icon': Icons.image_rounded,
      'color': 0xFF2ECC71,
      'description': 'Upload photos of your creation',
      'hint': 'e.g. Neon City Skyline — Micro Build',
    },
    {
      'type': 'Video',
      'icon': Icons.videocam_rounded,
      'color': 0xFFFF6B9D,
      'description': 'Share a time-lapse or build video',
      'hint': 'e.g. Speed Build: Eiffel Tower in 60 seconds',
    },
    {
      'type': 'Instructions',
      'icon': Icons.menu_book_rounded,
      'color': 0xFF00D4FF,
      'description': 'Create step-by-step build instructions',
      'hint': 'e.g. Modular Treehouse — Build Guide',
    },
  ];

  Map<String, dynamic> get _currentConfig =>
      _typeConfig.firstWhere((c) => c['type'] == _selectedType);

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _handleUpload() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please add a title for your creation',
            style: GoogleFonts.plusJakartaSans(fontSize: 13),
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
    });

    try {
      // Simulate upload progress while saving to Supabase
      for (int i = 1; i <= 8; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) setState(() => _uploadProgress = i / 10);
      }

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      await SupabaseService.instance.createPost({
        'post_type': _typeToPostType[_selectedType] ?? 'project',
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'image_url': '',
        'image_label': _titleController.text.trim(),
        'tags': tags,
      });

      if (mounted) setState(() => _uploadProgress = 1.0);
      await Future.delayed(const Duration(milliseconds: 200));

      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadComplete = true;
        });
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _error = 'Failed to share creation. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = _currentConfig;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? AppTheme.backgroundGradientDark
                  : AppTheme.backgroundGradientLight,
            ),
          ),
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Color(config['color'] as int).withAlpha(51),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(20)
                                : Colors.white.withAlpha(180),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1840),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: Text(
                          'Share Creation',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'What are you sharing?',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1840),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: _types.map((type) {
                            final cfg = _typeConfig.firstWhere(
                              (c) => c['type'] == type,
                            );
                            final isActive = type == _selectedType;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedType = type),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.only(right: 6),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Color(
                                            cfg['color'] as int,
                                          ).withAlpha(46)
                                        : (isDark
                                              ? Colors.white.withAlpha(10)
                                              : Colors.white.withAlpha(160)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isActive
                                          ? Color(
                                              cfg['color'] as int,
                                            ).withAlpha(128)
                                          : (isDark
                                                ? Colors.white.withAlpha(20)
                                                : AppTheme.primary.withAlpha(
                                                    30,
                                                  )),
                                      width: isActive ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        cfg['icon'] as IconData,
                                        size: 20,
                                        color: isActive
                                            ? Color(cfg['color'] as int)
                                            : (isDark
                                                  ? Colors.white.withAlpha(128)
                                                  : const Color(0xFF4A4870)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        type,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 10,
                                          fontWeight: isActive
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isActive
                                              ? Color(cfg['color'] as int)
                                              : (isDark
                                                    ? Colors.white.withAlpha(
                                                        128,
                                                      )
                                                    : const Color(0xFF4A4870)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // Title field
                        _buildLabel('Title', isDark),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _titleController,
                          hint: config['hint'] as String,
                          isDark: isDark,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 16),

                        // Description field
                        _buildLabel('Description', isDark),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _descController,
                          hint: 'Tell the community about your creation...',
                          isDark: isDark,
                          maxLines: 4,
                        ),
                        const SizedBox(height: 16),

                        // Tags field
                        _buildLabel('Tags (comma separated)', isDark),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _tagsController,
                          hint: 'e.g. Star Wars, Advanced, Lighting',
                          isDark: isDark,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 24),

                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              _error!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppTheme.error,
                              ),
                            ),
                          ),

                        // Upload button
                        if (_isUploading)
                          _buildProgressBar(isDark, config)
                        else if (_uploadComplete)
                          _buildSuccessState(isDark)
                        else
                          _buildUploadButton(isDark, config),
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

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white.withAlpha(180) : const Color(0xFF4A4870),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required int maxLines,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withAlpha(13)
            : Colors.white.withAlpha(200),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(20)
              : AppTheme.primary.withAlpha(35),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: isDark ? Colors.white : const Color(0xFF1A1840),
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark
                ? Colors.white.withAlpha(80)
                : const Color(0xFF4A4870).withAlpha(120),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _buildProgressBar(bool isDark, Map<String, dynamic> config) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: isDark
                ? Colors.white.withAlpha(20)
                : AppTheme.primary.withAlpha(30),
            valueColor: AlwaysStoppedAnimation<Color>(
              Color(config['color'] as int),
            ),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Sharing... ${(_uploadProgress * 100).toInt()}%',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: isDark
                ? Colors.white.withAlpha(180)
                : const Color(0xFF4A4870),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: Color(0xFF2ECC71),
          size: 22,
        ),
        const SizedBox(width: 8),
        Text(
          'Shared successfully!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF2ECC71),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton(bool isDark, Map<String, dynamic> config) {
    return GestureDetector(
      onTap: _handleUpload,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(config['color'] as int),
              Color(config['color'] as int).withAlpha(200),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Color(config['color'] as int).withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(config['icon'] as IconData, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              'Share $_selectedType',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
