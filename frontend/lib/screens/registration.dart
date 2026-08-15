import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_api_service.dart';

enum AuthMode { login, signUp, forgotPassword }

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({Key? key}) : super(key: key);

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  AuthMode _authMode = AuthMode.login;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _authMode = mode;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final apiService = Provider.of<MockApiService>(context, listen: false);

    try {
      if (_authMode == AuthMode.login) {
        await apiService.login(
          _emailController.text.trim(), // Can be email or username
          _passwordController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome back to PickO!'), backgroundColor: Colors.green),
        );
      } else if (_authMode == AuthMode.signUp) {
        await apiService.register(
          _usernameController.text.trim(),
          _emailController.text.trim(),
          _phoneController.text.trim(),
          _passwordController.text,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Registered successfully! Welcome, ${_usernameController.text}.'), backgroundColor: Colors.green),
        );
      } else {
        // Forgot Password
        await apiService.forgotPassword(
          _emailController.text.trim(),
          _phoneController.text.trim(),
          _passwordController.text, // Resetting to new password
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully! Please log in now.'), backgroundColor: Colors.green),
        );
        _switchMode(AuthMode.login);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = const Color(0xFF8B5CF6); // Violet

    return Scaffold(
      backgroundColor: const Color(0xFF0A090F),
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: themeColor.withOpacity(0.12),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withOpacity(0.12),
                      blurRadius: 150,
                      spreadRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withOpacity(0.06),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withOpacity(0.06),
                      blurRadius: 150,
                      spreadRadius: 80,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // App logo
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161420),
                          shape: BoxShape.circle,
                          border: Border.all(color: themeColor.withOpacity(0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: themeColor.withOpacity(0.12),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.airport_shuttle_rounded,
                          color: Color(0xFFC084FC),
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Brand details
                      const Text(
                        'PickO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Secure Crowdshipping Logistics',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 13,
                          letterSpacing: 0.5,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 35),

                      // Toggle Tabs (Only shown in Login / SignUp views)
                      if (_authMode != AuthMode.forgotPassword)
                        Container(
                          margin: const EdgeInsets.only(bottom: 24),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161420),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _switchMode(AuthMode.login),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _authMode == AuthMode.login
                                          ? themeColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'LOG IN',
                                        style: TextStyle(
                                          color: _authMode == AuthMode.login ? Colors.white : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => _switchMode(AuthMode.signUp),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: _authMode == AuthMode.signUp
                                          ? themeColor
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'SIGN UP',
                                        style: TextStyle(
                                          color: _authMode == AuthMode.signUp ? Colors.white : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Auth Form Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161420),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.04)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _authMode == AuthMode.login
                                  ? 'WELCOME BACK'
                                  : _authMode == AuthMode.signUp
                                      ? 'CREATE COMMUTER ACCOUNT'
                                      : 'RESET PASSWORD',
                              style: TextStyle(
                                color: themeColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // 1. Username Field (Only for Sign Up)
                            if (_authMode == AuthMode.signUp) ...[
                              _buildLabel('Choose Username'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _usernameController,
                                hint: 'e.g. johndoe',
                                icon: Icons.alternate_email_rounded,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter a username';
                                  }
                                  if (val.trim().length < 3) {
                                    return 'Username must be at least 3 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 2. Email Address Field (Always shown except on recovery screen if customized, but we use email for recovery)
                            _buildLabel(_authMode == AuthMode.login ? 'Username or Email' : 'Email Address'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _emailController,
                              hint: _authMode == AuthMode.login ? 'Enter username or email' : 'e.g. john@example.com',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Please fill in this field';
                                }
                                if (_authMode != AuthMode.login && !val.contains('@')) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // 3. Phone Number Field (Only for Sign Up / Forgot Password)
                            if (_authMode == AuthMode.signUp || _authMode == AuthMode.forgotPassword) ...[
                              _buildLabel('Phone Number'),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: _phoneController,
                                hint: 'e.g. +16175550199',
                                icon: Icons.phone_android_rounded,
                                keyboardType: TextInputType.phone,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                            ],

                            // 4. Password Field
                            _buildLabel(_authMode == AuthMode.forgotPassword ? 'New Password' : 'Password'),
                            const SizedBox(height: 8),
                            _buildTextField(
                              controller: _passwordController,
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              isObscure: !_isPasswordVisible,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please enter a password';
                                }
                                if (val.length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),

                            // Forgot Password link (Only on Login mode)
                            if (_authMode == AuthMode.login) ...[
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _switchMode(AuthMode.forgotPassword),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                                  child: Text(
                                    'Forgot Password?',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 2,
                                  shadowColor: themeColor.withOpacity(0.3),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : Text(
                                        _authMode == AuthMode.login
                                            ? 'Log In'
                                            : _authMode == AuthMode.signUp
                                                ? 'Register Account'
                                                : 'Reset Password',
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),

                            // Back to Login (Only on Forgot Password mode)
                            if (_authMode == AuthMode.forgotPassword) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => _switchMode(AuthMode.login),
                                  child: Text(
                                    'Back to Log In',
                                    style: TextStyle(color: themeColor, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Explanatory note
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161420),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.02)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded, color: Colors.grey, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Note: PickO encrypts and secures all passwords. New accounts are automatically credited with Rs. 5,000.00 mock balance.',
                                style: TextStyle(color: Colors.grey[500], fontSize: 10.5, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isObscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 18),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFF0F0E16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      validator: validator,
    );
  }
}
