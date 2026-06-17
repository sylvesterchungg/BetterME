import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

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
    _usernameController.dispose();
    _blobController.dispose();
    super.dispose();
  }

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password.');
      return;
    }

    if (!_isLogin && username.isEmpty) {
      _showError('Please enter a username.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await context.read<AppProvider>().loginWithEmail(email, password);
      } else {
        await context.read<AppProvider>().registerWithEmail(email, password, username);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      _showError(e.toString().split(']').last.trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await context.read<AppProvider>().loginWithGoogle();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      _showError('Google Sign-In failed or was canceled.');
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryContainer.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.bubble_chart,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'betterME',
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Username field (only for registration)
          if (!_isLogin) ...[
            _buildFieldLabel('Username'),
            const SizedBox(height: 8),
            _buildTextField(
              controller: _usernameController,
              icon: Icons.person,
              hint: 'Choose a username',
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
          _buildPasswordField(),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      onSubmitted: (_) => _submit(),
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
          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
          child: Icon(
            _obscurePassword ? Icons.visibility : Icons.visibility_off,
            color: AppTheme.outline,
            size: 20,
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
