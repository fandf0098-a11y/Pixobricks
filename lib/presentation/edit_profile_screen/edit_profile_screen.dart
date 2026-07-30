import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../services/supabase_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _bioCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _websiteCtrl;

  String _selectedExpLevel = 'Beginner';
  List<String> _selectedThemes = [];

  static const _expLevels = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert',
    'Master',
  ];

  static const _allThemes = [
    'Star Wars',
    'Technic',
    'City',
    'Architecture',
    'Creator',
    'Ninjago',
    'Harry Potter',
    'Marvel',
    'DC',
    'Speed Champions',
    'Ideas',
    'Minecraft',
    'Nature',
    'Space',
    'Castle',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    _locationCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final profile = await SupabaseService.instance.fetchCreatorProfile(
        userId,
      );
      if (mounted && profile != null) {
        setState(() {
          _nameCtrl.text = profile['full_name'] as String? ?? '';
          _usernameCtrl.text = profile['username'] as String? ?? '';
          _bioCtrl.text = profile['bio'] as String? ?? '';
          _locationCtrl.text = profile['location'] as String? ?? '';
          _websiteCtrl.text = profile['website'] as String? ?? '';
          _selectedExpLevel =
              profile['experience_level'] as String? ?? 'Beginner';
          _selectedThemes =
              (profile['favourite_themes'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load profile. Please try again.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();
    setState(() => _isSaving = true);
    try {
      final userId = SupabaseService.instance.currentUserId;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to save: User ID not found',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }
      await SupabaseService.instance.client.from('user_profiles').upsert({
        'id': userId,
        'full_name': _nameCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
        'bio': _bioCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'experience_level': _selectedExpLevel,
        'favourite_themes': _selectedThemes,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated!',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save profile. Please try again.',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildAppBar(isDark),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _sectionLabel('Basic Info', isDark),
                                const SizedBox(height: 12),
                                _buildField(
                                  controller: _nameCtrl,
                                  label: 'Display Name',
                                  hint: 'Your full name',
                                  icon: Icons.person_rounded,
                                  isDark: isDark,
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                _buildField(
                                  controller: _usernameCtrl,
                                  label: 'Username',
                                  hint: 'your_username',
                                  icon: Icons.alternate_email_rounded,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
                                _buildField(
                                  controller: _bioCtrl,
                                  label: 'Bio',
                                  hint: 'Tell the community about yourself...',
                                  icon: Icons.info_outline_rounded,
                                  isDark: isDark,
                                  maxLines: 3,
                                ),
                                const SizedBox(height: 12),
                                _buildField(
                                  controller: _locationCtrl,
                                  label: 'Location',
                                  hint: 'City, Country',
                                  icon: Icons.location_on_outlined,
                                  isDark: isDark,
                                ),
                                const SizedBox(height: 12),
                                _buildField(
                                  controller: _websiteCtrl,
                                  label: 'Website',
                                  hint: 'https://yoursite.com',
                                  icon: Icons.link_rounded,
                                  isDark: isDark,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return null;
                                    }
                                    final uri = Uri.tryParse(v.trim());
                                    if (uri == null ||
                                        (!uri.scheme.startsWith('http'))) {
                                      return 'Enter a valid URL (https://...)';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                _sectionLabel('Builder Profile', isDark),
                                const SizedBox(height: 12),
                                _buildExpLevelPicker(isDark),
                                const SizedBox(height: 20),
                                _buildThemePicker(isDark),
                                const SizedBox(height: 32),
                                _buildSaveButton(isDark),
                                const SizedBox(height: 40),
                              ],
                            ),
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

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: isDark ? Colors.white : const Color(0xFF1A1840),
              ),
            ),
          ),
          const Spacer(),
          Text(
            'Edit Profile',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1840),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, bool isDark) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppTheme.primary,
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: isDark ? Colors.white : const Color(0xFF1A1840),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        filled: true,
        fillColor: isDark
            ? Colors.white.withAlpha(12)
            : Colors.white.withAlpha(200),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(30)
                : AppTheme.primary.withAlpha(40),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(30)
                : AppTheme.primary.withAlpha(40),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildExpLevelPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Experience Level',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withAlpha(160)
                : const Color(0xFF4A4870),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _expLevels.map((level) {
            final isSelected = _selectedExpLevel == level;
            return GestureDetector(
              onTap: () => setState(() => _selectedExpLevel = level),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected ? AppTheme.primaryGradient : null,
                  color: isSelected
                      ? null
                      : (isDark
                            ? Colors.white.withAlpha(12)
                            : Colors.white.withAlpha(180)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark
                              ? Colors.white.withAlpha(30)
                              : AppTheme.primary.withAlpha(40)),
                  ),
                ),
                child: Text(
                  level,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? Colors.white.withAlpha(180)
                              : const Color(0xFF4A4870)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThemePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Favourite Themes',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark
                ? Colors.white.withAlpha(160)
                : const Color(0xFF4A4870),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select up to 6 themes',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: isDark
                ? Colors.white.withAlpha(100)
                : const Color(0xFF4A4870).withAlpha(160),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allThemes.map((theme) {
            final isSelected = _selectedThemes.contains(theme);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedThemes.remove(theme);
                  } else if (_selectedThemes.length < 6) {
                    _selectedThemes.add(theme);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withAlpha(40)
                      : (isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.white.withAlpha(180)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.primary.withAlpha(120)
                        : (isDark
                              ? Colors.white.withAlpha(25)
                              : AppTheme.primary.withAlpha(30)),
                  ),
                ),
                child: Text(
                  theme,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? AppTheme.primary
                        : (isDark
                              ? Colors.white.withAlpha(160)
                              : const Color(0xFF4A4870)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSaveButton(bool isDark) {
    return GestureDetector(
      onTap: _isSaving ? null : _save,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withAlpha(80),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Save Changes',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
