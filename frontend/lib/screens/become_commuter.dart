import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/mock_api_service.dart';

class BecomeCommuterScreen extends StatefulWidget {
  const BecomeCommuterScreen({Key? key}) : super(key: key);

  @override
  State<BecomeCommuterScreen> createState() => _BecomeCommuterScreenState();
}

class _BecomeCommuterScreenState extends State<BecomeCommuterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _routeCityController = TextEditingController(text: 'New York');
  bool _scanningKyc = false;
  bool _kycVerified = false;

  @override
  void dispose() {
    _routeCityController.dispose();
    super.dispose();
  }

  void _simulateKycScan() {
    setState(() {
      _scanningKyc = true;
    });
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        setState(() {
          _scanningKyc = false;
          _kycVerified = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simulated KYC verification successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<MockApiService>(context, listen: false);

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
          // Background Glows
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
                    color: const Color(0xFF10B981).withOpacity(0.08),
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
              padding: const EdgeInsets.all(24.0),
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
                      'Unlock matching runs and start earning tips on your transit routes.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    const SizedBox(height: 30),

                    // Route details
                    _buildSectionHeader('YOUR DESTINATION TRANSIT CITY'),
                    TextFormField(
                      controller: _routeCityController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'e.g. New York, Boston',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
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
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your destination city';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Note: The PostGIS matching service will query parcels dropping off in this city.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 30),

                    // KYC Document upload simulation
                    _buildSectionHeader('KYC DOCUMENT VERIFICATION'),
                    GestureDetector(
                      onTap: (_scanningKyc || _kycVerified) ? null : _simulateKycScan,
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B2C),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _kycVerified
                                ? const Color(0xFF10B981)
                                : (_scanningKyc ? const Color(0xFFF59E0B) : Colors.white.withOpacity(0.05)),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_scanningKyc) ...[
                                  const CircularProgressIndicator(color: Color(0xFFF59E0B)),
                                  const SizedBox(height: 14),
                                  const Text(
                                    'Simulating Document Scanning...',
                                    style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Running facial biometrics...', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                ] else if (_kycVerified) ...[
                                  const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 48),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Document Verified!',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'National ID & Photo Verification Completed ✓',
                                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ] else ...[
                                  const Icon(Icons.badge_outlined, color: Colors.grey, size: 48),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Upload Passport or Driver License',
                                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap to trigger simulated KYC scan',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 35),

                    // Submit application button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (!_kycVerified)
                            ? null
                            : () async {
                                if (_formKey.currentState!.validate()) {
                                  try {
                                    await apiService.registerAsCommuter(
                                      _routeCityController.text.trim(),
                                      simulatedKyc: _kycVerified,
                                    );
                                    _showApplicationSuccessDialog(context, _routeCityController.text.trim());
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(e.toString()),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          disabledBackgroundColor: Colors.white.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _kycVerified ? 'Complete Commuter Upgrade' : 'Verify KYC to Submit',
                          style: TextStyle(
                            color: _kycVerified ? Colors.white : Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
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
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white60,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  void _showApplicationSuccessDialog(BuildContext context, String routeCity) {
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
                  'Welcome to the PickO commuter network!\n\nYour transit route is set to $routeCity. Traveler View has been unlocked and matched runs are waiting.',
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
