import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/mock_api_service.dart';
import '../../models/parcel.dart';

class ParcelHandshakeScreen extends StatelessWidget {
  final Parcel parcel;

  const ParcelHandshakeScreen({Key? key, required this.parcel}) : super(key: key);

  Future<void> _shareToWhatsApp(BuildContext context, Parcel parcel) async {
    final message = "PickO Handshake verification code for package:\n"
        "📦 *${parcel.description}*\n"
        "📍 Route: ${parcel.pickupCity} ➔ ${parcel.dropoffCity}\n"
        "🔑 Verification Code: ${parcel.qrCodeData}\n\n"
        "Please present this code/QR to the commuter during handover to verify delivery.";
    final url = Uri.parse("https://wa.me/?text=${Uri.encodeComponent(message)}");
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch WhatsApp. Make sure it is installed.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sharing: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apiService = Provider.of<MockApiService>(context);
    
    // Find latest parcel status from state
    final currentParcel = apiService.parcels.firstWhere((p) => p.id == parcel.id, orElse: () => parcel);
    final statusColor = _getStatusColor(currentParcel.status);

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
          'Digital Handshake QR',
          style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Package details header card
              Container(
                width: double.infinity,
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
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${currentParcel.pickupCity} → ${currentParcel.dropoffCity}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        currentParcel.status.displayName.toUpperCase(),
                        style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // QR Code Container
              if (currentParcel.status == ParcelStatus.readyForPickup || currentParcel.status == ParcelStatus.inTransit) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withOpacity(0.15),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: currentParcel.qrCodeData ?? 'carry_mate_handshake',
                    version: QrVersions.auto,
                    size: 200.0,
                    foregroundColor: const Color(0xFF0F0E17),
                  ),
                ),
                const SizedBox(height: 25),
                const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF8B5CF6), size: 32),
                const SizedBox(height: 12),
                Text(
                  currentParcel.status == ParcelStatus.readyForPickup
                      ? 'Show this QR to the commuter during PICKUP'
                      : 'Show this QR to the commuter during DROPOFF',
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  currentParcel.status == ParcelStatus.readyForPickup
                      ? 'They must scan this QR and upload a sealed photo to begin transit.'
                      : 'They must scan this QR to complete delivery and unlock their escrow.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _shareToWhatsApp(context, currentParcel),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share Verification Code to WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ] else if (currentParcel.status == ParcelStatus.delivered) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFF10B981), width: 2),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 80),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Delivery Confirmed!',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 8),
                Text(
                  'The commuter has successfully delivered this package.\nTip of Rs. ${currentParcel.tipAmount.toStringAsFixed(0)} paid.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ] else if (currentParcel.status == ParcelStatus.stolen) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.1),
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: const Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 80),
                ),
                const SizedBox(height: 25),
                const Text(
                  'Liability Claim Settled',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 8),
                Text(
                  'This shipment was reported stolen.\nRs. ${currentParcel.liabilityValue.toStringAsFixed(0)} has been deducted from the traveler\'s escrow and credited to your wallet.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.matching:
        return const Color(0xFF3B82F6);
      case ParcelStatus.readyForPickup:
        return const Color(0xFFF59E0B);
      case ParcelStatus.inTransit:
        return const Color(0xFF8B5CF6);
      case ParcelStatus.delivered:
        return const Color(0xFF10B981);
      case ParcelStatus.stolen:
        return const Color(0xFFEF4444);
    }
  }
}
