import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/parcel.dart';
import '../../models/user.dart';
import '../../services/mock_api_service.dart';
import 'parcel_handshake.dart';

class LiveTrackingScreen extends StatefulWidget {
  final Parcel parcel;

  const LiveTrackingScreen({Key? key, required this.parcel}) : super(key: key);

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  Timer? _refreshTimer;

  Map<String, dynamic>? _trackingData;
  bool _isLoading = true;
  List<LatLng> _routePoints = [];
  bool _isRouteLoading = true;

  // Local commuter live position
  LatLng? _commuterPosition;
  double _remainingKm = 0.0;
  int _etaMinutes = 0;
  bool _isSimulating = false;
  double _simStep = 0.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Initial position based on pickup
    _commuterPosition = LatLng(widget.parcel.pickupLat, widget.parcel.pickupLng);

    _fetchRoute();
    _fetchTracking();

    // Auto-refresh every 4 seconds for live telemetry
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_isSimulating) {
        _fetchTracking(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchRoute() async {
    setState(() => _isRouteLoading = true);
    final pLat = widget.parcel.pickupLat;
    final pLng = widget.parcel.pickupLng;
    final dLat = widget.parcel.dropoffLat;
    final dLng = widget.parcel.dropoffLng;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$pLng,$pLat;$dLng,$dLat?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final coordinates = data['routes'][0]['geometry']['coordinates'] as List;
          final points = coordinates
              .map((coord) => LatLng(coord[1] as double, coord[0] as double))
              .toList();

          if (mounted) {
            setState(() {
              _routePoints = points;
              _isRouteLoading = false;
            });
            _fitRouteBounds();
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback: Straight-line interpolated route points
    if (mounted) {
      final points = <LatLng>[];
      for (int i = 0; i <= 20; i++) {
        final t = i / 20.0;
        points.add(LatLng(
          pLat + (dLat - pLat) * t,
          pLng + (dLng - pLng) * t,
        ));
      }
      setState(() {
        _routePoints = points;
        _isRouteLoading = false;
      });
      _fitRouteBounds();
    }
  }

  Future<void> _fetchTracking({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final apiService = Provider.of<MockApiService>(context, listen: false);

    final data = await apiService.getParcelTracking(widget.parcel.id);
    if (data != null && mounted) {
      setState(() {
        _trackingData = data;
        _isLoading = false;

        final nav = data['navigation'] as Map<String, dynamic>?;
        if (nav != null) {
          _remainingKm = (nav['remainingDistanceKm'] as num?)?.toDouble() ?? 0.0;
          _etaMinutes = (nav['etaMinutes'] as num?)?.toInt() ?? 0;
          final cLat = (nav['commuterLat'] as num?)?.toDouble();
          final cLng = (nav['commuterLng'] as num?)?.toDouble();
          if (cLat != null && cLng != null && cLat != 0.0) {
            _commuterPosition = LatLng(cLat, cLng);
          }
        }
      });
    } else if (!silent && mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _fitRouteBounds() {
    if (_routePoints.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints([
        LatLng(widget.parcel.pickupLat, widget.parcel.pickupLng),
        LatLng(widget.parcel.dropoffLat, widget.parcel.dropoffLng),
        if (_commuterPosition != null) _commuterPosition!,
      ]);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 100),
        ),
      );
    } catch (_) {}
  }

  void _centerOnCommuter() {
    if (_commuterPosition != null) {
      _mapController.move(_commuterPosition!, 13.5);
    }
  }

  // Interactive demo simulation along highway route
  void _stepSimulation() async {
    if (_routePoints.isEmpty) return;
    final apiService = Provider.of<MockApiService>(context, listen: false);
    final travelerId = widget.parcel.travelerId;

    setState(() {
      _isSimulating = true;
      _simStep += 0.10;
      if (_simStep > 1.0) _simStep = 0.0;

      final index = ((_routePoints.length - 1) * _simStep).round();
      _commuterPosition = _routePoints[index];

      // Recompute local metrics
      final dLat = widget.parcel.dropoffLat;
      final dLng = widget.parcel.dropoffLng;
      const r = 6371.0;
      final dLatRad = (dLat - _commuterPosition!.latitude) * math.pi / 180;
      final dLonRad = (dLng - _commuterPosition!.longitude) * math.pi / 180;
      final a = math.sin(dLatRad / 2) * math.sin(dLatRad / 2) +
          math.cos(_commuterPosition!.latitude * math.pi / 180) *
              math.cos(dLat * math.pi / 180) *
              math.sin(dLonRad / 2) *
              math.sin(dLonRad / 2);
      final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
      _remainingKm = double.parse((r * c).toStringAsFixed(1));
      _etaMinutes = math.max(1, (_remainingKm / 45.0 * 60).round());
    });

    if (travelerId != null && _commuterPosition != null) {
      await apiService.updateUserLocation(
        travelerId,
        _commuterPosition!.latitude,
        _commuterPosition!.longitude,
      );
    }

    _mapController.move(_commuterPosition!, _mapController.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<MockApiService>(context);
    final currentParcel = apiService.parcels.firstWhere(
      (p) => p.id == widget.parcel.id,
      orElse: () => widget.parcel,
    );

    final traveler = currentParcel.travelerId != null
        ? apiService.getUser(currentParcel.travelerId!)
        : null;

    final pickupPoint = LatLng(widget.parcel.pickupLat, widget.parcel.pickupLng);
    final dropoffPoint = LatLng(widget.parcel.dropoffLat, widget.parcel.dropoffLng);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E17),
      body: Stack(
        children: [
          // Interactive Map Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(
                (pickupPoint.latitude + dropoffPoint.latitude) / 2,
                (pickupPoint.longitude + dropoffPoint.longitude) / 2,
              ),
              initialZoom: 9.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.picko.app',
              ),
              // Highway Route Polyline
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Glow background
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF8B5CF6).withOpacity(0.35),
                      strokeWidth: 8,
                    ),
                    // Main route line
                    Polyline(
                      points: _routePoints,
                      color: const Color(0xFF8B5CF6),
                      strokeWidth: 4,
                    ),
                  ],
                ),
              // Map Markers
              MarkerLayer(
                markers: [
                  // Pickup Marker
                  Marker(
                    point: pickupPoint,
                    width: 50,
                    height: 50,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.home_work_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.parcel.pickupCity,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Dropoff Marker
                  Marker(
                    point: dropoffPoint,
                    width: 50,
                    height: 50,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 6),
                            ],
                          ),
                          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 16),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.parcel.dropoffCity,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Live Commuter Marker with pulse animation
                  if (_commuterPosition != null)
                    Marker(
                      point: _commuterPosition!,
                      width: 80,
                      height: 80,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulsing halo
                              Container(
                                width: 50 + (_pulseController.value * 22),
                                height: 50 + (_pulseController.value * 22),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF8B5CF6).withOpacity(0.35 * (1.0 - _pulseController.value)),
                                ),
                              ),
                              // Commuter vehicle pin
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF161424),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFA78BFA), width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0xFF8B5CF6),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: traveler?.avatarUrl != null && traveler!.avatarUrl!.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          traveler.avatarUrl!.startsWith('http')
                                              ? traveler.avatarUrl!
                                              : '${apiService.baseUrl}${traveler.avatarUrl}',
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const Icon(Icons.directions_car_rounded, color: Color(0xFFA78BFA), size: 22),
                              ),
                              // LIVE badge
                              Positioned(
                                top: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top Floating Navigation Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161424).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 12),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.parcel.description,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${widget.parcel.pickupCity} ➔ ${widget.parcel.dropoffCity}',
                                style: TextStyle(color: Colors.grey[400], fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        currentParcel.status.displayName,
                        style: const TextStyle(
                          color: Color(0xFFA78BFA),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Floating Action Buttons (Recenter / Zoom)
          Positioned(
            right: 16,
            top: 130,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_commuter',
                  backgroundColor: const Color(0xFF161424),
                  foregroundColor: const Color(0xFFA78BFA),
                  onPressed: _centerOnCommuter,
                  tooltip: 'Center on Commuter',
                  child: const Icon(Icons.my_location_rounded, size: 20),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'fit_route',
                  backgroundColor: const Color(0xFF161424),
                  foregroundColor: Colors.white70,
                  onPressed: _fitRouteBounds,
                  tooltip: 'Fit Whole Route',
                  child: const Icon(Icons.fullscreen_rounded, size: 22),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'simulate_transit',
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  onPressed: _stepSimulation,
                  tooltip: 'Simulate Movement',
                  child: const Icon(Icons.fast_forward_rounded, size: 20),
                ),
              ],
            ),
          ),

          // Bottom Telemetry & Commuter Info Sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF161424),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Colors.black87, blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Commuter Profile Row
                  if (traveler != null)
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF232038),
                          backgroundImage: traveler.avatarUrl != null && traveler.avatarUrl!.isNotEmpty
                              ? NetworkImage(traveler.avatarUrl!.startsWith('http')
                                  ? traveler.avatarUrl!
                                  : '${apiService.baseUrl}${traveler.avatarUrl}')
                              : null,
                          child: traveler.avatarUrl == null || traveler.avatarUrl!.isEmpty
                              ? const Icon(Icons.person_rounded, size: 26, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    traveler.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  if (traveler.isKycVerified) ...[
                                    const SizedBox(width: 4),
                                    const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 14),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    traveler.formattedRating,
                                    style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '• Trust: ${traveler.formattedTrustScore}',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Quick Action Buttons
                        IconButton(
                          onPressed: () async {
                            final phone = traveler.phoneNumber ?? '+94 77 123 4567';
                            final uri = Uri(scheme: 'tel', path: phone);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981).withOpacity(0.15),
                            padding: const EdgeInsets.all(8),
                          ),
                          icon: const Icon(Icons.phone_rounded, color: Color(0xFF10B981), size: 18),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () async {
                            final phone = (traveler.phoneNumber ?? '+94771234567').replaceAll(' ', '');
                            final text = 'Hi ${traveler.name}, checking in on my parcel: ${widget.parcel.description}';
                            final uri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(text)}');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366).withOpacity(0.15),
                            padding: const EdgeInsets.all(8),
                          ),
                          icon: const Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 18),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Metrics Strip: Distance, ETA, Status
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B2C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMetricColumn('Distance Remaining', '${_remainingKm.toStringAsFixed(1)} km', const Color(0xFF8B5CF6)),
                        Container(width: 1, height: 28, color: Colors.white10),
                        _buildMetricColumn('Estimated Arrival', '$_etaMinutes mins', const Color(0xFF10B981)),
                        Container(width: 1, height: 28, color: Colors.white10),
                        _buildMetricColumn('Handshake', widget.parcel.status == ParcelStatus.readyForPickup ? 'Pickup' : 'Dropoff', const Color(0xFFF59E0B)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // QR Code & Handshake Direct Button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ParcelHandshakeScreen(parcel: currentParcel),
                              ),
                            );
                          },
                          icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.white),
                          label: const Text(
                            'Show Handshake QR',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8B5CF6),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _stepSimulation,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Simulate Step', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFA78BFA),
                          side: BorderSide(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 10),
        ),
      ],
    );
  }
}
