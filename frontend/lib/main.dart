import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'services/mock_api_service.dart';
import 'models/user.dart';
import 'components/nav_bar.dart';
import 'screens/sender/sender_dashboard.dart';
import 'screens/sender/create_parcel.dart';
import 'screens/traveler/traveler_dashboard.dart';
import 'screens/registration.dart';
import 'screens/become_commuter.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => MockApiService(),
      child: const PickOApp(),
    ),
  );
}

class PickOApp extends StatelessWidget {
  const PickOApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PickO Logistics',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0E17),
        primaryColor: const Color(0xFF8B5CF6), // Violet
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF10B981), // Emerald
          surface: Color(0xFF1E1B2C),
          background: Color(0xFF0F0E17),
          error: Colors.redAccent,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontFamily: 'Outfit'),
          bodyMedium: TextStyle(fontFamily: 'Outfit'),
        ),
      ),
      home: const MainTabsContainer(),
    );
  }
}

class MainTabsContainer extends StatefulWidget {
  const MainTabsContainer({Key? key}) : super(key: key);

  @override
  State<MainTabsContainer> createState() => _MainTabsContainerState();
}

class _MainTabsContainerState extends State<MainTabsContainer> {
  int _senderTabIndex = 0;
  int _travelerTabIndex = 0;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final apiService = Provider.of<MockApiService>(context, listen: false);
    await apiService.tryAutoLogin();
    if (mounted) {
      setState(() {
        _isCheckingAuth = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0E17),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8B5CF6)),
        ),
      );
    }

    final apiService = Provider.of<MockApiService>(context);
    
    // Check registration gate
    if (!apiService.isRegistered) {
      return const RegistrationScreen();
    }

    final isSender = apiService.isSenderView;
    final currentTab = isSender ? _senderTabIndex : _travelerTabIndex;

    // Screens list for Sender
    final List<Widget> senderScreens = [
      SenderDashboardScreen(
        onCreateParcelTab: () {
          setState(() {
            _senderTabIndex = 1; // Switch to Create tab
          });
        },
      ),
      CreateParcelScreen(
        onParcelCreated: () {
          setState(() {
            _senderTabIndex = 0; // Back to Dashboard
          });
        },
      ),
      const WalletProfileTab(),
    ];

    // Screens list for Traveler
    final List<Widget> travelerScreens = [
      TravelerDashboardScreen(
        activeTab: 0, // Explore
        onTabChanged: (idx) {
          setState(() {
            _travelerTabIndex = idx;
          });
        },
      ),
      TravelerDashboardScreen(
        activeTab: 1, // My Runs
        onTabChanged: (idx) {
          setState(() {
            _travelerTabIndex = idx;
          });
        },
      ),
      const WalletProfileTab(),
    ];

    final currentScreen = isSender 
        ? senderScreens[_senderTabIndex] 
        : travelerScreens[_travelerTabIndex];

    return Scaffold(
      body: currentScreen,
      bottomNavigationBar: PickONavBar(
        currentIndex: currentTab,
        isSender: isSender,
        onTap: (index) {
          setState(() {
            if (isSender) {
              _senderTabIndex = index;
            } else {
              _travelerTabIndex = index;
            }
          });
        },
      ),
    );
  }
}

// Wallet Profile Tab Component (Shared by both Views)
class WalletProfileTab extends StatelessWidget {
  const WalletProfileTab({Key? key}) : super(key: key);

