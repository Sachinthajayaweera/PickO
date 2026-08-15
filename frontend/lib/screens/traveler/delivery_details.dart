import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/mock_api_service.dart';
import '../../models/parcel.dart';

class DeliveryDetailsScreen extends StatelessWidget {
  final Parcel parcel;

  const DeliveryDetailsScreen({Key? key, required this.parcel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<MockApiService>(context);
    final traveler = apiService.currentUser;
    final wallet = apiService.getWallet(traveler.id);

    final isTrustGated = traveler.trustScore < parcel.category.requiredTrustScore;
    final hasFunds = wallet.availableBalance >= parcel.liabilityValue;
    final categoryColor = _getCategoryColor(parcel.category);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Package Run Details', style: TextStyle(color: Colors.white, fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Subtle glow
          Positioned(
            top: 200,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    parcel.category.displayName,
                    style: TextStyle(color: categoryColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  parcel.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 10),

                // Location Route Cards
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161424),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.circle_outlined, color: Color(0xFF10B981), size: 16),
                          Container(width: 2, height: 40, color: Colors.white10),
                          const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 16),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PICKUP FROM', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(parcel.pickupCity, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            const Text('DROPOFF TO', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(parcel.dropoffCity, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (parcel.receiverName != null && parcel.receiverName!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161424),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RECEIVER DETAILS',
                          style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 10),
                            Text(
                              parcel.receiverName!,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (parcel.receiverPhone != null && parcel.receiverPhone!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, color: Color(0xFF10B981), size: 18),
                              const SizedBox(width: 10),
                              Text(
                                parcel.receiverPhone!,
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Financial Overview Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildFinancialCard(
                        'COMMUTER TIP',
                        'Rs. ${parcel.tipAmount.toStringAsFixed(0)}',
                        const Color(0xFF10B981),
                        Icons.payments_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildFinancialCard(
                        'LIABILITY ESCROW',
                        'Rs. ${parcel.liabilityValue.toStringAsFixed(0)}',
                        const Color(0xFFF59E0B),
                        Icons.shield_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Gating Checklist
                const Text(
                  'COMPLIANCE CHECKLIST',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                _buildChecklistItem(
                  'KYC Verification Status',
                  traveler.isKycVerified ? 'Verified ✓' : 'Unverified ✗',
                  traveler.isKycVerified,
                ),
                _buildChecklistItem(
                  'Required Trust Score (${(parcel.category.requiredTrustScore * 100).toStringAsFixed(0)}% Required)',
                  'Your Score: ${traveler.formattedTrustScore}',
                  !isTrustGated,
                ),
                _buildChecklistItem(
                  'Required Escrow Funds in Wallet',
                  'Available: Rs. ${wallet.availableBalance.toStringAsFixed(0)}',
                  hasFunds,
                ),
                const SizedBox(height: 24),

                // Escrow Locked Warning Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Escrow Wallet Lock Warning',
                              style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Accepting this package will lock Rs. ${parcel.liabilityValue.toStringAsFixed(0)} in your escrow balance. It will be released plus your tip of Rs. ${parcel.tipAmount.toStringAsFixed(0)} immediately upon successful delivery QR verification.',
                              style: TextStyle(color: Colors.grey[400], fontSize: 11, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 35),

                // Accept Run Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (isTrustGated || !hasFunds)
                        ? null
                        : () async {
                            try {
                              await apiService.acceptParcel(parcel.id);
                              _showSuccessDialog(context, parcel);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      disabledBackgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      shadowColor: const Color(0xFF10B981).withOpacity(0.2),
                    ),
                    child: Text(
                      isTrustGated
                          ? 'Trust Score Too Low'
                          : (!hasFunds ? 'Insufficient Wallet Funds' : 'Lock Escrow & Accept Run'),
                      style: TextStyle(
                        color: (isTrustGated || !hasFunds) ? Colors.grey[600] : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withOpacity(0.8), size: 16),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, String details, bool isMet) {
    final color = isMet ? const Color(0xFF10B981) : Colors.redAccent;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 2),
              Text(details, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color,
            size: 18,
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, Parcel parcel) {
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
                  child: const Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 48),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Escrow Secured!',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 10),
                Text(
                  'Rs. ${parcel.liabilityValue.toStringAsFixed(0)} has been locked in escrow.\nProceed to the sender\'s location to scan the pickup QR code.',
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
                      Navigator.pop(context); // Pop details screen
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Go to My Runs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getCategoryColor(ParcelCategory category) {
    switch (category) {
      case ParcelCategory.categoryA:
        return Colors.white70;
      case ParcelCategory.categoryB:
        return const Color(0xFFF472B6);
      case ParcelCategory.categoryC:
        return const Color(0xFF60A5FA);
      case ParcelCategory.categoryD:
        return const Color(0xFFF59E0B);
    }
  }
}
