import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _nameFocused = false;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _loaderController;
  late AnimationController _shakeController;
  late AnimationController _errorBannerController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _loaderRotation;
  late Animation<double> _shakeAnim;
  late Animation<double> _errorBannerAnim;

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  // ── Design tokens (identical to LoginScreen) ──
  static const Color _primaryColor = Color(0xFF1A73E8);
  static const Color _accentColor = Color(0xFF0D47A1);
  static const Color _bgColor = Color(0xFFF8FAFF);
  static const Color _cardColor = Colors.white;
  static const Color _subtleGray = Color(0xFFF1F4FB);
  static const Color _textDark = Color(0xFF1C2B4A);
  static const Color _textMid = Color(0xFF5A6A85);
  static const Color _errorColor = Color(0xFFE53935);
  static const Color _borderDefault = Color(0xFFDDE3F0);
  static const Color _borderFocus = Color(0xFF1A73E8);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _loaderController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _errorBannerController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    _loaderRotation =
        Tween<double>(begin: 0, end: 1).animate(_loaderController);
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 1),
    ]).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
    _errorBannerAnim =
        CurvedAnimation(parent: _errorBannerController, curve: Curves.easeOut);

    _nameFocusNode.addListener(
            () => setState(() => _nameFocused = _nameFocusNode.hasFocus));
    _emailFocusNode.addListener(
            () => setState(() => _emailFocused = _emailFocusNode.hasFocus));
    _passwordFocusNode.addListener(
            () => setState(() => _passwordFocused = _passwordFocusNode.hasFocus));

    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _loaderController.dispose();
    _shakeController.dispose();
    _errorBannerController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      return;
    }

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (authService.errorMessage != null) {
      _shakeController.forward(from: 0);
      _errorBannerController.forward(from: 0);
    }

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
      );
    }
  }

  void _clearError(AuthService authService) {
    if (authService.errorMessage != null) {
      authService.clearError();
      _errorBannerController.reverse();
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Consumer<AuthService>(
          builder: (context, authService, child) {
            final error = authService.errorMessage;

            // Parse server error into field-level hints
            String? nameError;
            String? emailError;
            String? passwordError;

            if (error != null) {
              if (error.toLowerCase().contains('name')) {
                nameError = error;
              } else if (error.toLowerCase().contains('email') ||
                  error.toLowerCase().contains('already')) {
                emailError = error;
              } else if (error.toLowerCase().contains('password')) {
                passwordError = error;
              }
            } else {
              if (_errorBannerController.isCompleted) {
                _errorBannerController.reverse();
              }
            }

            // Friendly banner message
            String bannerMessage = '';
            if (error != null) {
              if (error.toLowerCase().contains('already') ||
                  error.toLowerCase().contains('exists')) {
                bannerMessage =
                'An account with this email already exists. Try logging in instead.';
              } else if (error.toLowerCase().contains('network') ||
                  error.toLowerCase().contains('connection')) {
                bannerMessage =
                'No internet connection. Check your network and retry.';
              } else if (error.toLowerCase().contains('weak') ||
                  error.toLowerCase().contains('password')) {
                bannerMessage =
                'Your password is too weak. Use at least 6 characters.';
              } else {
                bannerMessage = error;
              }
            }

            return FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 52),

                        // ── Header ──
                        _buildHeader(),

                        const SizedBox(height: 40),

                        // ── Error Banner ──
                        AnimatedBuilder(
                          animation: _errorBannerAnim,
                          builder: (context, child) => ClipRect(
                            child: Align(
                              heightFactor: _errorBannerAnim.value,
                              child: Opacity(
                                opacity: _errorBannerAnim.value,
                                child: child,
                              ),
                            ),
                          ),
                          child: error != null
                              ? _buildErrorBanner(bannerMessage)
                              : const SizedBox.shrink(),
                        ),

                        if (error != null) const SizedBox(height: 14),

                        // ── Form Card (with shake) ──
                        AnimatedBuilder(
                          animation: _shakeAnim,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(_shakeAnim.value, 0),
                            child: child,
                          ),
                          child: _buildFormCard(
                            authService: authService,
                            nameError: nameError,
                            emailError: emailError,
                            passwordError: passwordError,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Register Button ──
                        _buildRegisterButton(authService),

                        const SizedBox(height: 20),

                        // ── OR Divider ──
                        _buildDivider(),

                        const SizedBox(height: 20),

                        // ── Google Sign-In Button ──
                        _buildGoogleButton(authService),

                        const SizedBox(height: 20),

                        // ── Info Banner ──
                        _buildInfoBanner(),

                        const SizedBox(height: 16),

                        // ── Login Link ──
                        _buildLoginLink(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Header
  // ─────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_rounded,
            size: 38,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Create Account',
          style: GoogleFonts.dmSerifDisplay(
            fontSize: 34,
            fontWeight: FontWeight.w400,
            color: _textDark,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Join SplitEase and split expenses effortlessly',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: _textMid,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Form Card
  // ─────────────────────────────────────────────
  Widget _buildFormCard({
    required AuthService authService,
    String? nameError,
    String? emailError,
    String? passwordError,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A73E8).withOpacity(0.07),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full Name ──
          _fieldLabel('Full Name'),
          const SizedBox(height: 8),
          _buildNameField(authService, nameError),
          if (nameError != null) ...[
            const SizedBox(height: 6),
            _errorText(nameError),
          ],

          const SizedBox(height: 20),

          // ── Email ──
          _fieldLabel('Email Address'),
          const SizedBox(height: 8),
          _buildEmailField(authService, emailError),
          if (emailError != null) ...[
            const SizedBox(height: 6),
            _errorText(emailError),
          ],

          const SizedBox(height: 20),

          // ── Password ──
          _fieldLabel('Password'),
          const SizedBox(height: 8),
          _buildPasswordField(authService, passwordError),
          if (passwordError != null) ...[
            const SizedBox(height: 6),
            _errorText(passwordError),
          ],

          const SizedBox(height: 6),

          // Password hint
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: Color(0xFFB0BAD0),
              ),
              const SizedBox(width: 5),
              Text(
                'Must be at least 6 characters',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _textMid,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Shared field helpers
  // ─────────────────────────────────────────────
  Widget _fieldLabel(String label) => Text(
    label,
    style: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: _textDark,
      letterSpacing: 0.1,
    ),
  );

  Widget _errorText(String message) => Row(
    children: [
      const Icon(Icons.error_outline_rounded,
          size: 13, color: _errorColor),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          message,
          style: GoogleFonts.inter(fontSize: 12, color: _errorColor),
        ),
      ),
    ],
  );

  // ─────────────────────────────────────────────
  //  Name Field
  // ─────────────────────────────────────────────
  Widget _buildNameField(AuthService authService, String? nameError) {
    final bool hasError = nameError != null;
    final Color borderColor = hasError
        ? _errorColor
        : _nameFocused
        ? _borderFocus
        : _borderDefault;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _nameFocused ? Colors.white : _subtleGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor, width: _nameFocused ? 1.8 : 1.2),
        boxShadow: _nameFocused
            ? [
          BoxShadow(
            color: _primaryColor.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ]
            : [],
      ),
      child: TextFormField(
        controller: _nameController,
        focusNode: _nameFocusNode,
        enabled: !authService.isLoading,
        textCapitalization: TextCapitalization.words,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: _textDark,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'John Doe',
          hintStyle: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFFB0BAD0)),
          prefixIcon: Icon(
            Icons.person_outline_rounded,
            size: 20,
            color: _nameFocused ? _primaryColor : const Color(0xFFB0BAD0),
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        onChanged: (_) => _clearError(authService),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your name';
          }
          if (value.trim().length < 2) {
            return 'Name must be at least 2 characters';
          }
          return null;
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Email Field
  // ─────────────────────────────────────────────
  Widget _buildEmailField(AuthService authService, String? emailError) {
    final bool hasError = emailError != null;
    final Color borderColor = hasError
        ? _errorColor
        : _emailFocused
        ? _borderFocus
        : _borderDefault;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _emailFocused ? Colors.white : _subtleGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor, width: _emailFocused ? 1.8 : 1.2),
        boxShadow: _emailFocused
            ? [
          BoxShadow(
            color: _primaryColor.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ]
            : [],
      ),
      child: TextFormField(
        controller: _emailController,
        focusNode: _emailFocusNode,
        enabled: !authService.isLoading,
        keyboardType: TextInputType.emailAddress,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: _textDark,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'you@example.com',
          hintStyle: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFFB0BAD0)),
          prefixIcon: Icon(
            Icons.email_outlined,
            size: 20,
            color: _emailFocused ? _primaryColor : const Color(0xFFB0BAD0),
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        onChanged: (_) => _clearError(authService),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your email';
          }
          if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(value.trim())) {
            return 'Please enter a valid email address';
          }
          return null;
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Password Field
  // ─────────────────────────────────────────────
  Widget _buildPasswordField(AuthService authService, String? passwordError) {
    final bool hasError = passwordError != null;
    final Color borderColor = hasError
        ? _errorColor
        : _passwordFocused
        ? _borderFocus
        : _borderDefault;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _passwordFocused ? Colors.white : _subtleGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor, width: _passwordFocused ? 1.8 : 1.2),
        boxShadow: _passwordFocused
            ? [
          BoxShadow(
            color: _primaryColor.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ]
            : [],
      ),
      child: TextFormField(
        controller: _passwordController,
        focusNode: _passwordFocusNode,
        enabled: !authService.isLoading,
        obscureText: _obscurePassword,
        style: GoogleFonts.inter(
          fontSize: 15,
          color: _textDark,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: 'Create a strong password',
          hintStyle: GoogleFonts.inter(
              fontSize: 14, color: const Color(0xFFB0BAD0)),
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            size: 20,
            color:
            _passwordFocused ? _primaryColor : const Color(0xFFB0BAD0),
          ),
          suffixIcon: GestureDetector(
            onTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                key: ValueKey(_obscurePassword),
                size: 20,
                color: _passwordFocused
                    ? _primaryColor
                    : const Color(0xFFB0BAD0),
              ),
            ),
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        onChanged: (_) => _clearError(authService),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter a password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Register Button
  // ─────────────────────────────────────────────
  Widget _buildRegisterButton(AuthService authService) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: authService.isLoading
            ? const LinearGradient(
          colors: [Color(0xFF5B9BEF), Color(0xFF4A7BD4)],
        )
            : const LinearGradient(
          colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: authService.isLoading
            ? []
            : [
          BoxShadow(
            color: _primaryColor.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: authService.isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: EdgeInsets.zero,
        ),
        child: authService.isLoading ? _buildLoader() : _buildButtonLabel(),
      ),
    );
  }

  Widget _buildButtonLabel() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Text(
        'Create Account',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(width: 8),
      const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
    ],
  );

  // ─────────────────────────────────────────────
  //  Professional Arc Loader
  // ─────────────────────────────────────────────
  Widget _buildLoader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        RotationTransition(
          turns: _loaderRotation,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.25),
                width: 2.5,
              ),
            ),
            child: CustomPaint(painter: _ArcLoaderPainter()),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'Creating account…',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Error Banner
  // ─────────────────────────────────────────────
  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB3B3), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Color(0xFFE53935),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close_rounded,
                color: Colors.white, size: 12),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registration Failed',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFC62828),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: const Color(0xFFB71C1C),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Info Banner
  // ─────────────────────────────────────────────
  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBDD6FB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF1A73E8), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your account is free. After registering, we\'ll send a verification link to your email.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFF1A4F9C),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Login Link
  // ─────────────────────────────────────────────
  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: GoogleFonts.inter(fontSize: 13.5, color: _textMid),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'Sign In',
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Divider Line
  // ─────────────────────────────────────────────
  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: _borderDefault, thickness: 1.2),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textMid,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: _borderDefault, thickness: 1.2),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Google Sign-In Button
  // ─────────────────────────────────────────────
  Widget _buildGoogleButton(AuthService authService) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderDefault, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: authService.isLoading
              ? null
              : () async {
                  final success = await authService.signInWithGoogle();
                  if (!success && authService.errorMessage != null) {
                    _shakeController.forward(from: 0);
                    _errorBannerController.forward(from: 0);
                  }
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      'G',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF4285F4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────
//  Arc Loader Painter
// ──────────────────────────────────────────────────
class _ArcLoaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -1.57, // start at top
      2.2,   // ~126° sweep
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcLoaderPainter oldDelegate) => false;
}