  void _showEditProfileDialog(BuildContext context, MockApiService apiService, User user) {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController(text: user.username ?? user.name);
    final emailController = TextEditingController(text: user.email ?? '');
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');

    var localUser = user;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1B2C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Avatar Upload Section
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: const Color(0xFF151424),
                            backgroundImage: localUser.avatarUrl != null && localUser.avatarUrl!.isNotEmpty
                                ? NetworkImage(localUser.avatarUrl!.startsWith('http')
                                    ? localUser.avatarUrl!
                                    : '${apiService.baseUrl}${localUser.avatarUrl}')
                                : null,
                            child: localUser.avatarUrl == null || localUser.avatarUrl!.isEmpty
                                ? const Icon(Icons.person_rounded, size: 40, color: Colors.grey)
                                : null,
                          ),
                          InkWell(
                            onTap: () async {
                              try {
                                final picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 80,
                                );
                                if (image != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Uploading profile picture...')),
                                  );
                                  await apiService.uploadAvatar(image.path);
                                  setDialogState(() {
                                    localUser = apiService.currentUser;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Profile picture updated successfully!')),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error uploading photo: ${e.toString()}')),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF8B5CF6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: usernameController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Enter a username' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: emailController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                        ),
                        validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF8B5CF6))),
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Enter phone number' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        await apiService.updateProfile(
                          usernameController.text.trim(),
                          emailController.text.trim(),
                          phoneController.text.trim(),
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                  child: const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showLogoutConfirmDialog(BuildContext context, MockApiService apiService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Log Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          content: const Text('Are you sure you want to log out of your session?', style: TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await apiService.logout();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('Log Out', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, MockApiService apiService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1B2C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Profile', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          content: const Text(
            'WARNING: This action is permanent. Deleting your profile will wipe all your balance, active/past parcels, and scanning audit histories from the database.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  Navigator.pop(context);
                  await apiService.deleteProfile();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Your account has been deleted.'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<MockApiService>(context);
    final user = apiService.currentUser;
    final wallet = apiService.getWallet(user.id);
    final themeColor = apiService.isSenderView ? const Color(0xFF8B5CF6) : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Stack(
        children: [
          // Background subtle blur glow
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeColor.withOpacity(0.1),
                    blurRadius: 80,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // User Avatar & KYC Badge
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF1E1B2C),
                        backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                            ? NetworkImage(user.avatarUrl!.startsWith('http')
                                ? user.avatarUrl!
                                : '${apiService.baseUrl}${user.avatarUrl}')
                            : null,
                        child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                            ? const Icon(Icons.person_rounded, size: 50, color: Colors.grey)
                            : null,
                      ),
                      if (user.isKycVerified)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 16),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.username ?? user.name,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${user.rating} Rating  •  ${(user.trustScore * 100).toStringAsFixed(0)}% Trust Score',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  if (!apiService.isSenderView) ...[
                    // Wallet Details Panel
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B2C),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'PICKO ESCROW WALLET',
                            style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Available Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Text(
                                'Rs. ${wallet.availableBalance.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Locked Escrow Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                              Text(
                                'Rs. ${wallet.lockedEscrowBalance.toStringAsFixed(2)}',
                                style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 25),
                          // Simulate deposit buttons to fund escrow for the demo
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await apiService.depositMockFunds(user.id, 5000.0);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Deposited Rs. 5,000.00 mock funds!'), backgroundColor: Colors.green),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: themeColor,
                                    side: BorderSide(color: themeColor),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('+ Rs. 5,000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Commuter Application Call To Action Banner
                  if (!user.isCommuter)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F3A2E), Color(0xFF1E1B2C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EARN ON YOUR COMMUTE',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Become a PickO Commuter',
                            style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Verify your KYC credentials, register your usual transit routes, and start locking escrow to pick up packages and earn tips.',
                            style: TextStyle(color: Colors.grey[400], fontSize: 11, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const BecomeCommuterScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.assignment_ind_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text(
                                    'Apply to Deliver',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Account Operations Panel
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2C),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACCOUNT MANAGEMENT',
                          style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 16),
                        
                        // Edit Profile Option
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.edit_outlined, color: Color(0xFF8B5CF6), size: 20),
                          ),
                          title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Modify username, email, phone', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: () => _showEditProfileDialog(context, apiService, user),
                        ),
                        const Divider(color: Colors.white10),
                        
                        // Log Out Option
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.logout_rounded, color: Colors.orange, size: 20),
                          ),
                          title: const Text('Log Out', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Sign out of your active session', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: () => _showLogoutConfirmDialog(context, apiService),
                        ),
                        const Divider(color: Colors.white10),
                        
                        // Delete Profile Option
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent, size: 20),
                          ),
                          title: const Text('Delete Profile', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: const Text('Permanently remove all user data', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          onTap: () => _showDeleteConfirmDialog(context, apiService),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // KYC verification display info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161424),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.02)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'PickO secures all transactions in a PostGIS-enabled escrow matching system. Senders lock transit tips, and travelers deposit liability value to secure cargo.',
                            style: TextStyle(color: Colors.grey[500], fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
