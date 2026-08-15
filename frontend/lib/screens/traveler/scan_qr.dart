import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/mock_api_service.dart';
import '../../models/parcel.dart';

class ScanQrScreen extends StatefulWidget {
  final Parcel parcel;

  const ScanQrScreen({Key? key, required this.parcel}) : super(key: key);

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> with SingleTickerProviderStateMixin {
  late AnimationController _scannerAnimationController;
  bool _qrScanned = false;
  bool _photoUploaded = false;
  String? _uploadedPhotoUrl;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _scannerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scannerAnimationController.dispose();
    super.dispose();
  }

  void _simulateQrScan() {
    setState(() {
      _isProcessing = true;
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      setState(() {
        _qrScanned = true;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digital Handshake QR Code Verified!'), backgroundColor: Colors.green),
      );
    });
  }

  void _simulatePhotoUpload() {
    setState(() {
      _isProcessing = true;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      setState(() {
        _photoUploaded = true;
        _uploadedPhotoUrl = 'https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=300'; // Sealed box mock
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Multipart photo of sealed package uploaded!'), backgroundColor: Colors.green),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<MockApiService>(context);
    final currentParcel = apiService.parcels.firstWhere((p) => p.id == widget.parcel.id, orElse: () => widget.parcel);
    final isPickup = currentParcel.status == ParcelStatus.readyForPickup;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isPickup ? 'Sealed Pickup Verification' : 'Drop-off Delivery Handshake',
          style: const TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Status bar info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161424),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Text(
                    currentParcel.description,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Liability Value: Rs. ${currentParcel.liabilityValue.toStringAsFixed(0)} | Tip: Rs. ${currentParcel.tipAmount.toStringAsFixed(0)}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Scanner Animation Box
            if (!_qrScanned) ...[
              const Text(
                'POSITION SENDER QR CODE IN FRAME',
                style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: _isProcessing ? null : _simulateQrScan,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                  ),
                  child: Stack(
                    children: [
                      // Scanner camera view simulation dots/lines
                      Center(
                        child: Icon(
                          Icons.qr_code_scanner_rounded,
                          color: Colors.white.withOpacity(0.2),
                          size: 100,
                        ),
                      ),
                      // Animated scanning line
                      AnimatedBuilder(
                        animation: _scannerAnimationController,
                        builder: (context, child) {
                          return Positioned(
                            top: 20 + (_scannerAnimationController.value * 190),
                            left: 20,
                            right: 20,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.8),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      // Corner brackets
                      _buildScannerCorners(),
                      if (_isProcessing)
                        const Center(
                          child: CircularProgressIndicator(color: Color(0xFF10B981)),
                        )
                      else
                        const Positioned(
                          bottom: 15,
                          left: 0,
                          right: 0,
                          child: Text(
                            'Tap to Simulate Scan',
                            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // QR Verified success box
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Handshake QR Verified', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          SizedBox(height: 2),
                          Text('Digital verification tokens match.', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 30),

            // Photo Seal upload (Pickup only)
            if (isPickup) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'STEP 2: PHOTO OF SEALED PACKAGE',
                  style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: (_isProcessing || _photoUploaded) ? null : _simulatePhotoUpload,
                child: Container(
                  width: double.infinity,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFF161424),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _photoUploaded ? const Color(0xFF10B981).withOpacity(0.3) : Colors.white.withOpacity(0.05),
                    ),
                    image: _photoUploaded && _uploadedPhotoUrl != null
                        ? DecorationImage(image: NetworkImage(_uploadedPhotoUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: _photoUploaded && _uploadedPhotoUrl != null
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                                SizedBox(width: 8),
                                Text('Package Photo Attached', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded, color: Colors.grey[500], size: 36),
                            const SizedBox(height: 10),
                            const Text('Simulate Sealed Package Upload', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Multipart form data simulation', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 35),
            ],

            // Action Buttons
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (!_qrScanned || (isPickup && !_photoUploaded) || _isProcessing)
                    ? null
                    : () async {
                        setState(() {
                          _isProcessing = true;
                        });
                        try {
                          if (isPickup) {
                            await apiService.pickupParcel(currentParcel.id, _uploadedPhotoUrl ?? '');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Transit started. Escrow holds secured.'), backgroundColor: Color(0xFF8B5CF6)),
                            );
                            Navigator.pop(context);
                          } else {
                            await apiService.deliverParcel(currentParcel.id);
                            _showDeliverySuccessDialog(context, currentParcel);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                          );
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isProcessing = false;
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  isPickup ? 'Confirm Pickup & Start Transit' : 'Verify Handshake & Complete Delivery',
                  style: TextStyle(
                    color: (!_qrScanned || (isPickup && !_photoUploaded)) ? Colors.grey[600] : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Report Stolen Button (For demonstrating theft penalty rules)
            if (!isPickup && currentParcel.status == ParcelStatus.inTransit) ...[
              const Divider(color: Colors.white10, height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () {
                    _showStolenReportConfirmDialog(context, apiService, currentParcel);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.gavel_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Report Lost / Stolen (Forfeits Escrow)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerCorners() {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: CustomPaint(
          painter: _ScannerBorderPainter(),
        ),
      ),
    );
  }

  void _showDeliverySuccessDialog(BuildContext context, Parcel parcel) {
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
                  child: const Icon(Icons.celebration_rounded, color: Color(0xFF10B981), size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Run Complete!',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your locked escrow of Rs. ${parcel.liabilityValue.toStringAsFixed(0)} has been refunded.\nYour delivery tip of Rs. ${parcel.tipAmount.toStringAsFixed(0)} has been credited!',
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
                      Navigator.pop(context); // Pop scanner screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showStolenReportConfirmDialog(BuildContext context, MockApiService apiService, Parcel parcel) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF161424),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirm Stolen Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'WARNING: Reporting this package as stolen will immediately deduct the locked escrow of Rs. ${parcel.liabilityValue.toStringAsFixed(0)} from your wallet and credit it to the sender. This action is irreversible.',
            style: TextStyle(color: Colors.grey[300], fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await apiService.reportStolen(parcel.id);
                  Navigator.pop(context); // Pop confirm dialog
                  Navigator.pop(context); // Pop scan screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Penalty applied. Escrow transferred to sender.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } catch (e) {
                  Navigator.pop(context); // Pop confirm dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Report Stolen & Deduct', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class _ScannerBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const double length = 20;

    // Top Left
    canvas.drawLine(const Offset(0, 0), const Offset(0, length), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(length, 0), paint);

    // Top Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - length, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);

    // Bottom Left
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - length), paint);
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);

    // Bottom Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - length, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
