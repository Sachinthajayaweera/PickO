import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/mock_api_service.dart';
import '../../models/parcel.dart';
import '../../models/user.dart';
import 'parcel_handshake.dart';

class SenderDashboardScreen extends StatefulWidget {
  final VoidCallback onCreateParcelTab;
  const SenderDashboardScreen({Key? key, required this.onCreateParcelTab}) : super(key: key);

  @override
  State<SenderDashboardScreen> createState() => _SenderDashboardScreenState();
}

class _SenderDashboardScreenState extends State<SenderDashboardScreen> {
  Parcel? _selectedMatchingParcel;
  int _filterIndex = 0;

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<MockApiService>(context);
    final sender = apiService.currentUser;
    final wallet = apiService.getWallet(sender.id);
    final myParcels = apiService.parcels.where((p) => p.senderId == sender.id).toList();
    final sendParcels = myParcels.where((p) => p.status == ParcelStatus.matching).toList();
    final ongoingParcels = myParcels.where((p) => p.status == ParcelStatus.readyForPickup || p.status == ParcelStatus.inTransit).toList();
    final receivedParcels = myParcels.where((p) => p.status == ParcelStatus.delivered || p.status == ParcelStatus.stolen).toList();

    final List<Parcel> filteredParcels;
    if (_filterIndex == 0) {
      filteredParcels = sendParcels;
    } else if (_filterIndex == 1) {
      filteredParcels = ongoingParcels;
    } else {
      filteredParcels = receivedParcels;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17), // Deep space black/purple
      body: Stack(
        children: [
          // Background subtle gradients for modern premium look
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.05),
                    blurRadius: 80,
                    spreadRadius: 40,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Premium Custom Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF1E1B2C),
                                    backgroundImage: sender.avatarUrl != null && sender.avatarUrl!.isNotEmpty
                                        ? NetworkImage(sender.avatarUrl!.startsWith('http')
                                            ? sender.avatarUrl!
                                            : '${apiService.baseUrl}${sender.avatarUrl}')
                                        : null,
                                    child: sender.avatarUrl == null || sender.avatarUrl!.isEmpty
                                        ? const Icon(Icons.person_rounded, size: 24, color: Colors.grey)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Welcome back,',
                                          style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Outfit'),
                                        ),
                                        Text(
                                          sender.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // View Mode Toggle (Sender vs Traveler)
                            GestureDetector(
                              onTap: () => apiService.toggleViewMode(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: const Color(0xFF8B5CF6), width: 1.5),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.swap_horiz_rounded, color: Color(0xFFC084FC), size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Sender View',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        // Sender Profile & Trust Card (No wallet balance info)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2E1A47), Color(0xFF1E1B2C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Sender Profile Status',
                                    style: TextStyle(color: Colors.grey, fontSize: 13, fontFamily: 'Outfit'),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: const [
                                        Icon(Icons.verified_user_rounded, color: Colors.green, size: 12),
                                        SizedBox(width: 4),
                                        Text('KYC Verified', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Trust Score',
                                        style: TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Outfit'),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(sender.trustScore * 100).toStringAsFixed(0)}%',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 40),
                                  Container(width: 1, height: 35, color: Colors.white10),
                                  const SizedBox(width: 24),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Rating',
                                        style: TextStyle(color: Colors.grey, fontSize: 11, fontFamily: 'Outfit'),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${sender.rating} ★',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Active Shipments Header & Filters
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Parcels',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 15),
                        // Segmented control tabs
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161420),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withOpacity(0.04)),
                          ),
                          child: Row(
                            children: [
                              _buildFilterTab(0, 'Send Parcels', sendParcels.length),
                              _buildFilterTab(1, 'Ongoing', ongoingParcels.length),
                              _buildFilterTab(2, 'Received', receivedParcels.length),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Parcels List
                if (filteredParcels.isEmpty)
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B2C).withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Colors.grey[600], size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _filterIndex == 0 
                                ? 'No pending/matching parcels.' 
                                : _filterIndex == 1 
                                    ? 'No active/ongoing deliveries.' 
                                    : 'No received/completed parcels.',
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _filterIndex == 0
                                ? 'Tap "New Parcel" to crowdsource your delivery.'
                                : 'Accepted runs will display here.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          ),
                          if (_filterIndex == 0) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: widget.onCreateParcelTab,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Scaffold New Parcel', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final parcel = filteredParcels[index];
                        return _buildParcelCard(context, parcel, apiService);
                      },
                      childCount: filteredParcels.length,
                    ),
                  ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 100), // Spacing for floating navbar
                ),
              ],
            ),
          ),

          // Bottom Sheet Drawer for Trust-Aware Matching Algorithm visualization
          if (_selectedMatchingParcel != null)
            _buildMatchingDrawer(context, _selectedMatchingParcel!, apiService),
        ],
      ),
    );
  }

  Widget _buildParcelCard(BuildContext context, Parcel parcel, MockApiService apiService) {
    final statusColor = _getStatusColor(parcel.status);
    final categoryColor = _getCategoryColor(parcel.category);
    final traveler = parcel.travelerId != null
        ? apiService.users.firstWhere(
            (u) => u.id == parcel.travelerId,
            orElse: () => User(
              id: '',
              name: 'Commuter',
              isKycVerified: false,
              trustScore: 0.0,
              rating: 0.0,
              avatarUrl: null,
              isCommuter: true,
            ),
          )
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _selectedMatchingParcel?.id == parcel.id
              ? const Color(0xFF8B5CF6)
              : Colors.white.withOpacity(0.05),
          width: _selectedMatchingParcel?.id == parcel.id ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  parcel.category.displayName,
                  style: TextStyle(color: categoryColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  parcel.status.displayName,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            parcel.description,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 14),
              const SizedBox(width: 4),
              Text(
                '${parcel.pickupCity} → ${parcel.dropoffCity}',
                style: TextStyle(color: Colors.grey[400], fontSize: 13, fontFamily: 'Outfit'),
              ),
            ],
          ),
          if (parcel.status == ParcelStatus.delivered && traveler != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: const Color(0xFF1E1B2C),
                  backgroundImage: traveler.avatarUrl != null && traveler.avatarUrl!.isNotEmpty
                      ? NetworkImage(traveler.avatarUrl!.startsWith('http')
                          ? traveler.avatarUrl!
                          : '${apiService.baseUrl}${traveler.avatarUrl}')
                      : null,
                  child: traveler.avatarUrl == null || traveler.avatarUrl!.isEmpty
                      ? const Icon(Icons.person_rounded, size: 10, color: Colors.grey)
                      : null,
                ),
                const SizedBox(width: 6),
                Text(
                  'Delivered by: ${traveler.name}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'Outfit'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Liability Value', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('Rs. ${parcel.liabilityValue.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estimated Tip', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text('Rs. ${parcel.tipAmount.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
              // Action Buttons based on status
              if (parcel.status == ParcelStatus.matching)
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedMatchingParcel = parcel;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.psychology_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Matching', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else if (parcel.status == ParcelStatus.readyForPickup || parcel.status == ParcelStatus.inTransit)
                OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParcelHandshakeScreen(parcel: parcel),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.qr_code_2_rounded, size: 14),
                      SizedBox(width: 4),
                      Text('QR Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              else ...[
                if (parcel.status == ParcelStatus.delivered) ...[
                  if (parcel.ratingStars == null)
                    ElevatedButton(
                      onPressed: () => _showRatingDialog(context, parcel, apiService),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.star_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Text('Rate Delivery', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            return Icon(
                              Icons.star_rounded,
                              color: index < parcel.ratingStars! ? Colors.amber : Colors.white10,
                              size: 14,
                            );
                          }),
                        ),
                        if (parcel.feedbackText != null && parcel.feedbackText!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            parcel.feedbackText!,
                            style: TextStyle(color: Colors.grey[400], fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                ] else
                  Text(
                    'Refund Issued',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12, fontStyle: FontStyle.italic),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, Parcel parcel, MockApiService apiService) {
    int selectedStars = 5;
    final feedbackController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1B2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
              ),
              title: Column(
                children: [
                  const Icon(
                    Icons.rate_review_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Rate Delivery',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'How was your delivery for "${parcel.description}"?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        return IconButton(
                          icon: Icon(
                            Icons.star_rounded,
                            color: starValue <= selectedStars ? Colors.amber : Colors.white10,
                            size: 36,
                          ),
                          onPressed: () {
                            setState(() {
                              selectedStars = starValue;
                            });
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: feedbackController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Share feedback about the commuter or delivery (optional)...',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF161420),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF8B5CF6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setState(() {
                                  isSubmitting = true;
                                });
                                try {
                                  await apiService.rateDelivery(
                                    parcel.id,
                                    selectedStars,
                                    feedbackController.text,
                                  );
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Thank you! Rating submitted successfully.'),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                } catch (e) {
                                  setState(() {
                                    isSubmitting = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: ${e.toString()}'),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          disabledBackgroundColor: const Color(0xFF8B5CF6).withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Draw bottom sheet matching details
  Widget _buildMatchingDrawer(BuildContext context, Parcel parcel, MockApiService apiService) {
    final matches = apiService.simulateMatchingAlgorithm(parcel);

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMatchingParcel = null;
          });
        },
        child: Container(
          color: Colors.black54,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // Prevent tap through
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(
                  color: const Color(0xFF161424),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.85), blurRadius: 20, spreadRadius: 5),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Trust-Aware Matcher',
                            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () {
                              setState(() {
                                _selectedMatchingParcel = null;
                              });
                            },
                          )
                        ],
                      ),
                      Text(
                        'Algorithm matching for: "${parcel.description}"',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13, fontFamily: 'Outfit'),
                      ),
                      const SizedBox(height: 20),
                      Expanded(
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: matches.length,
                          itemBuilder: (context, idx) {
                            final match = matches[idx];
                            final traveler = match['traveler'] as User;
                            final bool isEligible = match['isEligible'] as bool;
                            final double score = match['dynamicScore'] as double;
                            final double distance = match['distance'] as double;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isEligible
                                    ? const Color(0xFF1E1B2C)
                                    : const Color(0xFF1A1A1A).withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isEligible
                                      ? const Color(0xFF8B5CF6).withOpacity(0.3)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: const Color(0xFF1E1B2C),
                                    backgroundImage: traveler.avatarUrl != null && traveler.avatarUrl!.isNotEmpty
                                        ? NetworkImage(traveler.avatarUrl!.startsWith('http')
                                            ? traveler.avatarUrl!
                                            : '${apiService.baseUrl}${traveler.avatarUrl}')
                                        : null,
                                    child: traveler.avatarUrl == null || traveler.avatarUrl!.isEmpty
                                        ? const Icon(Icons.person_rounded, size: 20, color: Colors.grey)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          traveler.name,
                                          style: TextStyle(
                                            color: isEligible ? Colors.white : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            fontFamily: 'Outfit',
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        // Steps verification flags
                                        Row(
                                          children: [
                                            _buildAlgorithmChip('Spatial (5km)', match['passesSpatial'], '${distance.toStringAsFixed(1)}km'),
                                            const SizedBox(width: 6),
                                            _buildAlgorithmChip('Route', match['passesRoute'], traveler.routeCity ?? '-'),
                                            const SizedBox(width: 6),
                                            _buildAlgorithmChip('Trust Gate', match['passesTrustGate'], traveler.formattedTrustScore),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'Match Score',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                      ),
                                      Text(
                                        '${(score * 100).toStringAsFixed(0)}',
                                        style: TextStyle(
                                          color: isEligible ? const Color(0xFFC084FC) : Colors.grey,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (isEligible)
                                        ElevatedButton(
                                          onPressed: () {
                                            // Assign parcel
                                            // Simulate traveler accepting it
                                            try {
                                              apiService.selectTraveler(traveler.id);
                                              apiService.acceptParcel(parcel.id);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Commuter ${traveler.name} assigned! Escrow locked.'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              setState(() {
                                                _selectedMatchingParcel = null;
                                              });
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
                                            backgroundColor: const Color(0xFF8B5CF6),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          child: const Text('Assign', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        const Text('Ineligible', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlgorithmChip(String label, bool passed, String details) {
    final color = passed ? const Color(0xFF10B981) : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        '$details ${passed ? '✓' : '✗'}',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getStatusColor(ParcelStatus status) {
    switch (status) {
      case ParcelStatus.matching:
        return const Color(0xFF3B82F6); // Blue
      case ParcelStatus.readyForPickup:
        return const Color(0xFFF59E0B); // Amber
      case ParcelStatus.inTransit:
        return const Color(0xFF8B5CF6); // Purple
      case ParcelStatus.delivered:
        return const Color(0xFF10B981); // Emerald
      case ParcelStatus.stolen:
        return const Color(0xFFEF4444); // Red
    }
  }

  Color _getCategoryColor(ParcelCategory category) {
    switch (category) {
      case ParcelCategory.categoryA:
        return Colors.white70;
      case ParcelCategory.categoryB:
        return const Color(0xFFF472B6); // Pink
      case ParcelCategory.categoryC:
        return const Color(0xFF60A5FA); // Blue
      case ParcelCategory.categoryD:
        return const Color(0xFFF59E0B); // Amber
    }
  }

  Widget _buildFilterTab(int index, String label, int count) {
    final isSelected = _filterIndex == index;
    final activeColor = const Color(0xFF8B5CF6);

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _filterIndex = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[400],
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 11,
                    fontFamily: 'Outfit',
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.2) : const Color(0xFF1E1B2C),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
