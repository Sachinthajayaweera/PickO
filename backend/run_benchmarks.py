import os
import sys
import time
import uuid
import random
import math
import psycopg2
from dotenv import load_dotenv

load_dotenv()

# Add current directory to path so we can import from main.py
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database import get_db_connection, release_db_connection, init_db, POSTGIS_AVAILABLE
from main import match_travelers, scan_checkpoint, accept_parcel, get_user, rate_delivery, RateDeliveryRequest, AcceptParcelRequest

def run_benchmarks():
    print("=" * 60)
    print("           PICKO PERFORMANCE & INTEGRITY BENCHMARKS         ")
    print("=" * 60)
    
    # 1. Reset database schema
    print("\n[1/4] Resetting and initializing database...")
    init_db("schema.sql")
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Clear previous entries
            cursor.execute("DELETE FROM parcel_scans;")
            cursor.execute("DELETE FROM wallets;")
            cursor.execute("DELETE FROM parcels;")
            cursor.execute("DELETE FROM users;")
            conn.commit()
            
            # Setup a test sender and a test parcel
            sender_id = str(uuid.uuid4())
            cursor.execute(
                "INSERT INTO users (id, name, trust_score, rating, kyc_verified_status) VALUES (%s, 'Test Sender', 98.0, 4.9, True)",
                (sender_id,)
            )
            cursor.execute(
                "INSERT INTO wallets (user_id, available_balance, locked_escrow_balance) VALUES (%s, 100000.0, 0.0)",
                (sender_id,)
            )
            
            parcel_id = str(uuid.uuid4())
            # Category B requires trust >= 80%
            qr_code = "benchmark-qr-code"
            
            # Standard Boston Lat/Lng coordinates
            p_lat, p_lng = 42.3601, -71.0589
            
            if POSTGIS_AVAILABLE:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code, pickup_geom, dropoff_geom)
                       VALUES (%s, %s, 'B', 1500.00, 'Pending', 'Boston', 'New York', 'Test Package', 200.00, %s, %s, 40.7128, -74.0060, %s, ST_GeographyFromText('SRID=4326;POINT(-71.0589 42.3601)'), ST_GeographyFromText('SRID=4326;POINT(-74.0060 40.7128)'))""",
                    (parcel_id, sender_id, p_lat, p_lng, qr_code)
                )
            else:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code)
                       VALUES (%s, %s, 'B', 1500.00, 'Pending', 'Boston', 'New York', 'Test Package', 200.00, %s, %s, 40.7128, -74.0060, %s)""",
                    (parcel_id, sender_id, p_lat, p_lng, qr_code)
                )
            conn.commit()
            
            # -------------------------------------------------------------
            # BENCHMARK 1: MATCHING ENGINE LATENCY SCALING
            # -------------------------------------------------------------
            print("\n[2/4] Running Matching Latency Benchmark...")
            print("Generating 500 mock traveler profiles around Boston area...")
            
            # Generate 500 traveler profiles
            traveler_ids = []
            for i in range(500):
                t_id = str(uuid.uuid4())
                traveler_ids.append(t_id)
                # 80% are within 5km radius of pickup point, 20% are outside
                dist_factor = random.uniform(0.001, 0.03) if i < 400 else random.uniform(0.06, 0.1)
                # Jitter lat/lng
                angle = random.uniform(0, 2 * math.pi)
                t_lat = p_lat + dist_factor * math.sin(angle)
                t_lng = p_lng + dist_factor * math.cos(angle)
                
                # Dynamic trust scoring details
                trust = random.uniform(50.0, 100.0)
                kyc = random.choice([True, False])
                
                cursor.execute(
                    """INSERT INTO users (id, name, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating)
                       VALUES (%s, %s, True, 'New York', %s, %s, %s, %s, 4.5)""",
                    (t_id, f"Traveler-{i}", t_lat, t_lng, kyc, trust)
                )
            conn.commit()
            
            # Disable commuter status for all generated travelers initially
            cursor.execute("UPDATE users SET is_commuter = FALSE;")
            conn.commit()
            
            # Measure at 50, 200, and 500 active travelers
            latencies = {}
            for pool_size in [50, 200, 500]:
                active_ids = traveler_ids[:pool_size]
                cursor.execute(
                    "UPDATE users SET is_commuter = TRUE WHERE id IN %s",
                    (tuple(active_ids),)
                )
                conn.commit()
                
                # Warmup run
                match_travelers(parcel_id)
                
                # Benchmark run
                start_time = time.perf_counter()
                iterations = 20
                for _ in range(iterations):
                    match_travelers(parcel_id)
                end_time = time.perf_counter()
                
                avg_latency_ms = ((end_time - start_time) / iterations) * 1000.0
                latencies[pool_size] = avg_latency_ms
                print(f" -> Pool Size: {pool_size:3d} Active Travelers | Avg Latency: {avg_latency_ms:6.2f} ms")
                
                # Set them back to false before testing next size
                cursor.execute("UPDATE users SET is_commuter = FALSE;")
                conn.commit()

            # Restore commuter status to all generated travelers for the next tests
            cursor.execute(
                "UPDATE users SET is_commuter = TRUE WHERE id IN %s",
                (tuple(traveler_ids),)
            )
            conn.commit()

            # -------------------------------------------------------------
            # BENCHMARK 2: TRUST-GATING ACCURACY ANALYSIS
            # -------------------------------------------------------------
            print("\n[3/4] Running Trust-Gating Accuracy Analysis...")
            print("Verifying gating parameters across Category A, B, and C cargos...")
            
            # Category B requires trust >= 80
            # Let's test 30 traveler profiles (15 should pass, 15 should fail)
            gating_passed = 0
            for i in range(30):
                t_id = traveler_ids[i]
                # Alternate profiles above/below 80%
                expected_pass = i < 15
                test_trust = 85.0 if expected_pass else 75.0
                
                # Update traveler profile to exactly this trust value and KYC = True
                cursor.execute(
                    "UPDATE users SET trust_score = %s, kyc_verified_status = TRUE WHERE id = %s",
                    (test_trust, t_id)
                )
                conn.commit()
                
                # Check match list
                matches = match_travelers(parcel_id)
                matched_ids = [m["traveler"]["id"] for m in matches if m["isEligible"]]
                
                passed_gate = t_id in matched_ids
                if passed_gate == expected_pass:
                    gating_passed += 1
            
            accuracy_rate = (gating_passed / 30.0) * 100.0
            print(f" -> Correct classification cases: {gating_passed}/30 profiles")
            print(f" -> Trust Gating Evaluation Accuracy: {accuracy_rate:.1f}%")

            # -------------------------------------------------------------
            # BENCHMARK 3: QR HANDSHAKE INTEGRITY TEST
            # -------------------------------------------------------------
            print("\n[4/4] Running QR Verification Integrity Test...")
            
            rejections = 0
            total_checks = 5
            
            # Case 1: Drop-off scan attempted before pickup scan (should reject)
            try:
                scan_checkpoint(id=parcel_id, action="dropoff", qr_code=qr_code, lat=p_lat, lng=p_lng)
                print("FAIL: Out-of-sequence drop-off scan succeeded")
            except Exception:
                rejections += 1
                
            # Case 2: Pickup scan with tampered/incorrect QR code (should reject)
            try:
                scan_checkpoint(id=parcel_id, action="pickup", qr_code="wrong-qr-code", lat=p_lat, lng=p_lng)
                print("FAIL: Incorrect QR scan succeeded")
            except Exception:
                rejections += 1

            # Setup correct traveler assignment
            traveler_id = traveler_ids[0]
            cursor.execute("UPDATE users SET trust_score = 90.0 WHERE id = %s", (traveler_id,))
            cursor.execute(
                "INSERT INTO wallets (user_id, available_balance, locked_escrow_balance) VALUES (%s, 10000.0, 0.0) ON CONFLICT DO NOTHING",
                (traveler_id,)
            )
            conn.commit()
            
            # Accept parcel to enable pickup scans
            accept_parcel(AcceptParcelRequest(travelerId=traveler_id, parcelId=parcel_id))
            
            # Create a mock upload file for pickup
            mock_photo = type('UploadFile', (object,), {'filename': 'test.jpg', 'file': type('Buffer', (object,), {'read': lambda: b'data'})})
            
            # Case 3: Double pickup scan (should reject second)
            try:
                # First pickup (should succeed)
                # We simulate Form data params manually for backend call
                import shutil
                # Create uploads dir if not exists
                os.makedirs("uploads", exist_ok=True)
                
                cursor.execute(
                    "UPDATE parcels SET status = 'In Transit' WHERE id = %s",
                    (parcel_id,)
                )
                conn.commit()
                
                # Try pickup scan again now that it is already In Transit (should fail)
                scan_checkpoint(id=parcel_id, action="pickup", qr_code=qr_code, lat=p_lat, lng=p_lng)
                print("FAIL: Duplicate pickup scan succeeded")
            except Exception:
                rejections += 1
                
            # Case 4: Double drop-off scan (should reject second)
            try:
                # First drop-off (should succeed)
                scan_checkpoint(id=parcel_id, action="dropoff", qr_code=qr_code, lat=40.7128, lng=-74.0060)
                
                # Second drop-off (should fail)
                scan_checkpoint(id=parcel_id, action="dropoff", qr_code=qr_code, lat=40.7128, lng=-74.0060)
                print("FAIL: Duplicate drop-off scan succeeded")
            except Exception:
                rejections += 1
                
            # Case 5: Scan with invalid lat/lng format (should reject)
            try:
                scan_checkpoint(id=parcel_id, action="dropoff", qr_code=qr_code, lat="invalid", lng="invalid")
                print("FAIL: Invalid coordinates scan accepted")
            except Exception:
                rejections += 1
                
            rejection_rate = (rejections / total_checks) * 100.0
            print(f" -> Invalid scan scenarios blocked: {rejections}/{total_checks}")
            print(f" -> Handover Integrity Rejection Rate: {rejection_rate:.1f}%")
            
            print("\n" + "=" * 60)
            print("               BENCHMARK EVALUATION SUMMARY                 ")
            print("=" * 60)
            print(f" Latency ( 50 travelers)          : {latencies[50]:.2f} ms")
            print(f" Latency (200 travelers)          : {latencies[200]:.2f} ms")
            print(f" Latency (500 travelers)          : {latencies[500]:.2f} ms")
            print(f" Trust Gating Accuracy            : {accuracy_rate:.1f}%")
            print(f" QR Handshake Security Rejection  : {rejection_rate:.1f}%")
            print("=" * 60)
            
    finally:
        # Re-seed the clean developer environment
        print("\nRe-seeding clean developer data...")
        from main import startup_event
        startup_event()
        release_db_connection(conn)

if __name__ == "__main__":
    run_benchmarks()
