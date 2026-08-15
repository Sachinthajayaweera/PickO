import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../services/mock_api_service.dart';
import '../../models/parcel.dart';

class CreateParcelScreen extends StatefulWidget {
  final VoidCallback onParcelCreated;
  const CreateParcelScreen({Key? key, required this.onParcelCreated}) : super(key: key);

  @override
  State<CreateParcelScreen> createState() => _CreateParcelScreenState();
}

class _CreateParcelScreenState extends State<CreateParcelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _receiverNameController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  final _pickupCityController = TextEditingController(text: 'Colombo');
  final _dropoffCityController = TextEditingController(text: 'Kandy');

  final _pickupFocusNode = FocusNode();
  final _dropoffFocusNode = FocusNode();

  ParcelCategory _selectedCategory = ParcelCategory.categoryA;
  double _tipAmount = 250.0;

  bool _isCalculating = false;
  double? _distanceKm;
  bool _usingORS = false;

  double _resolvedPickupLat = 6.9271;
  double _resolvedPickupLng = 79.8612;
  double _resolvedDropoffLat = 7.2906;
  double _resolvedDropoffLng = 80.6337;

  Timer? _debounceTimer;
  List<Map<String, dynamic>> _pickupSuggestions = [];
  List<Map<String, dynamic>> _dropoffSuggestions = [];

  bool _isSelectingPickupOnMap = true;
  List<LatLng> _routePolylinePoints = [];
  final MapController _mapController = MapController();
  bool _pickupNeedsResolve = false;
  bool _dropoffNeedsResolve = false;

  final Map<String, List<double>> _fallbackCities = {
    'colombo': [6.9271, 79.8612],
    'kandy': [7.2906, 80.6337],
    'galle': [6.0535, 80.2117],
    'jaffna': [9.6615, 80.0255],
    'negombo': [7.2089, 79.8388],
    'anuradhapura': [8.3114, 80.4037],
    'kurunegala': [7.4863, 80.3647],
    'matara': [5.9549, 80.5550],
  };

  @override
  void initState() {
    super.initState();
    _pickupFocusNode.addListener(_onFocusChange);
    _dropoffFocusNode.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateDistance();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _receiverNameController.dispose();
    _receiverPhoneController.dispose();
    _pickupCityController.dispose();
    _dropoffCityController.dispose();
    _pickupFocusNode.removeListener(_onFocusChange);
    _dropoffFocusNode.removeListener(_onFocusChange);
    _pickupFocusNode.dispose();
    _dropoffFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_pickupFocusNode.hasFocus && !_dropoffFocusNode.hasFocus) {
      _calculateDistance();
    }
  }

  void _onPickupChanged(String value) {
    _pickupNeedsResolve = true;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(value, isPickup: true);
    });
  }

  void _onDropoffChanged(String value) {
    _dropoffNeedsResolve = true;
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(value, isPickup: false);
    });
  }

  Future<void> _fetchSuggestions(String query, {required bool isPickup}) async {
    if (query.trim().length < 3) {
      if (mounted) {
        setState(() {
          if (isPickup) {
            _pickupSuggestions = [];
          } else {
            _dropoffSuggestions = [];
          }
        });
      }
      return;
    }

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&countrycodes=lk');
      final response = await http.get(url, headers: {'User-Agent': 'CarryMate/1.0'}).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final suggestions = data.map((item) {
          return {
            'display_name': item['display_name'] as String,
            'lat': double.parse(item['lat']),
            'lng': double.parse(item['lon']),
          };
        }).toList();

        if (mounted) {
          setState(() {
            if (isPickup) {
              _pickupSuggestions = suggestions;
            } else {
              _dropoffSuggestions = suggestions;
            }
          });
        }
      }
    } catch (e) {
      print('Suggestion fetch error: $e');
    }
  }

  Widget _buildSuggestionList({required bool isPickup}) {
    final suggestions = isPickup ? _pickupSuggestions : _dropoffSuggestions;
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 4),
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: suggestions.length,
        itemBuilder: (context, index) {
          final item = suggestions[index];
          return ListTile(
            dense: true,
            leading: const Icon(Icons.location_on_rounded, color: Color(0xFFC084FC), size: 16),
            title: Text(
              item['display_name'],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            onTap: () {
              setState(() {
                if (isPickup) {
                  _pickupCityController.text = item['display_name'].split(',')[0];
                  _resolvedPickupLat = item['lat'];
                  _resolvedPickupLng = item['lng'];
                  _pickupSuggestions = [];
                  _pickupNeedsResolve = false;
                } else {
                  _dropoffCityController.text = item['display_name'].split(',')[0];
                  _resolvedDropoffLat = item['lat'];
                  _resolvedDropoffLng = item['lng'];
                  _dropoffSuggestions = [];
                  _dropoffNeedsResolve = false;
                }
              });
              _calculateDistance();
            },
          );
        },
      ),
    );
  }

  Future<Map<String, double>?> _resolveCoordinates(String city) async {
    final cleanCity = city.trim().toLowerCase();
    if (_fallbackCities.containsKey(cleanCity)) {
      return {
        'lat': _fallbackCities[cleanCity]![0],
        'lng': _fallbackCities[cleanCity]![1],
      };
    }

    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(city)}&format=json&limit=1&countrycodes=lk');
      final response = await http.get(url, headers: {'User-Agent': 'CarryMate/1.0'}).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lng': double.parse(data[0]['lon']),
          };
        }
      }
    } catch (e) {
      print('Geocoding error for $city: $e');
    }
    return null;
  }

  static const String _orsApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjRlYWRkMGJkZGQxMDQwNTBhOWY3OWU1MTMzYjFmMjIzIiwiaCI6Im11cm11cjY0In0=';

  Future<double?> _calculateRoadDistance(double startLat, double startLng, double endLat, double endLng) async {
    if (_orsApiKey == 'YOUR_API_KEY_HERE' || _orsApiKey.isEmpty) {
      print('ORS API Key is placeholder or empty. Falling back to local Haversine.');
      _usingORS = false;
      setState(() {
        _routePolylinePoints = [
          LatLng(startLat, startLng),
          LatLng(endLat, endLng),
        ];
      });
      return _calculateHaversineDistance(startLat, startLng, endLat, endLng);
    }

    try {
      final url = Uri.parse('https://api.openrouteservice.org/v2/directions/driving-car?api_key=$_orsApiKey&start=$startLng,$startLat&end=$endLng,$endLat');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'] != null && data['features'].isNotEmpty) {
          final feature = data['features'][0];
          final summary = feature['properties']['summary'];
          final geometry = feature['geometry'];
          if (summary != null && summary['distance'] != null) {
            final meters = summary['distance'] as num;
            _usingORS = true;

            if (geometry != null && geometry['coordinates'] != null) {
              final List<dynamic> coords = geometry['coordinates'];
              setState(() {
                _routePolylinePoints = coords.map((c) {
                  final List<dynamic> coordList = c as List<dynamic>;
                  final double lon = coordList[0] as double;
                  final double lat = coordList[1] as double;
                  return LatLng(lat, lon);
                }).toList();
              });
            } else {
              setState(() {
                _routePolylinePoints = [
                  LatLng(startLat, startLng),
                  LatLng(endLat, endLng),
                ];
              });
            }

            return meters.toDouble() / 1000.0;
          }
        }
      } else {
        print('ORS Error response code: ${response.statusCode}, body: ${response.body}');
      }
    } catch (e) {
      print('ORS Routing error: $e');
    }

    // Fallback to Haversine
    _usingORS = false;
    setState(() {
      _routePolylinePoints = [
        LatLng(startLat, startLng),
        LatLng(endLat, endLng),
      ];
    });
    return _calculateHaversineDistance(startLat, startLng, endLat, endLng);
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) *
              math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  Future<void> _calculateDistance() async {
    final pickup = _pickupCityController.text.trim();
    final dropoff = _dropoffCityController.text.trim();
    if (pickup.isEmpty || dropoff.isEmpty) return;

    if (mounted) {
      setState(() {
        _isCalculating = true;
      });
    }

    if (_pickupNeedsResolve) {
      final pickupCoords = await _resolveCoordinates(pickup);
      if (pickupCoords != null) {
        _resolvedPickupLat = pickupCoords['lat']!;
        _resolvedPickupLng = pickupCoords['lng']!;
        _pickupNeedsResolve = false;
      }
    }

    if (_dropoffNeedsResolve) {
      final dropoffCoords = await _resolveCoordinates(dropoff);
      if (dropoffCoords != null) {
        _resolvedDropoffLat = dropoffCoords['lat']!;
        _resolvedDropoffLng = dropoffCoords['lng']!;
        _dropoffNeedsResolve = false;
      }
    }

    final roadDist = await _calculateRoadDistance(
      _resolvedPickupLat,
      _resolvedPickupLng,
      _resolvedDropoffLat,
      _resolvedDropoffLng,
    );

    if (roadDist != null && mounted) {
      setState(() {
        _distanceKm = roadDist;
        _isCalculating = false;
      });
      _updateDefaultTip(_selectedCategory);
      _fitMapToPoints();
      return;
    }

    if (mounted) {
      setState(() {
        _isCalculating = false;
      });
    }
  }

  Future<void> _reverseGeocode(LatLng point, {required bool isPickup}) async {
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${point.latitude}&lon=${point.longitude}&format=json');
      final response = await http.get(url, headers: {'User-Agent': 'CarryMate/1.0'}).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        if (displayName != null) {
          final address = data['address'] as Map<String, dynamic>?;
          String cityName = '';
          if (address != null) {
            cityName = address['city'] ?? address['town'] ?? address['village'] ?? address['suburb'] ?? address['road'] ?? '';
          }
          if (cityName.isEmpty) {
            cityName = displayName.split(',')[0];
          }

          setState(() {
            if (isPickup) {
              _pickupCityController.text = cityName;
              _resolvedPickupLat = point.latitude;
              _resolvedPickupLng = point.longitude;
              _pickupNeedsResolve = false;
            } else {
              _dropoffCityController.text = cityName;
              _resolvedDropoffLat = point.latitude;
              _resolvedDropoffLng = point.longitude;
              _dropoffNeedsResolve = false;
            }
          });
          _calculateDistance();
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
      setState(() {
        final shortCoord = '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}';
        if (isPickup) {
          _pickupCityController.text = 'Location ($shortCoord)';
          _resolvedPickupLat = point.latitude;
          _resolvedPickupLng = point.longitude;
          _pickupNeedsResolve = false;
        } else {
          _dropoffCityController.text = 'Location ($shortCoord)';
          _resolvedDropoffLat = point.latitude;
          _resolvedDropoffLng = point.longitude;
          _dropoffNeedsResolve = false;
        }
      });
      _calculateDistance();
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    _reverseGeocode(point, isPickup: _isSelectingPickupOnMap);
  }

  void _fitMapToPoints() {
    final latCenter = (_resolvedPickupLat + _resolvedDropoffLat) / 2;
    final lngCenter = (_resolvedPickupLng + _resolvedDropoffLng) / 2;

    final latDiff = (_resolvedPickupLat - _resolvedDropoffLat).abs();
    final lngDiff = (_resolvedPickupLng - _resolvedDropoffLng).abs();
    final maxDiff = math.max(latDiff, lngDiff);

    double zoom = 7.2;
    if (maxDiff > 0.0) {
      zoom = (11.5 - (math.log(maxDiff) / math.ln2)).clamp(6.5, 14.0);
    }

    _mapController.move(LatLng(latCenter, lngCenter), zoom);
  }

  // Recalculates tip dynamically based on category and distance
  void _updateDefaultTip(ParcelCategory category) {
    if (_distanceKm != null) {
      double categoryMultiplier = 1.0;
      switch (category) {
        case ParcelCategory.categoryA:
          categoryMultiplier = 1.0;
          break;
        case ParcelCategory.categoryB:
          categoryMultiplier = 1.2;
          break;
        case ParcelCategory.categoryC:
          categoryMultiplier = 1.5;
          break;
        case ParcelCategory.categoryD:
          categoryMultiplier = 1.3;
          break;
      }
      setState(() {
        _tipAmount = (_distanceKm! * 10.0 * categoryMultiplier).clamp(100.0, 10000.0);
      });
    } else {
      setState(() {
        switch (category) {
          case ParcelCategory.categoryA:
            _tipAmount = 250.0;
            break;
          case ParcelCategory.categoryB:
            _tipAmount = 550.0;
            break;
          case ParcelCategory.categoryC:
            _tipAmount = 800.0;
            break;
          case ParcelCategory.categoryD:
            _tipAmount = 450.0;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<MockApiService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Stack(
        children: [
          // Background Glows
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
                    color: const Color(0xFF8B5CF6).withOpacity(0.12),
                    blurRadius: 90,
                    spreadRadius: 45,
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
                      'Scaffold New Shipment',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Match with commuter travelers for same-day delivery.',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13, fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 25),

                    // Package Description
                    _buildSectionHeader('Package Description'),
                    TextFormField(
                       controller: _descriptionController,
                       style: const TextStyle(color: Colors.white),
                       decoration: _getInputDecoration('e.g. MacBook Pro M3, Box of Chocolates'),
                       validator: (value) {
                         if (value == null || value.trim().isEmpty) {
                           return 'Please enter package details';
                         }
                         return null;
                       },
                    ),
                    const SizedBox(height: 20),
                    
                    // Receiver Details
                    _buildSectionHeader('Receiver Name'),
                    TextFormField(
                       controller: _receiverNameController,
                       style: const TextStyle(color: Colors.white),
                       decoration: _getInputDecoration('e.g. John Doe'),
                       validator: (value) {
                         if (value == null || value.trim().isEmpty) {
                           return 'Please enter receiver\'s name';
                         }
                         return null;
                       },
                    ),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Receiver Phone Number'),
                    TextFormField(
                       controller: _receiverPhoneController,
                       style: const TextStyle(color: Colors.white),
                       keyboardType: TextInputType.phone,
                       decoration: _getInputDecoration('e.g. +94 77 123 4567'),
                       validator: (value) {
                         if (value == null || value.trim().isEmpty) {
                           return 'Please enter receiver\'s phone number';
                         }
                         return null;
                       },
                    ),
                    const SizedBox(height: 20),

                    // Package Categories Grid
                    _buildSectionHeader('Category Type'),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ParcelCategory.values.length,
                      itemBuilder: (context, idx) {
                        final cat = ParcelCategory.values[idx];
                        final isSelected = _selectedCategory == cat;
                        final color = _getCategoryColor(cat);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCategory = cat;
                            });
                            _updateDefaultTip(cat);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF1E1B2C) : const Color(0xFF161424),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? color : Colors.transparent,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_getCategoryIcon(cat), color: color, size: 20),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cat.displayName,
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.grey[300],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        cat.description,
                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),


                    // Route details
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Pickup City'),
                              TextFormField(
                                controller: _pickupCityController,
                                focusNode: _pickupFocusNode,
                                style: const TextStyle(color: Colors.white),
                                decoration: _getInputDecoration('Pickup city'),
                                onChanged: _onPickupChanged,
                                onFieldSubmitted: (_) => _calculateDistance(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                              _buildSuggestionList(isPickup: true),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionHeader('Dropoff City'),
                              TextFormField(
                                controller: _dropoffCityController,
                                focusNode: _dropoffFocusNode,
                                style: const TextStyle(color: Colors.white),
                                decoration: _getInputDecoration('Dropoff city'),
                                onChanged: _onDropoffChanged,
                                onFieldSubmitted: (_) => _calculateDistance(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                              _buildSuggestionList(isPickup: false),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_isCalculating)
                      Container(
                        margin: const EdgeInsets.only(top: 15, bottom: 5),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161424),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.05)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Resolving coordinates & road routing...',
                              style: TextStyle(color: Colors.grey[400], fontSize: 13, fontFamily: 'Outfit'),
                            ),
                          ],
                        ),
                      )
                    else if (_distanceKm != null)
                      Container(
                        margin: const EdgeInsets.only(top: 15, bottom: 5),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E1B2C), Color(0xFF161424)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF8B5CF6).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.alt_route_rounded,
                                color: Color(0xFFC084FC),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Estimated Route',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (_usingORS ? const Color(0xFF10B981) : Colors.amber).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          _usingORS ? 'OpenRouteService' : 'Haversine Fallback',
                                          style: TextStyle(
                                            color: _usingORS ? const Color(0xFF10B981) : Colors.amber,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Distance: ${_distanceKm!.toStringAsFixed(1)} km',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Base Fare: Rs. 10/km | Suggested Tip: Rs. ${(_distanceKm! * 10).toStringAsFixed(0)}',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    _buildSectionHeader('Pinpoint Locations on Map'),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Set Pickup Pin'),
                          selected: _isSelectingPickupOnMap,
                          selectedColor: const Color(0xFF8B5CF6),
                          backgroundColor: const Color(0xFF161424),
                          labelStyle: TextStyle(
                            color: _isSelectingPickupOnMap ? Colors.white : Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _isSelectingPickupOnMap = true;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        ChoiceChip(
                          label: const Text('Set Dropoff Pin'),
                          selected: !_isSelectingPickupOnMap,
                          selectedColor: const Color(0xFF10B981),
                          backgroundColor: const Color(0xFF161424),
                          labelStyle: TextStyle(
                            color: !_isSelectingPickupOnMap ? Colors.white : Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _isSelectingPickupOnMap = false;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(7.8731, 80.7718),
                          initialZoom: 7.2,
                          onTap: (tapPosition, point) {
                            _onMapTap(tapPosition, point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.carrymate.app',
                          ),
                          if (_routePolylinePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePolylinePoints,
                                  color: const Color(0xFF8B5CF6),
                                  strokeWidth: 4,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(_resolvedPickupLat, _resolvedPickupLng),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF8B5CF6),
                                  size: 40,
                                ),
                              ),
                              Marker(
                                point: LatLng(_resolvedDropoffLat, _resolvedDropoffLng),
                                width: 40,
                                height: 40,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF10B981),
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap on the map to place the selected pin. The distance and route will update automatically.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 20),

                    // Tip Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionHeader('Traveler Incentive (Tip)'),
                        Text(
                          'Rs. ${_tipAmount.toStringAsFixed(0)}',
                          style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                    Slider(
                      value: _tipAmount,
                      min: 100,
                      max: math.max(2000.0, ((_tipAmount / 100).ceil() * 100.0) + 500.0),
                      activeColor: const Color(0xFF8B5CF6),
                      inactiveColor: const Color(0xFF1E1B2C),
                      onChanged: (val) {
                        setState(() {
                          _tipAmount = val;
                        });
                      },
                    ),
                    const SizedBox(height: 30),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            try {
                              await apiService.createParcel(
                                category: _selectedCategory,
                                description: _descriptionController.text.trim(),
                                receiverName: _receiverNameController.text.trim(),
                                receiverPhone: _receiverPhoneController.text.trim(),
                                pickupCity: _pickupCityController.text.trim(),
                                dropoffCity: _dropoffCityController.text.trim(),
                                pickupLat: _resolvedPickupLat,
                                pickupLng: _resolvedPickupLng,
                                dropoffLat: _resolvedDropoffLat,
                                dropoffLng: _resolvedDropoffLng,
                                tipAmount: _tipAmount,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Parcel successfully published to commuters!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              widget.onParcelCreated();
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
                          backgroundColor: const Color(0xFF8B5CF6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 5,
                          shadowColor: const Color(0xFF8B5CF6).withOpacity(0.3),
                        ),
                        child: const Text(
                          'Publish Shipment to Commuters',
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 100), // Navigation spacing
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
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  InputDecoration _getInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF161424),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF8B5CF6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

  IconData _getCategoryIcon(ParcelCategory category) {
    switch (category) {
      case ParcelCategory.categoryA:
        return Icons.shopping_bag_outlined;
      case ParcelCategory.categoryB:
        return Icons.gavel_rounded; // High worth
      case ParcelCategory.categoryC:
        return Icons.insert_drive_file_outlined; // Docs
      case ParcelCategory.categoryD:
        return Icons.restaurant_rounded; // Food/Perishables
    }
  }
}
