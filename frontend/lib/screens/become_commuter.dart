import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/mock_api_service.dart';

class BecomeCommuterScreen extends StatefulWidget {
  const BecomeCommuterScreen({Key? key}) : super(key: key);

  @override
  State<BecomeCommuterScreen> createState() => _BecomeCommuterScreenState();
}

class _BecomeCommuterScreenState extends State<BecomeCommuterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  final _startCityController = TextEditingController(text: '');
  final _destCityController = TextEditingController(text: '');
  
  bool _termsAccepted = false;
  bool _scanningKyc = false;
  bool _kycVerified = false;

  // File paths for NIC images
  XFile? _nicFrontFile;
  XFile? _nicBackFile;

  @override
  void initState() {
    super.initState();
    final apiService = Provider.of<MockApiService>(context, listen: false);
    final user = apiService.currentUser;
    _nameController = TextEditingController(text: user.name);
    _phoneController = TextEditingController(text: user.phoneNumber ?? '');
    _destCityController.text = user.routeCity ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _startCityController.dispose();
    _destCityController.dispose();
    super.dispose();
  }

  Future<void> _pickNicFront() async {
    final picker = ImagePicker();
    try {
      final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (img != null) {
        setState(() {
          _nicFrontFile = img;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting front image: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _pickNicBack() async {
    final picker = ImagePicker();
    try {
      final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (img != null) {
        setState(() {
          _nicBackFile = img;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting back image: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nicFrontFile == null || _nicBackFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both sides of your NIC card.'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms and Security Collateral agreement.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() {
      _scanningKyc = true;
    });

    // Simulate OCR and biometric validation checks
    await Future.delayed(const Duration(milliseconds: 2500));

    if (!mounted) return;

    final apiService = Provider.of<MockApiService>(context, listen: false);
    try {
      // Upgrade KYC verification status and commuter route
      await apiService.registerAsCommuter(
        startCity: _startCityController.text.trim(),
        routeCity: _destCityController.text.trim(),
        termsAccepted: _termsAccepted,
        nicFrontPath: _nicFrontFile!.path,
        nicBackPath: _nicBackFile!.path,
      );

      setState(() {
        _scanningKyc = false;
        _kycVerified = true;
      });

      _showApplicationSuccessDialog(context, _startCityController.text.trim(), _destCityController.text.trim());
    } catch (e) {
      setState(() {
        _scanningKyc = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Commuter Onboarding',
          style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.06),
                    blurRadius: 90,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.06),
                    blurRadius: 90,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Apply to Deliver',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unlock inter-city matching runs and start earning tips on your routes.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    const SizedBox(height: 25),

                    // SECTION 1: Personal Profile Info (Auto-filled)
                    _buildSectionHeader('PERSONAL PROFILE INFO (AUTO-FILLED)'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B2C).withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          _buildAutofilledField('Full Name', _nameController, Icons.person_rounded),
                          const SizedBox(height: 12),
                          _buildAutofilledField('Contact Number', _phoneController, Icons.phone_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // SECTION 2: Route Details
                    _buildSectionHeader('YOUR TRANSIT ROUTE'),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Start Ride City', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _startCityController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _getInputDecoration('e.g. Boston'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Destination City', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _destCityController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _getInputDecoration('e.g. New York'),
                                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // SECTION 3: National Identity Card (NIC) Upload both sides
                    _buildSectionHeader('UPLOAD NATIONAL IDENTITY CARD (NIC)'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildNicSelector(
                            title: 'NIC Front Side',
                            file: _nicFrontFile,
                            onTap: _pickNicFront,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildNicSelector(
                            title: 'NIC Back Side',
                            file: _nicBackFile,
                            onTap: _pickNicBack,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // SECTION 4: Terms & Escrow Collateral Agreement
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B2C).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.shield_outlined, color: Color(0xFFC084FC), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Escrow & Security Collateral Info',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'To maintain trust and protect sender cargo value, accepting a delivery request requires the traveler to lock a collateral deposit matching the package value (up to Rs. 5,000 max) in their escrow wallet. The collateral is automatically unlocked and returned immediately upon verified drop-off confirmation.',
                            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                          ),
                          const Divider(height: 20, color: Colors.white10),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'I understand and agree to hold up to Rs. 5000 in my wallet as escrow collateral when delivering packages.',
                              style: TextStyle(color: Colors.white, fontSize: 11, height: 1.3),
                            ),
                            value: _termsAccepted,
                            activeColor: const Color(0xFF10B981),
                            checkColor: Colors.white,
                            onChanged: (val) {
                              setState(() {
                                _termsAccepted = val ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Submission / Loading view
                    if (_scanningKyc) ...[
                      Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF10B981)),
                            const SizedBox(height: 16),
                            const Text(
                              'Verifying NIC Documents & Profile...',
                              style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text('Scanning image OCR biometrics...', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                          ],
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            disabledBackgroundColor: Colors.white.withOpacity(0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Complete Commuter Upgrade',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  InputDecoration _getInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
      filled: true,
      fillColor: const Color(0xFF1E1B2C),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildAutofilledField(String label, TextEditingController ctrl, IconData icon) {
    return TextFormField(
      controller: ctrl,
      enabled: false,
      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.grey, size: 18),
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.02)),
        ),
      ),
    );
  }

  Widget _buildNicSelector({required String title, required XFile? file, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1B2C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: file != null ? const Color(0xFF10B981) : Colors.white.withOpacity(0.05),
                width: file != null ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: file != null
                  ? Image.file(
                      File(file.path),
                      fit: BoxFit.cover,
                      width: double.infinity,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 30),
                          const SizedBox(height: 8),
                          Text(
                            'Upload Photo',
                            style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _showApplicationSuccessDialog(BuildContext context, String startCity, String destCity) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF161424),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withOpacity(0.1),
                  ),
                  child: const Icon(Icons.airport_shuttle_rounded, color: Color(0xFF10B981), size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Commuter Registered!',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Welcome to the PickO traveler commuter network!\n\nYour transit route is set from $startCity to $destCity. Traveler view is unlocked and matching shipments are waiting.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Pop dialog
                      Navigator.pop(context); // Pop commuter onboarding screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Enter Traveler View', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
