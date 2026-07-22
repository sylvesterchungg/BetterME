import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../providers/app_provider.dart';
import '../theme.dart';

/// Full-screen editor for the user's core profile details — avatar, username,
/// birth date, phone, and (for email accounts) password. Replaces the old
/// one-field dialogs with a single "Personal Info" page reached from Settings.
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
    );
  }

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _usernameController;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  final _currentPasswordController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  DateTime? _birthDate;
  bool _saving = false;
  bool _uploading = false;
  bool _obscureCurrent = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  bool get _isEmailUser =>
      auth.FirebaseAuth.instance.currentUser?.providerData
          .any((p) => p.providerId == 'password') ??
      false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    // Username lives on the world-readable `users` doc; birth date + phone live
    // on the owner-only `privateProfile` doc (see PrivateProfile / firestore.rules).
    _usernameController =
        TextEditingController(text: provider.currentUser?.username ?? '');
    _nameController =
        TextEditingController(text: provider.currentUser?.name ?? '');
    _phoneController =
        TextEditingController(text: provider.privateProfile.phoneNumber);
    _birthDate = provider.privateProfile.birthDate;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickAvatar(AppProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (img == null) return;
    setState(() => _uploading = true);
    try {
      await provider.uploadProfilePhoto(File(img.path));
      messenger.showSnackBar(const SnackBar(content: Text('Photo updated')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed to upload: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birth date',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _save(AppProvider provider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final newPass = _passwordController.text;
    setState(() => _saving = true);
    try {
      // Password change goes first: it requires re-authentication with the
      // current password, so a wrong old password stops the save before any
      // other field is touched.
      if (_isEmailUser && newPass.isNotEmpty) {
        await provider.reauthenticateWithPassword(_currentPasswordController.text);
        await provider.updatePassword(newPass);
        _currentPasswordController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
      }
      await provider.updateName(_nameController.text.trim());
      await provider.updateUsername(_usernameController.text.trim());
      await provider.updateProfileDetails(
        birthDate: _birthDate,
        phoneNumber: _phoneController.text.trim(),
      );
      messenger.showSnackBar(const SnackBar(content: Text('Profile updated')));
      navigator.pop();
    } on auth.FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password' ||
        'invalid-credential' =>
          'Your current password is incorrect.',
        'requires-recent-login' =>
          'For security, log out and back in, then try again.',
        _ => e.message ?? 'Could not update password.',
      };
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save: ${e.toString().split(']').last.trim()}')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Validators ───────────────────────────────────────────────────────────

  String? _validateName(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Please enter your name';
    return null;
  }

  String? _validateUsername(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Please choose a username';
    if (value.length < 3) return 'At least 3 characters';
    return null;
  }

  // Required only when a new password has been entered.
  String? _validateCurrentPassword(String? v) {
    if (_passwordController.text.isEmpty) return null;
    if ((v ?? '').isEmpty) return 'Enter your current password';
    return null;
  }

  String? _validatePhone(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null; // optional
    if (!RegExp(r'^\+?[\d\s-]{7,15}$').hasMatch(value)) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  String? _validateNewPassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return null; // optional — only changes when filled
    if (value.length < 6) return 'At least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (_passwordController.text.isEmpty) return null;
    if ((v ?? '') != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final user = provider.currentUser;

    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLow,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Personal Info',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.borderDefault),
        ),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: _buildAvatar(user.avatarUrl, provider)),
                    const SizedBox(height: 28),
                    _buildLabel('Full Name'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _nameController,
                      icon: Icons.badge_outlined,
                      hint: 'Your real name',
                      validator: _validateName,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Username'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _usernameController,
                      icon: Icons.alternate_email,
                      hint: 'Your username',
                      validator: _validateUsername,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Birth Date'),
                    const SizedBox(height: 8),
                    _buildDateField(),
                    const SizedBox(height: 20),
                    _buildLabel('Phone (optional)'),
                    const SizedBox(height: 8),
                    _buildTextField(
                      controller: _phoneController,
                      icon: Icons.phone,
                      hint: '+1 555 123 4567',
                      keyboardType: TextInputType.phone,
                      validator: _validatePhone,
                    ),
                    if (_isEmailUser) ...[
                      const SizedBox(height: 28),
                      const Divider(height: 1, color: AppTheme.borderDefault),
                      const SizedBox(height: 20),
                      const Text('Change Password',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      const Text(
                        'Leave blank to keep your current password.',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Current Password'),
                      const SizedBox(height: 8),
                      _buildPasswordField(
                        controller: _currentPasswordController,
                        obscure: _obscureCurrent,
                        onToggle: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                        validator: _validateCurrentPassword,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('New Password'),
                      const SizedBox(height: 8),
                      _buildPasswordField(
                        controller: _passwordController,
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 16),
                      _buildLabel('Confirm New Password'),
                      const SizedBox(height: 8),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        obscure: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: _validateConfirm,
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _saving ? null : () => _save(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryContainer,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          elevation: 1,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar(String avatarUrl, AppProvider provider) {
    return GestureDetector(
      onTap: _uploading ? null : () => _pickAvatar(provider),
      child: Stack(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceContainerHigh,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
              image: avatarUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: avatarUrl.isEmpty
                ? Text(
                    _usernameController.text.isNotEmpty
                        ? _usernameController.text[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt,
                      size: 16, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String label) => Text(
        label,
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
      );

  Widget _buildDateField() {
    final hasDate = _birthDate != null;
    final label = hasDate
        ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
        : 'Select date';
    return InkWell(
      onTap: _pickBirthDate,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: _fieldDecoration(icon: Icons.cake),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: hasDate ? AppTheme.onSurface : AppTheme.outlineVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
      decoration: _fieldDecoration(icon: icon, hint: hint),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
      decoration: _fieldDecoration(
        icon: Icons.lock,
        hint: '••••••••',
        suffix: GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure ? Icons.visibility : Icons.visibility_off,
            color: AppTheme.outline,
            size: 20,
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon, color: AppTheme.outline, size: 20),
      suffixIcon: suffix,
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.outlineVariant, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppTheme.primary, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
