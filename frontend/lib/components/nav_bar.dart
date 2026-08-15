import 'package:flutter/material.dart';

class PickONavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isSender;

  const PickONavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.isSender,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Define tabs based on mode
    final items = isSender
        ? [
            _NavBarItem(icon: Icons.dashboard_rounded, label: 'Dashboard'),
            _NavBarItem(icon: Icons.add_circle_outline_rounded, label: 'New Parcel'),
            _NavBarItem(icon: Icons.person_rounded, label: 'Profile'),
          ]
        : [
            _NavBarItem(icon: Icons.explore_rounded, label: 'Explore Matches'),
            _NavBarItem(icon: Icons.airport_shuttle_rounded, label: 'My Runs'),
            _NavBarItem(icon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
          ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2C).withOpacity(0.95), // Premium Dark Violet Glassmorphism
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF6C63FF).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F0E17).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = currentIndex == index;
            final activeColor = isSender ? const Color(0xFF8B5CF6) : const Color(0xFF10B981); // Violet for Sender, Emerald for Traveler

            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: isSelected ? 18 : 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor.withOpacity(0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        item.icon,
                        color: isSelected ? activeColor : Colors.grey[400],
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? activeColor : Colors.grey[500],
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavBarItem {
  final IconData icon;
  final String label;

  _NavBarItem({required this.icon, required this.label});
}
