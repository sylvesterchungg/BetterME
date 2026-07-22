import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/app_provider.dart';
import '../theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthDate;
  File? _avatarFile;

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _blobController;

  @override
  void initState() {
    super.initState();
    _blobController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _blobController.dispose();
    super.dispose();
  }

  void _submit() async {
    // Runs the validators of every currently-mounted field (login mode only
    // mounts email + password; sign-up also mounts username/confirm/phone).
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await context.read<AppProvider>().loginWithEmail(email, password);
      } else {
        await context.read<AppProvider>().registerWithEmail(
              email,
              password,
              username,
              name: _nameController.text.trim(),
              birthDate: _birthDate,
              phoneNumber: _phoneController.text.trim(),
              photo: _avatarFile,
            );
      }
      // No manual navigation — AuthGate swaps to MainScreen when auth state changes.
    } catch (e) {
      _showError(e.toString().split(']').last.trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Validators ─────────────────────────────────────────────────────────────

  String? _validateName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Please enter your name';
    return null;
  }

  String? _validateUsername(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Please choose a username';
    if (value.length < 3) return 'At least 3 characters';
    return null;
  }

  String? _validateEmail(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Please enter your email';
    final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Please enter a password';
    if (value.length < 6) return 'At least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if ((v ?? '') != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  // Phone is optional; only validate the format when something was typed.
  String? _validatePhone(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return null;
    final phoneRegex = RegExp(r'^\+?[\d\s-]{7,15}$');
    if (!phoneRegex.hasMatch(value)) return 'Enter a valid phone number';
    return null;
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

  Future<void> _pickAvatar() async {
    final img = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (img != null) setState(() => _avatarFile = File(img.path));
  }

  // Circular avatar picker shown on the sign-up form. Tapping it opens the
  // gallery; until a photo is chosen it shows a neutral silhouette default
  // (like Instagram/Facebook) rather than a randomly generated stock image.
  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _pickAvatar,
      child: Stack(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.surfaceContainerHigh,
              border: Border.all(color: AppTheme.outlineVariant, width: 2),
              image: _avatarFile != null
                  ? DecorationImage(
                      image: FileImage(_avatarFile!), fit: BoxFit.cover)
                  : null,
            ),
            child: _avatarFile == null
                ? const Icon(Icons.person, size: 44, color: AppTheme.outline)
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
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AppProvider>().loginWithGoogle();
      // No manual navigation — AuthGate swaps to MainScreen when auth state changes.
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      _showError('Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email address first.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await context.read<AppProvider>().sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent. Check your inbox.')),
        );
      }
    } catch (e) {
      _showError('Could not send reset email. Check the address and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppTheme.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background Blobs
          _buildBackgroundBlobs(),
          // Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildHeroSection(),
                    const SizedBox(height: 32),
                    _buildLoginCard(),
                    const SizedBox(height: 24),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundBlobs() {
    return AnimatedBuilder(
      animation: _blobController,
      builder: (context, child) {
        final t = _blobController.value;
        return Stack(
          children: [
            Positioned(
              top: -60 + (t * 40),
              left: -60 + (t * 20),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
              ),
            ),
            Positioned(
              bottom: -40 + (t * 30),
              right: -40 + (t * 15),
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryFixed.withValues(alpha: 0.3),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        // Logo Icon
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/icon/Icon.png',
              width: 64,
              height: 64,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'BetterME',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your journey to a better you starts here.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile photo picker (only for registration)
          if (!_isLogin) ...[
            _buildAvatarPicker(),
            const SizedBox(height: 6),
            const Text(
              'Add a photo (optional)',
              style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
          ],

          // Full name + username fields (only for registration)
          if (!_isLogin) ...[
            _buildFieldLabel('Full Name'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _nameController,
              icon: Icons.badge_outlined,
              hint: 'Your real name',
              validator: _validateName,
            ),
            const SizedBox(height: 16),
            _buildFieldLabel('Username'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _usernameController,
              icon: Icons.alternate_email,
              hint: 'Choose a username',
              validator: _validateUsername,
            ),
            const SizedBox(height: 16),
          ],

          // Email Field
          _buildFieldLabel('Email'),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailController,
            icon: Icons.mail,
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
          const SizedBox(height: 16),

          // Password Field
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFieldLabel('Password'),
              if (_isLogin)
                GestureDetector(
                  onTap: _sendPasswordReset,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primary,
                      letterSpacing: 0.02,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPasswordField(
            controller: _passwordController,
            obscure: _obscurePassword,
            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
            validator: _validatePassword,
            textInputAction:
                _isLogin ? TextInputAction.done : TextInputAction.next,
            onFieldSubmitted: _isLogin ? (_) => _submit() : null,
          ),

          // Confirm password + optional details (registration only)
          if (!_isLogin) ...[
            const SizedBox(height: 16),
            _buildFieldLabel('Confirm Password'),
            const SizedBox(height: 8),
            _buildPasswordField(
              controller: _confirmPasswordController,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: _validateConfirm,
            ),
            const SizedBox(height: 16),
            _buildFieldLabel('Birth Date (optional)'),
            const SizedBox(height: 8),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildFieldLabel('Phone (optional)'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _phoneController,
              icon: Icons.phone,
              hint: '+1 555 123 4567',
              keyboardType: TextInputType.phone,
              validator: _validatePhone,
            ),
          ],
          const SizedBox(height: 24),

          // Sign In / Sign Up Button
          if (_isLoading)
            const SizedBox(
              height: 52,
              child: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryContainer,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999), // Pill
                  ),
                  elevation: 1,
                ),
                child: Text(
                  _isLogin ? 'Sign In' : 'Sign Up',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.01),
                ),
              ),
            ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Row(
              children: [
                Expanded(child: Container(height: 1, color: AppTheme.outlineVariant)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'OR CONTINUE WITH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.outline,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Expanded(child: Container(height: 1, color: AppTheme.outlineVariant)),
              ],
            ),
          ),

          // Google Sign-In
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _loginWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 24, color: Colors.red),
              label: const Text(
                'Google',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: const BorderSide(color: AppTheme.outlineVariant),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
            letterSpacing: 0.01,
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
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppTheme.outline, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.outlineVariant, fontSize: 14),
        filled: true,
        fillColor: AppTheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
    TextInputAction textInputAction = TextInputAction.done,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock, color: AppTheme.outline, size: 20),
        hintText: '••••••••',
        hintStyle: const TextStyle(color: AppTheme.outlineVariant, fontSize: 14),
        filled: true,
        fillColor: AppTheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: GestureDetector(
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

  // Tappable, read-only field that opens the date picker. Birth date is
  // optional, so there is no validator — an un-picked value stays null.
  Widget _buildDateField() {
    final hasDate = _birthDate != null;
    final label = hasDate
        ? '${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}'
        : 'Select date';
    return InkWell(
      onTap: _pickBirthDate,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.cake, color: AppTheme.outline, size: 20),
          filled: true,
          fillColor: AppTheme.surfaceContainerLow,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
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

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLogin ? 'New to betterME? ' : 'Already have an account? ',
          style: const TextStyle(fontSize: 14, color: AppTheme.onSurfaceVariant),
        ),
        GestureDetector(
          onTap: () => setState(() => _isLogin = !_isLogin),
          child: Text(
            _isLogin ? 'Sign Up' : 'Sign In',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
