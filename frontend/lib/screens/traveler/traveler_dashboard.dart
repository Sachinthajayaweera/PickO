import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/mock_api_service.dart';
import '../../models/parcel.dart';
import 'delivery_details.dart';
import 'scan_qr.dart';

class TravelerDashboardScreen extends StatelessWidget {
  final int activeTab; // 0 for Explore, 1 for My Runs
  final Function(int) onTabChanged;

  const TravelerDashboardScreen({
    Key? key,
    required this.activeTab,
    required this.onTabChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<MockApiService>(context);
    final traveler = apiService.currentUser;
    final wallet = apiService.getWallet(traveler.id);

    // Filter parcels
    final availableParcels = apiService.parcels.where((p) => p.status == ParcelStatus.matching).toList();
    final myRuns = apiService.parcels.where((p) => p.travelerId == traveler.id).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.12), // Green glow for Traveler
                    blurRadius: 100,
                    spreadRadius: 50,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header & Toggles
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: const Color(0xFF1E1B2C),
                                  backgroundImage: traveler.avatarUrl != null && traveler.avatarUrl!.isNotEmpty
                                      ? NetworkImage(traveler.avatarUrl!.startsWith('http')
                                          ? traveler.avatarUrl!
                                          : '${apiService.baseUrl}${traveler.avatarUrl}')
                                      : null,
                                  child: traveler.avatarUrl == null || traveler.avatarUrl!.isEmpty
                                      ? const Icon(Icons.person_rounded, size: 24, color: Colors.grey)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Active Commuter,',
                                      style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Outfit'),
                                    ),
                                    Text(
                                      traveler.name,
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
                            // View Toggle Button
                            GestureDetector(
                              onTap: () => apiService.toggleViewMode(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: const Color(0xFF10B981), width: 1.5),
                                ),
                                child: Row(
                                  children: const [
                                    Icon(Icons.swap_horiz_rounded, color: Color(0xFF34D399), size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Traveler View',
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
                        const SizedBox(height: 15),

                        // Dropdown to change simulated commuter profile
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B2C),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Simulate Commuter Profile:',
                                style: TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Outfit'),
                              ),
                              DropdownButton<String>(
                                value: traveler.id,
                                dropdownColor: const Color(0xFF161424),
                                underline: const SizedBox(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                items: apiService.users
                                    .where((u) => u.id.startsWith('traveler_'))
                                    .map((u) => DropdownMenuItem(
                                          value: u.id,
                                          child: Text(u.name.replaceAll(' (Commuter)', '')),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    apiService.selectTraveler(val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Wallet Escrow Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF122E25), Color(0xFF161424)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'COMMUTER ESCROW WALLET',
                                    style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 12),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Trust Score: ${traveler.formattedTrustScore}',
                                          style: const TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Available Balance', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rs. ${wallet.availableBalance.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 40, color: Colors.white10),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Locked Escrow', style: TextStyle(color: Colors.grey, fontSize: 11)),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Rs. ${wallet.lockedEscrowBalance.toStringAsFixed(2)}',
                                          style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                        ),
                                      ],
                                    ),
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

                // Main Content depending on Tab
                if (activeTab == 0) ...[
                  // EXPLORE MATCHES
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Available Packages (Route: ${traveler.routeCity ?? 'All'})',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    ),
                  ),
                  if (availableParcels.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyState(Icons.explore_outlined, 'No packages currently waiting for delivery.'),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final parcel = availableParcels[index];
                          final isGated = traveler.trustScore < parcel.category.requiredTrustScore;
                          return _buildExploreCard(context, parcel, isGated, apiService);
                        },
                        childCount: availableParcels.length,
                      ),
                    ),
                ] else ...[
                  // MY ACTIVE RUNS
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Text(
                        'Your Active Shipments',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    ),
                  ),
                  if (myRuns.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyState(Icons.directions_run_rounded, 'You have no accepted deliveries at the moment.'),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final parcel = myRuns[index];
                          return _buildActiveRunCard(context, parcel);
                        },
                        childCount: myRuns.length,
                      ),
                    ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2C).withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.grey[600], size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExploreCard(BuildContext context, Parcel parcel, bool isGated, MockApiService apiService) {
    final themeColor = isGated ? Colors.grey : const Color(0xFF10B981);
    final categoryColor = _getCategoryColor(parcel.category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGated ? Colors.transparent : themeColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: categoryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  parcel.category.displayName,
                  style: TextStyle(color: categoryColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              if (isGated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'Requires ${(parcel.category.requiredTrustScore * 100).toStringAsFixed(0)}% Trust',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'Route Match ✓',
                  style: TextStyle(color: Colors.greenAccent[400], fontSize: 10, fontWeight: FontWeight.bold),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            parcel.description,
            style: TextStyle(
              color: isGated ? Colors.grey[500] : Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 13),
              const SizedBox(width: 4),
              Text(
                '${parcel.pickupCity} → ${parcel.dropoffCity}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Liability Escrow', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text(
                    'Rs. ${parcel.liabilityValue.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isGated ? Colors.grey : Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Commuter Tip', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text(
                    'Rs. ${parcel.tipAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isGated ? Colors.grey : const Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: isGated
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeliveryDetailsScreen(parcel: parcel),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  disabledBackgroundColor: Colors.white.withOpacity(0.05),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  isGated ? 'Gated' : 'View Run',
                  style: TextStyle(
                    color: isGated ? Colors.grey[600] : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRunCard(BuildContext context, Parcel parcel) {
    final statusColor = _getStatusColor(parcel.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                parcel.category.displayName,
                style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  parcel.status.displayName,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            parcel.description,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Colors.redAccent, size: 13),
              const SizedBox(width: 4),
              Text(
                '${parcel.pickupCity} → ${parcel.dropoffCity}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Escrow Locked', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text(
                    'Rs. ${parcel.liabilityValue.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your Tip', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text(
                    'Rs. ${parcel.tipAmount.toStringAsFixed(0)}',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (parcel.status == ParcelStatus.readyForPickup || parcel.status == ParcelStatus.inTransit)
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ScanQrScreen(parcel: parcel),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        parcel.status == ParcelStatus.readyForPickup ? Icons.camera_alt_rounded : Icons.qr_code_scanner_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        parcel.status == ParcelStatus.readyForPickup ? 'Pickup' : 'Deliver',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  parcel.status == ParcelStatus.delivered ? 'Completed' : 'Stolen / Penalized',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ],
      ),
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
