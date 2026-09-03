import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/wallet.dart';
import '../models/parcel.dart';

class MockApiService extends ChangeNotifier {
  // Configures base URL dynamically for localhost/Android emulator compatibility
  String get baseUrl {
    if (kIsWeb) return 'http://localhost:8080';
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:8080';
      }
    } catch (_) {}
    return 'http://localhost:8080';
  }

  final List<User> _users = [];
  final Map<String, Wallet> _wallets = {};
  final List<Parcel> _parcels = [];

  String? _token;

  User _currentUser = User(
    id: '00000000-0000-0000-0000-000000000001',
    name: 'Alice (Sender)',
    isKycVerified: true,
    trustScore: 0.0,
    rating: 0.0,
    avatarUrl: null,
    isCommuter: false,
  );
  bool _isSenderView = true;
  bool _isRegistered = false;
  late String _selectedTravelerId;
  String? _currentUserId;

  MockApiService() {
    _selectedTravelerId = '00000000-0000-0000-0000-000000000002'; // default Bob
    init();
  }

  Future<void> init() async {
    await refreshState();
  }

  // Getters
  List<User> get users => _users;
  List<Parcel> get parcels => _parcels;
  User get currentUser => _currentUser;
  bool get isSenderView => _isSenderView;
  bool get isRegistered => _isRegistered;
  String get selectedTravelerId => _selectedTravelerId;

  User? getUser(String userId) {
    try {
      return _users.firstWhere((u) => u.id == userId);
    } catch (_) {
      return null;
    }
  }

  Future<User?> fetchUser(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/users/$userId'));
      if (response.statusCode == 200) {
        final u = json.decode(response.body);
        final user = User(
          id: u['id'],
          name: u['name'],
          username: u['username'],
          email: u['email'],
          phoneNumber: u['phone_number'],
          isKycVerified: u['kyc_verified_status'] ?? false,
          trustScore: (u['trust_score'] as num).toDouble() / 100.0,
          rating: (u['rating'] as num).toDouble(),
          avatarUrl: u['avatarUrl'],
          isCommuter: u['is_commuter'] ?? true,
          routeCity: u['route_city'],
        );
        final idx = _users.indexWhere((existing) => existing.id == user.id);
        if (idx != -1) {
          _users[idx] = user;
        } else {
          _users.add(user);
        }
        notifyListeners();
        return user;
      }
    } catch (_) {}
    return getUser(userId);
  }

  // Map category string from DB to enum
  ParcelCategory _mapCategory(String cat) {
    switch (cat) {
      case 'A':
        return ParcelCategory.categoryA;
      case 'B':
        return ParcelCategory.categoryB;
      case 'C':
        return ParcelCategory.categoryC;
      case 'D':
        return ParcelCategory.categoryD;
      default:
        return ParcelCategory.categoryA;
    }
  }

  String _mapCategoryToString(ParcelCategory cat) {
    switch (cat) {
      case ParcelCategory.categoryA:
        return 'A';
      case ParcelCategory.categoryB:
        return 'B';
      case ParcelCategory.categoryC:
        return 'C';
      case ParcelCategory.categoryD:
        return 'D';
    }
  }

  // Map status string from DB to enum
  ParcelStatus _mapStatus(String status) {
    switch (status) {
      case 'Pending':
        return ParcelStatus.matching;
      case 'Accepted':
        return ParcelStatus.readyForPickup;
      case 'In Transit':
        return ParcelStatus.inTransit;
      case 'Delivered':
        return ParcelStatus.delivered;
      case 'Stolen':
        return ParcelStatus.stolen;
      default:
        return ParcelStatus.matching;
    }
  }

  Future<void> refreshState() async {
    try {
      final usersResponse = await http.get(Uri.parse('$baseUrl/api/users'));
      if (usersResponse.statusCode == 200) {
        final List<dynamic> usersData = json.decode(usersResponse.body);
        _users.clear();
        for (var u in usersData) {
          final user = User(
            id: u['id'],
            name: u['name'],
            username: u['username'],
            email: u['email'],
            phoneNumber: u['phone_number'],
            isKycVerified: u['kyc_verified_status'],
            trustScore: (u['trust_score'] as num).toDouble() / 100.0,
            rating: (u['rating'] as num).toDouble(),
            avatarUrl: u['avatarUrl'],
            isCommuter: u['is_commuter'],
            routeCity: u['route_city'],
          );
          _users.add(user);

          // Fetch wallet
          final walletResponse = await http.get(Uri.parse('$baseUrl/api/wallets/${user.id}'));
          if (walletResponse.statusCode == 200) {
            final w = json.decode(walletResponse.body);
            _wallets[user.id] = Wallet(
              userId: w['user_id'],
              availableBalance: (w['available_balance'] as num).toDouble(),
              lockedEscrowBalance: (w['locked_escrow_balance'] as num).toDouble(),
            );
          }
        }
      }

      final parcelsResponse = await http.get(Uri.parse('$baseUrl/api/parcels'));
      if (parcelsResponse.statusCode == 200) {
        final List<dynamic> parcelsData = json.decode(parcelsResponse.body);
        _parcels.clear();
        for (var p in parcelsData) {
          _parcels.add(Parcel(
            id: p['id'],
            senderId: p['senderId'],
            travelerId: p['travelerId'],
            category: _mapCategory(p['category']),
            liabilityValue: (p['liabilityValue'] as num).toDouble(),
            status: _mapStatus(p['status']),
            pickupCity: p['pickupCity'],
            dropoffCity: p['dropoffCity'],
            pickupLat: (p['pickupLat'] as num).toDouble(),
            pickupLng: (p['pickupLng'] as num).toDouble(),
            dropoffLat: (p['dropoffLat'] as num).toDouble(),
            dropoffLng: (p['dropoffLng'] as num).toDouble(),
            description: p['description'],
            tipAmount: (p['tipAmount'] as num).toDouble(),
            qrCodeData: p['qrCodeData'],
            photoUrl: p['photoUrl'],
            createdAt: DateTime.parse(p['createdAt']),
            ratingStars: p['ratingStars'],
            feedbackText: p['feedbackText'],
            receiverName: p['receiverName'],
            receiverPhone: p['receiverPhone'],
            requestedTravelerId: p['requestedTravelerId'],
          ));
        }
      }

      // Update current user references
      if (_users.isNotEmpty) {
        if (_currentUserId != null) {
          _currentUser = _users.firstWhere((u) => u.id == _currentUserId, orElse: () => _users.first);
        } else {
          _currentUser = _users.firstWhere((u) => u.name.contains('Alice'), orElse: () => _users.first);
          _currentUserId = _currentUser.id;
        }
        
        // Update registration flag
        _isRegistered = _users.any((u) => u.id == _currentUserId && !u.id.startsWith('00000000-0000-0000-0000-00000000000'));
      }

      notifyListeners();
    } catch (e) {
      print("Error refreshing state: $e");
    }
  }

  Future<void> tryAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey('token')) return;
      _token = prefs.getString('token');
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/me'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final userData = json.decode(response.body);
        _currentUserId = userData['id'];
        _isRegistered = true;
        await refreshState();
      } else {
        await logout();
      }
    } catch (e) {
      print("Error during auto-login: $e");
    }
  }

  Future<void> login(String loginIdentifier, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username_or_email': loginIdentifier,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        
        _currentUserId = data['user']['id'];
        _isRegistered = true;
        _isSenderView = true;
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Login failed.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> register(String username, String email, String phoneNumber, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'phone_number': phoneNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        _token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        
        _currentUserId = data['user']['id'];
        _isRegistered = true;
        _isSenderView = true;
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Registration failed.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> forgotPassword(String email, String phoneNumber, String newPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'phone_number': phoneNumber,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Password reset failed.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> updateProfile(String username, String email, String phoneNumber) async {
    try {
      if (_token == null) throw Exception("Unauthorized");
      final response = await http.put(
        Uri.parse('$baseUrl/api/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: json.encode({
          'username': username,
          'email': email,
          'phone_number': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to update profile.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> uploadAvatar(String filePath) async {
    try {
      if (_token == null) throw Exception("Unauthorized");
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/auth/profile/avatar'));
      request.headers['Authorization'] = 'Bearer $_token';
      
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to upload profile picture.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> deleteProfile() async {
    try {
      if (_token == null) throw Exception("Unauthorized");
      final response = await http.delete(
        Uri.parse('$baseUrl/api/auth/profile'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        await logout();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to delete profile.');
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    try {
      _token = null;
      _currentUserId = null;
      _isRegistered = false;
      _isSenderView = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      _users.clear();
      _wallets.clear();
      _parcels.clear();
      notifyListeners();
    } catch (e) {
      print("Error during logout: $e");
    }
  }

  Future<void> registerAsCommuter({
    required String startCity,
    required String routeCity,
    required bool termsAccepted,
    required String nicFrontPath,
    required String nicBackPath,
  }) async {
    try {
      // First update KYC status
      await http.post(
        Uri.parse('$baseUrl/api/users/$_currentUserId/kyc'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'kyc_verified': true}),
      );

      // Then upgrade user to commuter
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/users/$_currentUserId/commuter'),
      );
      
      request.fields['route_city'] = routeCity;
      request.fields['start_city'] = startCity;
      request.fields['terms_accepted'] = termsAccepted.toString();
      request.fields['current_lat'] = '42.3601'; // Default Boston Lat
      request.fields['current_lng'] = '-71.0589'; // Default Boston Lng
      
      request.files.add(await http.MultipartFile.fromPath('nic_front', nicFrontPath));
      request.files.add(await http.MultipartFile.fromPath('nic_back', nicBackPath));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        _isSenderView = false;
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to upgrade to commuter.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  Wallet getWallet(String userId) {
    return _wallets[userId] ?? Wallet(userId: userId, availableBalance: 0.0, lockedEscrowBalance: 0.0);
  }

  Future<void> requestDelivery(String parcelId, String travelerId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/parcels/$parcelId/request'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'travelerId': travelerId}),
      );
      if (response.statusCode == 200) {
        final idx = _parcels.indexWhere((p) => p.id == parcelId);
        if (idx != -1) {
          _parcels[idx] = _parcels[idx].copyWith(requestedTravelerId: travelerId);
        }
        notifyListeners();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to send delivery request.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  Future<void> cancelDeliveryRequest(String parcelId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/parcels/$parcelId/request'),
      );
      if (response.statusCode == 200) {
        final idx = _parcels.indexWhere((p) => p.id == parcelId);
        if (idx != -1) {
          _parcels[idx] = _parcels[idx].copyWith(requestedTravelerId: null);
        }
        notifyListeners();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to cancel delivery request.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  Future<void> depositMockFunds(String userId, double amount) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/wallets/$userId/deposit'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'amount': amount}),
      );

      if (response.statusCode == 200) {
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Deposit failed.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  void toggleViewMode() {
    if (_isSenderView && !_currentUser.isCommuter) {
      throw Exception('Commuter registration required! Please apply in the Wallet/Profile tab.');
    }
    
    _isSenderView = !_isSenderView;
    
    if (_isSenderView) {
      _currentUser = _users.firstWhere((u) => u.id == _currentUserId, orElse: () => _users.first);
    } else {
      _currentUser = _users.firstWhere((u) => u.id == _selectedTravelerId, orElse: () => _users.first);
    }
    notifyListeners();
  }

  void selectTraveler(String travelerId) {
    _selectedTravelerId = travelerId;
    if (!_isSenderView) {
      _currentUser = _users.firstWhere((u) => u.id == travelerId, orElse: () => _users.first);
    }
    notifyListeners();
  }

  Future<String> createParcel({
    required ParcelCategory category,
    required String description,
    required String receiverName,
    required String receiverPhone,
    required String pickupCity,
    required String dropoffCity,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required double tipAmount,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/parcels/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'sender_id': _currentUserId,
          'category_type': _mapCategoryToString(category),
          'liability_value': 0.0,
          'receiver_name': receiverName,
          'receiver_phone': receiverPhone,
          'pickup_city': pickupCity,
          'dropoff_city': dropoffCity,
          'description': description,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          'dropoff_lat': dropoffLat,
          'dropoff_lng': dropoffLng,
          'tip_amount': tipAmount
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        await refreshState();
        return data['id'];
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to create parcel.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  Future<void> acceptParcel(String parcelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/wallets/accept'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'travelerId': _currentUser.id,
          'parcelId': parcelId
        }),
      );

      if (response.statusCode == 200) {
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to accept parcel.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  Future<void> pickupParcel(String parcelId, String photoUrl) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/parcels/$parcelId/scan'));
      request.fields['action'] = 'pickup';
      request.fields['qr_code'] = _parcels.firstWhere((p) => p.id == parcelId).qrCodeData ?? '';
      request.fields['lat'] = '42.3601'; // Mock Pickup Lat
      request.fields['lng'] = '-71.0589'; // Mock Pickup Lng
      
      request.files.add(http.MultipartFile.fromBytes(
        'photo',
        [0, 1, 2, 3], // Dummy binary data for sealed package photo
        filename: 'sealed.jpg'
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to complete pickup scan.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  Future<void> deliverParcel(String parcelId) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/parcels/$parcelId/scan'));
      request.fields['action'] = 'dropoff';
      request.fields['qr_code'] = _parcels.firstWhere((p) => p.id == parcelId).qrCodeData ?? '';
      request.fields['lat'] = '40.7128'; // Mock Dropoff Lat
      request.fields['lng'] = '-74.0060'; // Mock Dropoff Lng

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to complete delivery scan.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  Future<void> reportStolen(String parcelId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/wallets/stolen'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'parcelId': parcelId}),
      );

      if (response.statusCode == 200) {
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to report stolen parcel.');
      }
    } catch (e) {
      throw Exception('Server error: $e');
    }
  }

  Future<void> rateDelivery(String parcelId, int stars, String feedback) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/parcels/$parcelId/rate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'rating_stars': stars,
          'feedback_text': feedback.trim(),
        }),
      );

      if (response.statusCode == 200) {
        await refreshState();
      } else {
        final err = json.decode(response.body);
        throw Exception(err['detail'] ?? 'Failed to submit rating.');
      }
    } catch (e) {
      // Local fallback calculation for offline or demo mode
      final pIdx = _parcels.indexWhere((p) => p.id == parcelId);
      if (pIdx != -1) {
        _parcels[pIdx] = _parcels[pIdx].copyWith(ratingStars: stars, feedbackText: feedback.trim());
        final travelerId = _parcels[pIdx].travelerId;
        if (travelerId != null) {
          final ratedParcels = _parcels.where((p) => p.travelerId == travelerId && p.ratingStars != null).toList();
          final totalDeliveries = ratedParcels.length;
          final totalStars = ratedParcels.fold<double>(0.0, (sum, p) => sum + (p.ratingStars ?? 0));
          if (totalDeliveries > 0) {
            final avgRating = totalStars / totalDeliveries;
            final trustPercent = totalStars / (totalDeliveries * 5.0);
            final uIdx = _users.indexWhere((u) => u.id == travelerId);
            if (uIdx != -1) {
              _users[uIdx] = _users[uIdx].copyWith(rating: avgRating, trustScore: trustPercent);
            }
          }
        }
        notifyListeners();
      }
    }
  }

  // Real Database + PostGIS Traveler Matching query integration
  List<Map<String, dynamic>> simulateMatchingAlgorithm(Parcel parcel) {
    List<Map<String, dynamic>> matchResults = [];

    // Category threshold score
    double minTrustScore = 0.0;
    if (parcel.category == ParcelCategory.categoryB) {
      minTrustScore = 0.80;
    } else if (parcel.category == ParcelCategory.categoryC) {
      minTrustScore = 0.95;
    }

    for (var traveler in _users) {
      if (!traveler.isCommuter) continue; // Skip non-commuters
      if (traveler.id == parcel.senderId) continue; // Skip sender themselves

      // Step 0: Collateral Verification (Only appear when liability value is available in wallet)
      final wallet = getWallet(traveler.id);
      if (wallet.availableBalance < parcel.liabilityValue) continue;

      // Step 1: Spatial Filter (ST_DWithin 5km check)
      double dist = _haversine(parcel.pickupLat, parcel.pickupLng, traveler.currentLat ?? 42.3601, traveler.currentLng ?? -71.0589);
      bool passesSpatial = dist <= 5.0;

      // Step 2: Route Filter
      bool passesRoute = false;
      if (traveler.routeCity != null) {
        passesRoute = traveler.routeCity!.trim().toLowerCase() == parcel.dropoffCity.trim().toLowerCase();
      }

      // Step 3: Trust Gating & KYC checks
      bool passesTrustGate = traveler.trustScore >= minTrustScore;
      
      // Category A, B, C require KYC verification
      bool passesKycGate = true;
      if ((parcel.category == ParcelCategory.categoryA || 
           parcel.category == ParcelCategory.categoryB || 
           parcel.category == ParcelCategory.categoryC) && 
          !traveler.isKycVerified) {
        passesKycGate = false;
      }

      // Calculate dynamic combined score
      double baseWeight = traveler.trustScore * 100.0 * 0.40;
      double successWeight = 100.0 * 0.30; 
      double ratingWeight = (traveler.rating / 5.0) * 20.0;
      double kycBonus = traveler.isKycVerified ? 10.0 : 0.0;
      double dynamicScore = (baseWeight + successWeight + ratingWeight + kycBonus) / 100.0;

      matchResults.add({
        'traveler': traveler,
        'distance': dist,
        'passesSpatial': passesSpatial,
        'passesRoute': passesRoute,
        'passesTrustGate': passesTrustGate && passesKycGate,
        'dynamicScore': dynamicScore,
        'isEligible': passesSpatial && passesRoute && passesTrustGate && passesKycGate,
      });
    }

    // Sort: eligible first, then sort by dynamicScore descending
    matchResults.sort((a, b) {
      if (a['isEligible'] != b['isEligible']) {
        return a['isEligible'] ? -1 : 1;
      }
      return (b['dynamicScore'] as double).compareTo(a['dynamicScore'] as double);
    });

    return matchResults;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; 
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180.0;
  }

  Future<void> updateUserLocation(String userId, double lat, double lng) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/users/$userId/location'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'latitude': lat,
          'longitude': lng,
        }),
      );
      if (response.statusCode == 200) {
        final userIdx = _users.indexWhere((u) => u.id == userId);
        if (userIdx != -1) {
          _users[userIdx] = _users[userIdx].copyWith(
            currentLat: lat,
            currentLng: lng,
          );
          if (_currentUser.id == userId) {
            _currentUser = _users[userIdx];
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error updating user location: $e');
    }
  }

  Future<Map<String, dynamic>?> getParcelTracking(String parcelId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/parcels/$parcelId/tracking'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data is Map<String, dynamic> ? data : null;
      }
    } catch (e) {
      debugPrint('Error fetching parcel tracking: $e');
    }
    return null;
  }
}

