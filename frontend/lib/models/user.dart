class User {
  final String id;
  final String name;
  final String? username;
  final String? email;
  final String? phoneNumber;
  final bool isKycVerified;
  final double trustScore; // 0.0 to 1.0 (e.g., 0.95 = 95% trust score)
  final double rating;     // 1.0 to 5.0
  final String? avatarUrl;
  final String? routeCity;  // Transit route destination city for filtering
  final bool isCommuter;    // True if registered as a traveler
  final double? currentLat;
  final double? currentLng;

  User({
    required this.id,
    required this.name,
    this.username,
    this.email,
    this.phoneNumber,
    required this.isKycVerified,
    required this.trustScore,
    required this.rating,
    this.avatarUrl,
    this.routeCity,
    required this.isCommuter,
    this.currentLat,
    this.currentLng,
  });

  String get formattedTrustScore => '${(trustScore * 100).toStringAsFixed(0)}%';

  User copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? phoneNumber,
    bool? isKycVerified,
    double? trustScore,
    double? rating,
    String? avatarUrl,
    String? routeCity,
    bool? isCommuter,
    double? currentLat,
    double? currentLng,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isKycVerified: isKycVerified ?? this.isKycVerified,
      trustScore: trustScore ?? this.trustScore,
      rating: rating ?? this.rating,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      routeCity: routeCity ?? this.routeCity,
      isCommuter: isCommuter ?? this.isCommuter,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
    );
  }
}
