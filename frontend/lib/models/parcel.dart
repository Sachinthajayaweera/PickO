enum ParcelCategory {
  categoryA, // Standard Goods (Low risk, standard tip, open to all verified)
  categoryB, // Fragile/High-Value (High risk, premium tip, requires 80%+ Trust Score)
  categoryC, // High-Importance Documents (Zero monetary value, Platinum tip, requires 95%+ Trust Score)
  categoryD, // Perishables (Speed bonus tip, strict time-window matching)
}

enum ParcelStatus {
  matching,         // Looking for a commuter
  readyForPickup,   // Commuter matched and accepted (escrow locked)
  inTransit,        // Picked up with QR verification + photo sealed
  delivered,        // Successfully delivered with final QR handshake
  stolen,           // Traveler failed / packet stolen (escrow deducted and given to sender)
}

extension ParcelCategoryExtension on ParcelCategory {
  String get displayName {
    switch (this) {
      case ParcelCategory.categoryA:
        return 'Standard Goods';
      case ParcelCategory.categoryB:
        return 'Fragile & High-Value';
      case ParcelCategory.categoryC:
        return 'High-Importance Docs';
      case ParcelCategory.categoryD:
        return 'Perishable Goods';
    }
  }

  String get description {
    switch (this) {
      case ParcelCategory.categoryA:
        return 'Low risk, open to all verified commuters.';
      case ParcelCategory.categoryB:
        return 'High risk, requires 80%+ traveler trust score.';
      case ParcelCategory.categoryC:
        return 'Zero declared value, requires 95%+ traveler trust score.';
      case ParcelCategory.categoryD:
        return 'Strict time windows. Eligible for Speed Tip.';
    }
  }

  double get requiredTrustScore {
    switch (this) {
      case ParcelCategory.categoryA:
        return 0.0;
      case ParcelCategory.categoryB:
        return 0.80;
      case ParcelCategory.categoryC:
        return 0.95;
      case ParcelCategory.categoryD:
        return 0.0;
    }
  }
}

extension ParcelStatusExtension on ParcelStatus {
  String get displayName {
    switch (this) {
      case ParcelStatus.matching:
        return 'Matching';
      case ParcelStatus.readyForPickup:
        return 'Ready for Pickup';
      case ParcelStatus.inTransit:
        return 'In Transit';
      case ParcelStatus.delivered:
        return 'Delivered';
      case ParcelStatus.stolen:
        return 'Stolen / Claimed';
    }
  }
}

class Parcel {
  final String id;
  final String senderId;
  final String? travelerId;
  final ParcelCategory category;
  final double liabilityValue; // Max 10,000 Rs
  final ParcelStatus status;
  final double pickupLat;
  final double pickupLng;
  final double dropoffLat;
  final double dropoffLng;
  final String pickupCity;
  final String dropoffCity;
  final String description;
  final double tipAmount;
  final String? photoUrl;
  final String? qrCodeData;
  final DateTime createdAt;
  final int? ratingStars;
  final String? feedbackText;
  final String? receiverName;
  final String? receiverPhone;

  Parcel({
    required this.id,
    required this.senderId,
    this.travelerId,
    required this.category,
    required this.liabilityValue,
    required this.status,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.pickupCity,
    required this.dropoffCity,
    required this.description,
    required this.tipAmount,
    this.photoUrl,
    this.qrCodeData,
    required this.createdAt,
    this.ratingStars,
    this.feedbackText,
    this.receiverName,
    this.receiverPhone,
  });

  Parcel copyWith({
    String? id,
    String? senderId,
    String? travelerId,
    ParcelCategory? category,
    double? liabilityValue,
    ParcelStatus? status,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    String? pickupCity,
    String? dropoffCity,
    String? description,
    double? tipAmount,
    String? photoUrl,
    String? qrCodeData,
    DateTime? createdAt,
    int? ratingStars,
    String? feedbackText,
    String? receiverName,
    String? receiverPhone,
  }) {
    return Parcel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      travelerId: travelerId ?? this.travelerId,
      category: category ?? this.category,
      liabilityValue: liabilityValue ?? this.liabilityValue,
      status: status ?? this.status,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      pickupCity: pickupCity ?? this.pickupCity,
      dropoffCity: dropoffCity ?? this.dropoffCity,
      description: description ?? this.description,
      tipAmount: tipAmount ?? this.tipAmount,
      photoUrl: photoUrl ?? this.photoUrl,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      createdAt: createdAt ?? this.createdAt,
      ratingStars: ratingStars ?? this.ratingStars,
      feedbackText: feedbackText ?? this.feedbackText,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
    );
  }
}
