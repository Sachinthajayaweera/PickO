import sys
import uuid
from database import get_db_connection, release_db_connection, init_db, POSTGIS_AVAILABLE

def run_tests():
    print("Initializing test database tables...")
    init_db("schema.sql")
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Clean up previous test entries
            cursor.execute("DELETE FROM parcel_scans;")
            cursor.execute("DELETE FROM wallets;")
            cursor.execute("DELETE FROM parcels;")
            cursor.execute("DELETE FROM users;")
            conn.commit()
            
            # Create mock users
            sender_id = str(uuid.uuid4())
            traveler_id = str(uuid.uuid4())
            unverified_id = str(uuid.uuid4())
            
            cursor.execute(
                "INSERT INTO users (id, name, trust_score, rating, kyc_verified_status) VALUES (%s, %s, 90.0, 4.5, True)",
                (sender_id, "user-sender")
            )
            cursor.execute(
                "INSERT INTO users (id, name, trust_score, rating, kyc_verified_status) VALUES (%s, %s, 90.0, 4.5, True)",
                (traveler_id, "user-traveler")
            )
            cursor.execute(
                "INSERT INTO users (id, name, trust_score, rating, kyc_verified_status) VALUES (%s, %s, 75.0, 3.8, False)",
                (unverified_id, "user-traveler-unverified")
            )
            
            # Create wallets
            cursor.execute(
                "INSERT INTO wallets (user_id, available_balance, locked_escrow_balance) VALUES (%s, 5000.00, 0.00)",
                (sender_id,)
            )
            cursor.execute(
                "INSERT INTO wallets (user_id, available_balance, locked_escrow_balance) VALUES (%s, 2000.00, 0.00)",
                (traveler_id,)
            )
            cursor.execute(
                "INSERT INTO wallets (user_id, available_balance, locked_escrow_balance) VALUES (%s, 2000.00, 0.00)",
                (unverified_id,)
            )
            conn.commit()
            
            print("Mock database populated successfully.")

            # Test 1: Successful Escrow Lock
            p1_id = str(uuid.uuid4())
            qr1 = "qr-p1"
            if POSTGIS_AVAILABLE:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code, pickup_geom, dropoff_geom)
                       VALUES (%s, %s, 'A', 1500.00, 'Pending', 'Boston', 'New York', 'Test Package 1', 200.00, 42.3601, -71.0589, 40.7128, -74.0060, %s, ST_GeographyFromText('SRID=4326;POINT(-71.0589 42.3601)'), ST_GeographyFromText('SRID=4326;POINT(-74.0060 40.7128)'))""",
                    (p1_id, sender_id, qr1)
                )
            else:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code)
                       VALUES (%s, %s, 'A', 1500.00, 'Pending', 'Boston', 'New York', 'Test Package 1', 200.00, 42.3601, -71.0589, 40.7128, -74.0060, %s)""",
                    (p1_id, sender_id, qr1)
                )
            conn.commit()
            
            from main import accept_parcel, AcceptParcelRequest
            accept_parcel(AcceptParcelRequest(travelerId=traveler_id, parcelId=p1_id))
            
            # Verify balances
            cursor.execute("SELECT available_balance, locked_escrow_balance FROM wallets WHERE user_id = %s", (traveler_id,))
            avail, locked = cursor.fetchone()
            assert float(avail) == 500.00, f"Expected 500.00 available balance, got {avail}"
            assert float(locked) == 1500.00, f"Expected 1500.00 locked balance, got {locked}"
            
            cursor.execute("SELECT status, traveler_id FROM parcels WHERE id = %s", (p1_id,))
            p_status, p_traveler = cursor.fetchone()
            assert p_status == "Accepted", f"Expected status Accepted, got {p_status}"
            assert str(p_traveler) == traveler_id, f"Expected traveler to be set, got {p_traveler}"
            print("SUCCESS: Test 1 Passed: Escrow locked successfully on parcel acceptance.")

            # Test 2: Trust-gating failure (requires trust >= 80, unverified has 75)
            p2_id = str(uuid.uuid4())
            qr2 = "qr-p2"
            if POSTGIS_AVAILABLE:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code, pickup_geom, dropoff_geom)
                       VALUES (%s, %s, 'B', 1000.00, 'Pending', 'Boston', 'New York', 'Test Package 2', 200.00, 42.3601, -71.0589, 40.7128, -74.0060, %s, ST_GeographyFromText('SRID=4326;POINT(-71.0589 42.3601)'), ST_GeographyFromText('SRID=4326;POINT(-74.0060 40.7128)'))""",
                    (p2_id, sender_id, qr2)
                )
            else:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code)
                       VALUES (%s, %s, 'B', 1000.00, 'Pending', 'Boston', 'New York', 'Test Package 2', 200.00, 42.3601, -71.0589, 40.7128, -74.0060, %s)""",
                    (p2_id, sender_id, qr2)
                )
            conn.commit()
            
            from fastapi import HTTPException
            try:
                accept_parcel(AcceptParcelRequest(travelerId=unverified_id, parcelId=p2_id))
                raise AssertionError("Should have failed trust gate")
            except HTTPException as he:
                assert he.status_code == 403, f"Expected 403, got {he.status_code}"
                print("SUCCESS: Test 2 Passed: Gated trust score successfully rejected low-trust commuter.")

            # Test 3: Insufficient Funds failure
            p3_id = str(uuid.uuid4())
            qr3 = "qr-p3"
            if POSTGIS_AVAILABLE:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code, pickup_geom, dropoff_geom)
                       VALUES (%s, %s, 'A', 8000.00, 'Pending', 'Boston', 'New York', 'Test Package 3', 200.00, 42.3601, -71.0589, 40.7128, -74.0060, %s, ST_GeographyFromText('SRID=4326;POINT(-71.0589 42.3601)'), ST_GeographyFromText('SRID=4326;POINT(-74.0060 40.7128)'))""",
                    (p3_id, sender_id, qr3)
                )
            else:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code)
                       VALUES (%s, %s, 'A', 8000.00, 'Pending', 'Boston', 'New York', 'Test Package 3', 200.00, 42.3601, -71.0589, 40.7128, -74.0060, %s)""",
                    (p3_id, sender_id, qr3)
                )
            conn.commit()
            
            try:
                accept_parcel(AcceptParcelRequest(travelerId=traveler_id, parcelId=p3_id))
                raise AssertionError("Should have failed balance verification")
            except HTTPException as he:
                assert he.status_code == 400, f"Expected 400, got {he.status_code}"
                print("SUCCESS: Test 3 Passed: Rejected acceptance due to insufficient traveler collateral.")

            # Test 4: Complete Delivery Escrow release + tip transfer
            cursor.execute("UPDATE parcels SET status = 'In Transit' WHERE id = %s", (p1_id,))
            conn.commit()
            
            from main import scan_checkpoint
            scan_checkpoint(
                id=p1_id,
                action="dropoff",
                qr_code=qr1,
                lat=40.7128,
                lng=-74.0060
            )
            
            # Verify balances
            cursor.execute("SELECT available_balance, locked_escrow_balance FROM wallets WHERE user_id = %s", (traveler_id,))
            avail, locked = cursor.fetchone()
            # Traveler: 500.00 + 1500.00 (released escrow) + 200.00 (tip) = 2200.00
            assert float(avail) == 2200.00, f"Expected 2200.00, got {avail}"
            assert float(locked) == 0.00, f"Expected 0.00 locked, got {locked}"
            
            cursor.execute("SELECT available_balance FROM wallets WHERE user_id = %s", (sender_id,))
            s_avail = cursor.fetchone()[0]
            # Sender: 5000.00 - 200.00 = 4800.00
            assert float(s_avail) == 4800.00, f"Expected 4800.00 sender avail, got {s_avail}"
            
            cursor.execute("SELECT status FROM parcels WHERE id = %s", (p1_id,))
            assert cursor.fetchone()[0] == "Delivered"
            
            # Verify scan logged in tracking history
            cursor.execute("SELECT action, scan_lat FROM parcel_scans WHERE parcel_id = %s AND action = 'dropoff'", (p1_id,))
            s_action, s_lat = cursor.fetchone()
            assert s_action == "dropoff"
            assert float(s_lat) == 40.7128
            print("SUCCESS: Test 4 Passed: Escrow released, tip transferred, scan logged on delivery completion.")

            # Test 5: Stolen package transfers liability from traveler to sender
            p4_id = str(uuid.uuid4())
            qr4 = "qr-p4"
            if POSTGIS_AVAILABLE:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code, pickup_geom, dropoff_geom)
                       VALUES (%s, %s, 'A', 1000.00, 'Pending', 'Boston', 'New York', 'Stolen Package Test', 200.00, 42.3601, -71.0589, 40.7128, -74.0060, %s, ST_GeographyFromText('SRID=4326;POINT(-71.0589 42.3601)'), ST_GeographyFromText('SRID=4326;POINT(-74.0060 40.7128)'))""",
                    (p4_id, sender_id, qr4)
                )
            else:
                cursor.execute(
                    """INSERT INTO parcels (id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code)
                       VALUES (%s, %s, 'A', 1000.00, 'Pending', 'Boston', 'New York', 'Stolen Package Test', 200.00, 42.3601, -71.0589, 40.7128, -74.0060, %s)""",
                    (p4_id, sender_id, qr4)
                )
            conn.commit()
            
            accept_parcel(AcceptParcelRequest(travelerId=traveler_id, parcelId=p4_id))
            
            from main import report_stolen
            report_stolen({"parcelId": p4_id})
            
            # Verify balances
            cursor.execute("SELECT available_balance, locked_escrow_balance FROM wallets WHERE user_id = %s", (traveler_id,))
            avail, locked = cursor.fetchone()
            assert float(avail) == 1200.00, f"Expected 1200.00 traveler avail, got {avail}"
            assert float(locked) == 0.00, f"Expected 0.00 locked, got {locked}"
            
            cursor.execute("SELECT available_balance FROM wallets WHERE user_id = %s", (sender_id,))
            s_avail = cursor.fetchone()[0]
            # Sender: 4800.00 + 1000.00 = 5800.00
            assert float(s_avail) == 5800.00, f"Expected 5800.00 sender avail, got {s_avail}"
            
            cursor.execute("SELECT status FROM parcels WHERE id = %s", (p4_id,))
            assert cursor.fetchone()[0] == "Stolen"
            print("SUCCESS: Test 5 Passed: Stolen package deducted escrow and reimbursed sender wallet.")

            # Test 6: Rate Delivery and verify traveler trust score recalculation
            from main import rate_delivery, RateDeliveryRequest
            # Retrieve traveler's rating and trust score before rating
            cursor.execute("SELECT rating, trust_score FROM users WHERE id = %s", (traveler_id,))
            old_rating, old_trust = cursor.fetchone()
            
            # Sender rates the delivery with 3 stars
            rate_delivery(
                id=p1_id,
                req=RateDeliveryRequest(rating_stars=3, feedback_text="Delivery was okay, but a bit late.")
            )
            
            # Verify parcel was updated in DB
            cursor.execute("SELECT rating_stars, feedback_text FROM parcels WHERE id = %s", (p1_id,))
            stars, feedback = cursor.fetchone()
            assert stars == 3
            assert feedback == "Delivery was okay, but a bit late."
            
            # Verify traveler rating and trust score were updated in DB using formula:
            # Rating = 3 stars / 1 delivery = 3.0
            # Trust Score = (3 / (1 * 5)) * 100 = 60.0%
            cursor.execute("SELECT rating, trust_score FROM users WHERE id = %s", (traveler_id,))
            new_rating, new_trust = cursor.fetchone()
            assert float(new_rating) == 3.0, f"Expected rating 3.0, got {new_rating}"
            assert float(new_trust) == 60.0, f"Expected trust score 60.0, got {new_trust}"
            print("SUCCESS: Test 6 Passed: Delivery rated and traveler trust score updated via formula (3.0 stars, 60%).")

            # --- TEST 7: MATCHING LIABILITY GATING & REQUEST WORKFLOW ---
            from main import match_travelers, request_traveler, RequestDeliveryRequest, create_parcel, CreateParcelRequest
            c1_id = str(uuid.uuid4())
            c2_id = str(uuid.uuid4())
            cursor.execute("""
                INSERT INTO users (id, name, username, email, password_hash, is_commuter, route_city, start_city, current_lat, current_lng, kyc_verified_status, trust_score, rating)
                VALUES 
                (%s, 'Commuter Rich', 'c_rich', 'rich@test.com', 'h', TRUE, 'Kandy', 'Colombo', 6.9271, 79.8612, TRUE, 95.0, 5.0),
                (%s, 'Commuter Poor', 'c_poor', 'poor@test.com', 'h', TRUE, 'Kandy', 'Colombo', 6.9271, 79.8612, TRUE, 95.0, 5.0)
            """, (c1_id, c2_id))
            cursor.execute("""
                INSERT INTO wallets (user_id, available_balance, locked_escrow_balance)
                VALUES (%s, 5000.0, 0.0), (%s, 200.0, 0.0)
            """, (c1_id, c2_id))
            conn.commit()

            # Create parcel with liability = 1,500 Rs
            p_match_res = create_parcel(CreateParcelRequest(
                sender_id=sender_id,
                category_type='B',
                liability_value=1500.00,
                receiver_name='Test Receiver',
                receiver_phone='0771234567',
                pickup_city='Colombo',
                dropoff_city='Kandy',
                pickup_lat=6.9271,
                pickup_lng=79.8612,
                dropoff_lat=7.2906,
                dropoff_lng=80.6337,
                tip_amount=300.00,
                description='High-Value Device'
            ))
            p_match_id = p_match_res["id"]

            # Match travelers: Rich commuter must appear, poor commuter must NOT appear
            match_res = match_travelers(p_match_id)
            matched_uids = [m["traveler"]["id"] for m in match_res]
            assert c1_id in matched_uids, "Rich commuter should be in match results"
            assert c2_id not in matched_uids, "Poor commuter should be excluded due to insufficient liability balance"
            
            # Sender requests rich commuter
            req_out = request_traveler(p_match_id, RequestDeliveryRequest(travelerId=c1_id))
            assert req_out["requestedTravelerId"] == c1_id
            
            # Rich commuter accepts the request
            acc_out = accept_parcel(AcceptParcelRequest(travelerId=c1_id, parcelId=p_match_id))
            assert acc_out["parcel"]["status"] == "Accepted"
            
            # Verify escrow locked
            cursor.execute("SELECT available_balance, locked_escrow_balance FROM wallets WHERE user_id = %s", (c1_id,))
            c1_avail, c1_locked = cursor.fetchone()
            assert float(c1_avail) == 3500.0
            assert float(c1_locked) == 1500.0
            print("SUCCESS: Test 7 Passed: Commuter matching gated by liability balance and direct request accepted.")

            # --- AUTH TESTS ---
            print("\nRunning new Authentication and Profile Management tests...")
            from main import (
                auth_register, AuthRegisterRequest,
                auth_login, AuthLoginRequest,
                auth_forgot_password, ForgotPasswordRequest,
                auth_update_profile, UpdateProfileRequest,
                auth_delete_profile, auth_me
            )
            
            # Auth Test 1: Register
            reg_req = AuthRegisterRequest(
                username="testuser",
                email="testuser@picko.com",
                phone_number="+15551234567",
                password="password123"
            )
            reg_res = auth_register(reg_req)
            assert reg_res["token"] is not None
            assert reg_res["user"]["username"] == "testuser"
            assert reg_res["user"]["trust_score"] == 0.0, f"Expected 0.0 trust score, got {reg_res['user']['trust_score']}"
            assert reg_res["user"]["rating"] == 0.0, f"Expected 0.0 rating, got {reg_res['user']['rating']}"
            u_id = reg_res["user"]["id"]
            
            # Verify wallet created
            assert reg_res["wallet"]["available_balance"] == 5000.00
            print("SUCCESS: Auth Test 1 Passed: User registered with 0 starting scores, wallet, and token generated.")
            
            # Auth Test 2: Register duplicate email (should fail)
            try:
                auth_register(reg_req)
                raise AssertionError("Should have failed duplicate check")
            except HTTPException as he:
                assert he.status_code == 400
                print("SUCCESS: Auth Test 2 Passed: Duplicate registration blocked.")
                
            # Auth Test 3: Login successfully
            log_req = AuthLoginRequest(
                username_or_email="testuser",
                password="password123"
            )
            log_res = auth_login(log_req)
            assert log_res["token"] is not None
            token = log_res["token"]
            
            # Login with email
            log_req_email = AuthLoginRequest(
                username_or_email="testuser@picko.com",
                password="password123"
            )
            log_res_email = auth_login(log_req_email)
            assert log_res_email["token"] is not None
            print("SUCCESS: Auth Test 3 Passed: User logged in using username and email.")
            
            # Auth Test 4: Login with bad password (should fail)
            log_req_bad = AuthLoginRequest(
                username_or_email="testuser",
                password="badpassword"
            )
            try:
                auth_login(log_req_bad)
                raise AssertionError("Should have failed bad password")
            except HTTPException as he:
                assert he.status_code == 401
                print("SUCCESS: Auth Test 4 Passed: Login with incorrect password rejected.")
                
            # Auth Test 5: Forgot Password
            forgot_req = ForgotPasswordRequest(
                email="testuser@picko.com",
                phone_number="+15551234567",
                new_password="newpassword123"
            )
            forgot_res = auth_forgot_password(forgot_req)
            assert forgot_res["message"] == "Password reset successfully."
            
            # Attempt login with old password (should fail)
            try:
                auth_login(log_req)
                raise AssertionError("Should have failed old password")
            except HTTPException as he:
                assert he.status_code == 401
                
            # Login with new password (should succeed)
            log_req_new = AuthLoginRequest(
                username_or_email="testuser",
                password="newpassword123"
            )
            log_res_new = auth_login(log_req_new)
            assert log_res_new["token"] is not None
            token = log_res_new["token"]
            print("SUCCESS: Auth Test 5 Passed: Password reset and validated via login.")
            
            # Auth Test 6: Verify auth_me session
            me_res = auth_me(u_id)
            assert me_res["username"] == "testuser"
            assert me_res["email"] == "testuser@picko.com"
            print("SUCCESS: Auth Test 6 Passed: Token authentication verified user session.")
            
            # Auth Test 7: Update profile
            up_req = UpdateProfileRequest(
                username="testuser2",
                email="testuser2@picko.com",
                phone_number="+15557654321"
            )
            up_res = auth_update_profile(up_req, user_id=u_id)
            assert up_res["user"]["username"] == "testuser2"
            assert up_res["user"]["email"] == "testuser2@picko.com"
            assert up_res["user"]["phone_number"] == "+15557654321"
            print("SUCCESS: Auth Test 7 Passed: Profile details successfully updated in DB.")

            
            # Auth Test 8: Cascading deletion
            del_res = auth_delete_profile(user_id=u_id)
            assert del_res["message"] == "Profile deleted successfully."
            
            # Verify user deleted from DB
            cursor.execute("SELECT id FROM users WHERE id = %s", (u_id,))
            assert cursor.fetchone() is None
            
            # Verify wallet deleted from DB
            cursor.execute("SELECT user_id FROM wallets WHERE user_id = %s", (u_id,))
            assert cursor.fetchone() is None
            print("SUCCESS: Auth Test 8 Passed: Cascading deletion removed user and wallet record.")

            print("\nAll Python Backend tests completed successfully!")
            
    finally:
        release_db_connection(conn)

if __name__ == "__main__":
    run_tests()
