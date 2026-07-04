import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/app_messages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isRegisteringCompany = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isRegisteringCompany) {
        await _authService.registerCompany(
          companyName: _companyNameController.text.trim(),
          adminName: _nameController.text.trim(),
          adminEmail: _emailController.text.trim(),
          adminPassword: _passwordController.text,
        );
        if (!mounted) return;
        AppMessages.showSuccess(
          context,
          'Company "${_companyNameController.text.trim()}" registered successfully! Please wait for System Admin approval.',
        );
        // Clear registration specific fields and switch to login tab
        _companyNameController.clear();
        _nameController.clear();
        setState(() {
          _isRegisteringCompany = false;
        });
      } else {
        await _authService.login(
          _emailController.text.trim(),
          _passwordController.text,
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      if (mounted) {
        final errMsg = e.toString();
        if (errMsg.contains('already active on another device') || errMsg.contains('another device')) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  SizedBox(width: 10),
                  Text('Session Conflict', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                ],
              ),
              content: const Text(
                'This account is already logged in on another device.\n\n'
                'To secure your account, we only allow one active session at a time. '
                'Please log out from your other device, or ask your company administrator to reset your session.',
                style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155)),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
              ],
            ),
          );
        } else {
          AppMessages.showError(context, errMsg);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
      body: Stack(
        children: [
          // Aurora Mesh Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF020617)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Glowing Orbs
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
          
          // Blur layer for background orbs
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
              child: const SizedBox.shrink(),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Brand Logo with Dynamic concentric glowing rings
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
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
                              color: const Color(0xFF2563EB).withValues(alpha: 0.06),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: Image.asset(
                              'assets/HLAM_logo.png',
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 80,
                                height: 80,
                                color: const Color(0xFF2563EB),
                                child: const Icon(Icons.fingerprint_rounded, size: 44, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Brand Name Typography
                    const Text(
                      'HLAM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Company & Employee Management',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 30),
                    
                    // Translucent Glassmorphic Form Card
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Container(
                          padding: const EdgeInsets.all(24.0),
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
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Segmented Tab Toggle
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _isRegisteringCompany = false),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: !_isRegisteringCompany ? const Color(0xFF2563EB) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Login',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: !_isRegisteringCompany ? Colors.white : const Color(0xFF64748B),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => setState(() => _isRegisteringCompany = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            decoration: BoxDecoration(
                                              color: _isRegisteringCompany ? const Color(0xFF2563EB) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              'Register Company',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: _isRegisteringCompany ? Colors.white : const Color(0xFF64748B),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                if (_isRegisteringCompany) ...[
                                  // Company Name
                                  TextFormField(
                                    controller: _companyNameController,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                                    decoration: _inputDecoration(
                                      label: 'Company Name',
                                      icon: Icons.domain_rounded,
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Company name is required' : null,
                                  ),
                                  const SizedBox(height: 18),
                                  // Admin Name
                                  TextFormField(
                                    controller: _nameController,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                                    decoration: _inputDecoration(
                                      label: 'Admin Full Name',
                                      icon: Icons.person_outline_rounded,
                                    ),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Admin full name is required' : null,
                                  ),
                                  const SizedBox(height: 18),
                                ],

                                // Email / Identifier
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                                  decoration: _inputDecoration(
                                    label: _isRegisteringCompany ? 'Admin Email Address' : 'Email or Employee ID',
                                    icon: Icons.email_outlined,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return _isRegisteringCompany ? 'Email is required' : 'Email or Employee ID is required';
                                    }
                                    if (_isRegisteringCompany && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                
                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(color: Color(0xFF0F172A), fontSize: 15),
                                  decoration: _inputDecoration(
                                    label: _isRegisteringCompany ? 'Admin Password' : 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: const Color(0xFF64748B),
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Password is required';
                                    }
                                    if (_isRegisteringCompany && value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                                
                                if (!_isRegisteringCompany) ...[
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                                
                                const SizedBox(height: 24),
                                
                                _buildGradientButton(
                                  onPressed: _isLoading ? null : _submitForm,
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                        )
                                      : Text(_isRegisteringCompany ? 'Register Company' : 'Sign In'),
                                ),

                                if (!_isRegisteringCompany) ...[
                                  const SizedBox(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'Are you an individual user? ',
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                      ),
                                      GestureDetector(
                                        onTap: () => Navigator.pushNamed(context, '/register'),
                                        child: const Text(
                                          'Register Here',
                                          style: TextStyle(
                                            color: Color(0xFF2563EB),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String label, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
      suffixIcon: suffix,
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
    );
  }
}
