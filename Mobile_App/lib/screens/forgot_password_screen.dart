import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/app_messages.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  final _authService = AuthService();
  
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();
  final _formKey3 = GlobalKey<FormState>();

  int _currentStep = 1; // 1: Email, 2: OTP, 3: Reset Password
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _resetToken = '';
  
  // Timer for OTP resend (60 seconds)
  Timer? _timer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  // Custom blinking cursor for OTP boxes
  bool _cursorBlink = true;
  Timer? _cursorTimer;

  @override
  void initState() {
    super.initState();
    _otpController.addListener(_onOtpChanged);
    _otpFocusNode.addListener(_onOtpFocusChanged);
    _passwordController.addListener(_onPasswordChanged);
    
    // Blinking cursor timer for OTP digit boxes
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted && _otpFocusNode.hasFocus) {
        setState(() {
          _cursorBlink = !_cursorBlink;
        });
      }
    });
  }

  void _onOtpChanged() {
    setState(() {});
  }

  void _onOtpFocusChanged() {
    setState(() {});
  }

  void _onPasswordChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _otpFocusNode.removeListener(_onOtpFocusChanged);
    _otpFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    _timer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _secondsRemaining = 60;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _canResend = true;
          _timer?.cancel();
        }
      });
    });
  }

  void _sendOtp() async {
    if (!_formKey1.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      
      AppMessages.showSuccess(context, 'Verification code sent to ${_emailController.text}');
      setState(() {
        _currentStep = 2;
      });
      _startResendTimer();
      // Auto-focus the OTP hidden input
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_otpFocusNode);
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppMessages.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resendOtp() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);
    try {
      await _authService.forgotPassword(_emailController.text.trim());
      if (!mounted) return;
      
      AppMessages.showSuccess(context, 'New verification code sent!');
      _startResendTimer();
      _otpController.clear();
      _otpFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;
      AppMessages.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _verifyOtp() async {
    if (!_formKey2.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final token = await _authService.verifyOtp(
        _emailController.text.trim(),
        _otpController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _resetToken = token;
        _currentStep = 3;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          FocusScope.of(context).requestFocus(_passwordFocusNode);
        }
      });
    } catch (e) {
      if (!mounted) return;
      AppMessages.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetPassword() async {
    if (!_formKey3.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.resetPassword(_resetToken, _passwordController.text);
      if (!mounted) return;
      
      // Show premium success dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 60),
              SizedBox(height: 16),
              Text(
                'Password Reset!',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 22),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          content: const Text(
            'Your account password has been successfully updated. You can now log in securely.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF4F46E5)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pushNamedAndRemoveUntil(ctx, '/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: const Text('Return to Login'),
              ),
            )
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppMessages.showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _getPasswordStrength(String password) {
    if (password.isEmpty) return 0;
    if (password.length < 6) return 1; // Weak
    
    final hasNumbers = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecial = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    
    if (hasNumbers || hasSpecial) {
      return 3; // Strong
    }
    return 2; // Medium
  }

  Widget _buildPasswordStrengthIndicator() {
    final strength = _getPasswordStrength(_passwordController.text);
    Color strengthColor;
    String strengthLabel;
    int litSegments;

    switch (strength) {
      case 1:
        strengthColor = const Color(0xFFEF4444); // Red
        strengthLabel = 'Weak Password';
        litSegments = 1;
        break;
      case 2:
        strengthColor = const Color(0xFFF59E0B); // Orange
        strengthLabel = 'Medium Strength';
        litSegments = 2;
        break;
      case 3:
        strengthColor = const Color(0xFF10B981); // Emerald Green
        strengthLabel = 'Strong Password';
        litSegments = 3;
        break;
      default:
        strengthColor = Colors.transparent;
        strengthLabel = '';
        litSegments = 0;
    }

    if (strength == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password Security',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              Text(
                strengthLabel,
                style: TextStyle(fontSize: 11, color: strengthColor, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // 3-Segmented Pill Indicator
          Row(
            children: List.generate(3, (index) {
              final isLit = index < litSegments;
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  margin: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == 2 ? 0 : 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: isLit ? strengthColor : const Color(0xFFE2E8F0),
                    boxShadow: isLit
                        ? [
                            BoxShadow(
                              color: strengthColor.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsChecklist() {
    final password = _passwordController.text;
    final isMinLength = password.length >= 6;
    final hasNumbersOrSpecial = RegExp(r'[0-9]').hasMatch(password) || RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Column(
        children: [
          _buildChecklistItem('Minimum of 6 characters', isMinLength),
          const SizedBox(height: 8),
          _buildChecklistItem('Contains a number or special character', hasNumbersOrSpecial),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String label, bool isMet) {
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 200),
      style: TextStyle(
        fontSize: 12,
        color: isMet ? const Color(0xFF10B981) : const Color(0xFF64748B),
        fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMet ? const Color(0xFFD1FAE5) : const Color(0xFFF1F5F9),
            ),
            child: Icon(
              isMet ? Icons.check_rounded : Icons.fiber_manual_record_rounded,
              size: 12,
              color: isMet ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        Expanded(child: _buildProgressSegment(1, 'Email', _currentStep >= 1)),
        const SizedBox(width: 8),
        Expanded(child: _buildProgressSegment(2, 'Verify', _currentStep >= 2)),
        const SizedBox(width: 8),
        Expanded(child: _buildProgressSegment(3, 'Reset', _currentStep >= 3)),
      ],
    );
  }

  Widget _buildProgressSegment(int stepNum, String title, bool isCompletedOrActive) {
    final isActive = _currentStep == stepNum;
    final isDone = _currentStep > stepNum;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isDone
                ? const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)], // Completed check green
                  )
                : isActive
                    ? const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF4F46E5)], // Active blue/indigo
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFE2E8F0), Color(0xFFE2E8F0)], // Grey
                      ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (isDone)
              const Padding(
                padding: EdgeInsets.only(right: 4.0),
                child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 12),
              ),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.w500,
                color: isDone
                    ? const Color(0xFF10B981)
                    : isActive
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required VoidCallback? onPressed,
    required Widget child,
    Color glowColor = const Color(0xFF2563EB),
    List<Color> colors = const [Color(0xFF2563EB), Color(0xFF4F46E5)],
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: onPressed == null
            ? null
            : LinearGradient(
                colors: colors,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: onPressed == null ? const Color(0xFFCBD5E1) : null,
        borderRadius: BorderRadius.circular(18),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white, letterSpacing: 0.5),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Colors.white),
          onPressed: () {
            if (_currentStep > 1 && _currentStep < 3) {
              setState(() {
                _currentStep--;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background Mesh & Glowing Orbs wrapped in IgnorePointer to avoid intercepting touch events
            IgnorePointer(
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF020617)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -100,
                    left: -100,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    right: -100,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 280,
                    right: -150,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),

            // Main Scrollable Content
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 32,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                // Translucent Glassmorphic Card Container
                                Padding(
                                  padding: const EdgeInsets.only(top: 55),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 300),
                                        key: ValueKey<int>(_currentStep),
                                        padding: const EdgeInsets.fromLTRB(24.0, 72.0, 24.0, 24.0),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.94),
                                          borderRadius: BorderRadius.circular(30),
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.45),
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.15),
                                              blurRadius: 40,
                                              offset: const Offset(0, 16),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildStepIndicator(),
                                            const SizedBox(height: 24),
                                            AnimatedSwitcher(
                                              duration: const Duration(milliseconds: 250),
                                              child: _buildStepContent(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        
                        // Layered Premium Illustration Icon Display - Overlapping Header Badge
                        Positioned(
                          top: 0,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.04),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  )
                                ]
                              ),
                              padding: const EdgeInsets.all(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _currentStep == 1
                                      ? Icons.mail_lock_rounded
                                      : _currentStep == 2
                                          ? Icons.security_rounded
                                          : Icons.lock_reset_rounded,
                                  size: 34,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ),
  ],
),
),
);
}

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildEmailStep();
      case 2:
        return _buildOtpStep();
      case 3:
        return _buildResetStep();
      default:
        return _buildEmailStep();
    }
  }

  Widget _buildEmailStep() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        key: const ValueKey('email_step'),
        children: [
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Enter your registered email address below. We will send you a 4-digit verification code.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _sendOtp(),
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Email Address',
              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF2563EB), size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          _buildGradientButton(
            onPressed: _isLoading ? null : _sendOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Send Verification Code'),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        key: const ValueKey('otp_step'),
        children: [
          const Text(
            'Enter Code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'We have sent a 4-digit verification code to ${_emailController.text}. Please enter it below.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          
          // Modern separate OTP digital boxes with transparent TextField overlay
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              FocusScope.of(context).requestFocus(_otpFocusNode);
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Fully hit-testable transparent TextField overlay
                Positioned.fill(
                  child: TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_otpController.text.length == 4 && !_isLoading) {
                        _verifyOtp();
                      }
                    },
                    maxLength: 4,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    showCursor: false,
                    enableInteractiveSelection: false,
                    style: const TextStyle(color: Colors.transparent, fontSize: 1),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      fillColor: Colors.transparent,
                    ),
                  ),
                ),
                // Styled OTP visual boxes row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    final text = _otpController.text;
                    final isFocused = _otpFocusNode.hasFocus && text.length == index;
                    final isFilled = text.length > index;
                    final digit = isFilled ? text[index] : '';

                    Color boxBgColor;
                    Color borderColor;
                    double borderWidth;
                    List<BoxShadow> boxShadows = [];

                    if (isFocused) {
                      boxBgColor = Colors.white;
                      borderColor = const Color(0xFF2563EB);
                      borderWidth = 2.2;
                      boxShadows = [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ];
                    } else if (isFilled) {
                      boxBgColor = const Color(0xFFEFF6FF);
                      borderColor = const Color(0xFF2563EB).withValues(alpha: 0.5);
                      borderWidth = 1.5;
                    } else {
                      boxBgColor = const Color(0xFFF8FAFC);
                      borderColor = const Color(0xFFE2E8F0);
                      borderWidth = 1.5;
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 56,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: boxBgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: borderColor,
                          width: borderWidth,
                        ),
                        boxShadow: boxShadows,
                      ),
                      child: digit.isNotEmpty
                          ? Text(
                              digit,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            )
                          : isFocused && _cursorBlink
                              ? Container(
                                  width: 2.2,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                )
                              : const SizedBox.shrink(),
                    );
                  }),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 28),
          
          // Timer display styled as a chip
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _canResend ? Icons.refresh_rounded : Icons.timer_outlined,
                    size: 16,
                    color: const Color(0xFF2563EB),
                  ),
                  const SizedBox(width: 8),
                  _canResend
                      ? GestureDetector(
                          onTap: _isLoading ? null : _resendOtp,
                          child: const Text(
                            'Resend OTP Code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        )
                      : Text(
                          "Resend in ${_secondsRemaining}s",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildGradientButton(
            onPressed: _isLoading || _otpController.text.length < 4 ? null : _verifyOtp,
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Verify & Continue'),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _formKey3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        key: const ValueKey('reset_step'),
        children: [
          const Text(
            'New Password',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'Please choose a strong new password to secure your account.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_confirmPasswordFocusNode);
            },
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
            decoration: InputDecoration(
              labelText: 'New Password',
              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB), size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a new password';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters long';
              }
              return null;
            },
          ),
          
          // Password Strength Bar
          _buildPasswordStrengthIndicator(),
          const SizedBox(height: 8),
          
          // Password Requirements Checklist
          _buildRequirementsChecklist(),
          const SizedBox(height: 16),
          
          TextFormField(
            controller: _confirmPasswordController,
            focusNode: _confirmPasswordFocusNode,
            obscureText: _obscureConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _resetPassword(),
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Confirm Password',
              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF2563EB), size: 20),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Colors.redAccent, width: 1),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          _buildGradientButton(
            onPressed: _isLoading ? null : _resetPassword,
            colors: const [Color(0xFF10B981), Color(0xFF059669)], // Emerald Green gradient
            glowColor: const Color(0xFF10B981),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Reset Password'),
          ),
        ],
      ),
    );
  }
}
