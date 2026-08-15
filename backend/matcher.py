import math
from typing import List, Dict, Any, Optional
from pydantic import BaseModel

class Traveler(BaseModel):
    id: str
    name: str
    current_lat: float
    current_lng: float
    transit_route_cities: List[str] # List of cities along their travel route
    kyc_verified_status: bool
    trust_score: float # Base trust score from history (0 - 100)
    success_rate: float # Past success rate percentage (0 - 100)
    rating: float # Average rating out of 5.0

class ParcelRequest(BaseModel):
    pickup_lat: float
    pickup_lng: float
    destination_city: str
    category_type: str # A, B, C, D
    liability_value: float

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Calculate the great-circle distance between two points on the Earth 
    in kilometers using the Haversine formula.
    """
    R = 6371.0 # Earth radius in kilometers

    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)

    a = math.sin(dlat / 2)**2 + \
        math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * \
        math.sin(dlon / 2)**2
    
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

def calculate_dynamic_trust_score(traveler: Traveler) -> float:
    """
    Calculate a dynamic trust ranking score out of 100.
    Combines:
    - Base Trust Score (40% weight)
    - Past Success Rate (30% weight)
    - Rating scaled to 100 (20% weight)
    - KYC Verification status (10% bonus weight)
    """
    base_weight = traveler.trust_score * 0.40
    success_weight = traveler.success_rate * 0.30
    rating_weight = (traveler.rating / 5.0) * 20.0
    kyc_bonus = 10.0 if traveler.kyc_verified_status else 0.0

    return base_weight + success_weight + rating_weight + kyc_bonus

def find_best_traveler(parcel: ParcelRequest, travelers: List[Traveler]) -> Optional[Dict[str, Any]]:
    """
    Executes the 3-step Trust-Aware Matching Algorithm:
    1. Spatial Filter: Traveler within 5km of pickup.
    2. Route Filter: Traveler route intersects destination city.
    3. Trust Score Sort: Filter by category constraints & pick the highest scoring.
    """
    candidates = []

    # Trust Gating requirements based on Category
    # Category B: 80%+ Trust Score
    # Category C: 95%+ Trust Score
    min_trust_score = 0.0
    if parcel.category_type == 'B':
        min_trust_score = 80.0
    elif parcel.category_type == 'C':
        min_trust_score = 95.0

    for traveler in travelers:
        # --- STEP 1: Spatial Filter (5km radius) ---
        dist = haversine_distance(parcel.pickup_lat, parcel.pickup_lng, traveler.current_lat, traveler.current_lng)
        if dist > 5.0:
            # Exceeded 5km radius
            continue

        # --- STEP 2: Route Filter (Intersects destination city) ---
        # Normalize comparison (lowercase and trimmed)
        dest_city_normalized = parcel.destination_city.strip().lower()
        route_cities_normalized = [c.strip().lower() for c in traveler.transit_route_cities]
        if dest_city_normalized not in route_cities_normalized:
            # Route does not intersect with destination city
            continue

        # --- Category Trust-Score Gating ---
        if traveler.trust_score < min_trust_score:
            continue

        # --- KYC Check for Category A, B, C (all verified travelers) ---
        # Category A requires verified status. B and C also require verification.
        if not traveler.kyc_verified_status:
            continue

        # --- STEP 3: Trust Score Sort ---
        score = calculate_dynamic_trust_score(traveler)
        candidates.append({
            "traveler": traveler,
            "distance_to_pickup": dist,
            "matching_score": score
        })

    if not candidates:
        return None

    # Sort descending by matching score, secondary sort by distance (closer is better)
    candidates.sort(key=lambda x: (-x["matching_score"], x["distance_to_pickup"]))
    
    best_candidate = candidates[0]
    
    return {
        "traveler_id": best_candidate["traveler"].id,
        "name": best_candidate["traveler"].name,
        "matching_score": round(best_candidate["matching_score"], 2),
        "distance_to_pickup_km": round(best_candidate["distance_to_pickup"], 2),
        "trust_score": best_candidate["traveler"].trust_score,
        "success_rate": best_candidate["traveler"].success_rate,
        "rating": best_candidate["traveler"].rating
    }
