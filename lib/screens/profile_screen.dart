import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../widgets/skeleton_loading.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _upiController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _paypalController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _saveSuccess = false;

  // Focus nodes for animated fields
  final _nameFocus = FocusNode();
  final _upiFocus = FocusNode();
  final _bankAccFocus = FocusNode();
  final _ifscFocus = FocusNode();
  final _paypalFocus = FocusNode();

  bool _nameFocused = false;
  bool _upiFocused = false;
  bool _bankAccFocused = false;
  bool _ifscFocused = false;
  bool _paypalFocused = false;

  late AnimationController _fadeController;
  late AnimationController _loaderController;
  late Animation<double> _fadeAnim;
  late Animation<double> _loaderRotation;

  // ── Design tokens ──
  static const Color _primaryColor = Color(0xFF1A73E8);
  static const Color _accentColor = Color(0xFF0D47A1);
  static const Color _bgColor = Color(0xFFF8FAFF);
  static const Color _cardColor = Colors.white;
  static const Color _subtleGray = Color(0xFFF1F4FB);
  static const Color _textDark = Color(0xFF1C2B4A);
  static const Color _textMid = Color(0xFF5A6A85);
  static const Color _errorColor = Color(0xFFE53935);
  static const Color _successColor = Color(0xFF00897B);
  static const Color _borderDefault = Color(0xFFDDE3F0);
  static const Color _borderFocus = Color(0xFF1A73E8);
  static const Color _disabledBg = Color(0xFFEEF2F9);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _loaderController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _loaderRotation = Tween<double>(begin: 0, end: 1).animate(_loaderController);

    _nameFocus.addListener(() => setState(() => _nameFocused = _nameFocus.hasFocus));
    _upiFocus.addListener(() => setState(() => _upiFocused = _upiFocus.hasFocus));
    _bankAccFocus.addListener(() => setState(() => _bankAccFocused = _bankAccFocus.hasFocus));
    _ifscFocus.addListener(() => setState(() => _ifscFocused = _ifscFocus.hasFocus));
    _paypalFocus.addListener(() => setState(() => _paypalFocused = _paypalFocus.hasFocus));

    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _paypalController.dispose();
    _nameFocus.dispose();
    _upiFocus.dispose();
    _bankAccFocus.dispose();
    _ifscFocus.dispose();
    _paypalFocus.dispose();
    _fadeController.dispose();
    _loaderController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _isLoading = true);
    final doc = await FirestoreService().getUserDocument(user.uid);
    if (doc != null && doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      _nameController.text = data['name'] ?? '';
      _upiController.text = data['upiId'] ?? '';
      _bankAccountController.text = data['bankAccountNumber'] ?? '';
      _bankIfscController.text = data['bankIfsc'] ?? '';
      _paypalController.text = data['paypalId'] ?? '';
    }
    setState(() => _isLoading = false);
    _fadeController.forward();
  }

  Future<void> _saveProfile() async {
    FocusScope.of(context).unfocus();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_nameController.text.trim().isEmpty) {
      _showErrorBanner('Name cannot be empty.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveSuccess = false;
    });

    try {
      await FirestoreService().updateUserProfile(user.uid, {
        'name': _nameController.text.trim(),
        'upiId': _upiController.text.trim(),
        'bankAccountNumber': _bankAccountController.text.trim(),
        'bankIfsc': _bankIfscController.text.trim(),
        'paypalId': _paypalController.text.trim(),
      });
      if (mounted) setState(() => _saveSuccess = true);
      // Auto-dismiss success after 2.5s
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _saveSuccess = false);
      });
    } catch (e) {
      if (mounted) _showErrorBanner('Failed to update profile. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErrorBanner(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 13))),
          ],
        ),
        backgroundColor: _errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String get _avatarLetter {
    final n = _nameController.text.trim();
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  String get _userEmail =>
      FirebaseAuth.instance.currentUser?.email ?? '';

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const GenericScreenSkeleton(itemHeight: 80, itemCount: 4)
          : FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // ── Avatar + Name ──
              _buildAvatarSection(),

              const SizedBox(height: 28),

              // ── Success Banner ──
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _saveSuccess
                    ? _buildSuccessBanner()
                    : const SizedBox.shrink(),
              ),

              if (_saveSuccess) const SizedBox(height: 16),

              // ── Personal Info Card ──
              _buildSectionLabel(
                'PERSONAL INFO',
                Icons.person_outline_rounded,
              ),
              const SizedBox(height: 12),
              _buildCard(
                children: [
                  _buildField(
                    label: 'Full Name',
                    hint: 'John Doe',
                    controller: _nameController,
                    focusNode: _nameFocus,
                    isFocused: _nameFocused,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    label: 'Email Address',
                    hint: _userEmail,
                    controller: TextEditingController(text: _userEmail),
                    focusNode: FocusNode(),
                    isFocused: false,
                    icon: Icons.email_outlined,
                    enabled: false,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Payment Settings Card ──
              _buildSectionLabel(
                'PAYMENT SETTINGS',
                Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 12),
                child: Text(
                  'Add your payment details so group members can pay you directly.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: _textMid, height: 1.5),
                ),
              ),
              _buildCard(
                children: [
                  // UPI
                  _buildField(
                    label: 'UPI ID',
                    hint: 'yourname@upi',
                    controller: _upiController,
                    focusNode: _upiFocus,
                    isFocused: _upiFocused,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 16),

                  // Divider with label
                  _sectionDivider('Bank Transfer'),
                  const SizedBox(height: 16),

                  // Bank Account + IFSC side by side
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildField(
                          label: 'Account Number',
                          hint: '0000 0000 0000',
                          controller: _bankAccountController,
                          focusNode: _bankAccFocus,
                          isFocused: _bankAccFocused,
                          icon: Icons.numbers_rounded,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: _buildField(
                          label: 'IFSC Code',
                          hint: 'SBIN0000123',
                          controller: _bankIfscController,
                          focusNode: _ifscFocus,
                          isFocused: _ifscFocused,
                          icon: Icons.code_rounded,
                          textCapitalization: TextCapitalization.characters,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Divider with label
                  _sectionDivider('PayPal'),
                  const SizedBox(height: 16),

                  _buildField(
                    label: 'PayPal Email / ID',
                    hint: 'user@example.com',
                    controller: _paypalController,
                    focusNode: _paypalFocus,
                    isFocused: _paypalFocused,
                    icon: Icons.payment_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ── Save Button ──
              _buildSaveButton(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  App Bar
  // ─────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _bgColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: _subtleGray,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _borderDefault),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: _textMid),
        ),
      ),
      title: Text(
        'Profile Settings',
        style: GoogleFonts.dmSerifDisplay(
          fontSize: 22,
          color: _textDark,
          fontWeight: FontWeight.w400,
        ),
      ),
      centerTitle: false,
    );
  }

  // ─────────────────────────────────────────────
  //  Avatar Section
  // ─────────────────────────────────────────────
  Widget _buildAvatarSection() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_primaryColor, _accentColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _avatarLetter,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              // Online dot
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _successColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bgColor, width: 2.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : 'Your Name',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _userEmail,
            style: GoogleFonts.inter(fontSize: 13, color: _textMid),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Section Label
  // ─────────────────────────────────────────────
  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 14,
          decoration: BoxDecoration(
            color: _primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: _primaryColor,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Card wrapper
  // ─────────────────────────────────────────────
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderDefault, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A73E8).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Animated Input Field
  // ─────────────────────────────────────────────
  Widget _buildField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isFocused,
    required IconData icon,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    final Color borderColor =
    !enabled ? _borderDefault : isFocused ? _borderFocus : _borderDefault;
    final Color bgColor = !enabled
        ? _disabledBg
        : isFocused
        ? Colors.white
        : _subtleGray;
    final Color iconColor =
    isFocused ? _primaryColor : const Color(0xFFB0BAD0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textDark,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: borderColor, width: isFocused ? 1.8 : 1.2),
            boxShadow: isFocused && enabled
                ? [
              BoxShadow(
                color: _primaryColor.withOpacity(0.10),
                blurRadius: 10,
                offset: const Offset(0, 3),
              )
            ]
                : [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: enabled ? _textDark : _textMid,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                  fontSize: 14, color: const Color(0xFFB0BAD0)),
              prefixIcon:
              Icon(icon, size: 18, color: iconColor),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Inline section divider
  // ─────────────────────────────────────────────
  Widget _sectionDivider(String label) {
    return Row(
      children: [
        Expanded(
            child: Container(height: 1, color: _borderDefault)),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _textMid,
              letterSpacing: 0.5),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Container(height: 1, color: _borderDefault)),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  Success Banner
  // ─────────────────────────────────────────────
  Widget _buildSuccessBanner() {
    return Container(
      key: const ValueKey('success'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB2DDD6), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: _successColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 12),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile Updated',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A73E8)),
              ),
              Text(
                'Your changes have been saved successfully.',
                style: GoogleFonts.inter(
                    fontSize: 12, color: const Color(0xFF00796B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Save Button
  // ─────────────────────────────────────────────
  Widget _buildSaveButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: _isSaving
            ? const LinearGradient(
            colors: [Color(0xFF5B9BEF), Color(0xFF4A7BD4)])
            : const LinearGradient(
          colors: [_primaryColor, _accentColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: _isSaving
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
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.zero,
        ),
        child: _isSaving ? _buildLoader() : _buildButtonLabel(),
      ),
    );
  }

  Widget _buildButtonLabel() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.save_alt_rounded, size: 18, color: Colors.white),
      const SizedBox(width: 8),
      Text(
        'Save Changes',
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 0.2,
        ),
      ),
    ],
  );

  Widget _buildLoader() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      RotationTransition(
        turns: _loaderRotation,
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withOpacity(0.25), width: 2.5),
          ),
          child: CustomPaint(painter: _ArcLoaderPainter()),
        ),
      ),
      const SizedBox(width: 12),
      Text(
        'Saving…',
        style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.white),
      ),
    ],
  );
}

// ──────────────────────────────────────────────
//  Arc Loader Painter (same as login/register)
// ──────────────────────────────────────────────
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
      -1.57,
      2.2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcLoaderPainter oldDelegate) => false;
}
