-- Enable PostGIS Extension if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Users Table (Stores senders and travelers/commuters)
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    is_commuter BOOLEAN DEFAULT FALSE,
    route_city VARCHAR(255),
    current_lat DECIMAL(9, 6) DEFAULT 42.3601, -- Default Boston Lat
    current_lng DECIMAL(9, 6) DEFAULT -71.0589, -- Default Boston Lng
    kyc_verified_status BOOLEAN DEFAULT FALSE,
    trust_score DECIMAL(5, 2) DEFAULT 50.00, -- e.g., 0.00 to 100.00
    rating DECIMAL(3, 2) DEFAULT 5.00, -- e.g., 1.00 to 5.00
    avatar_url VARCHAR(500),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 2. Wallets Table
CREATE TABLE IF NOT EXISTS wallets (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    available_balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (available_balance >= 0),
    locked_escrow_balance DECIMAL(12, 2) NOT NULL DEFAULT 0.00 CHECK (locked_escrow_balance >= 0)
);

-- 3. Parcels Table
CREATE TABLE IF NOT EXISTS parcels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id),
    traveler_id UUID REFERENCES users(id),
    category_type VARCHAR(50) NOT NULL CHECK (category_type IN ('A', 'B', 'C', 'D')),
    liability_value DECIMAL(10, 2) NOT NULL CHECK (liability_value <= 10000.00), -- Max 10,000 Rs
    status VARCHAR(50) NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Accepted', 'In Transit', 'Delivered', 'Stolen', 'Cancelled')),
    
    pickup_city VARCHAR(255) NOT NULL,
    dropoff_city VARCHAR(255) NOT NULL,
    description TEXT NOT NULL,
    tip_amount DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    
    pickup_lat DECIMAL(9, 6) NOT NULL,
    pickup_lng DECIMAL(9, 6) NOT NULL,
    dropoff_lat DECIMAL(9, 6) NOT NULL,
    dropoff_lng DECIMAL(9, 6) NOT NULL,
    
    -- Geography Point (WGS84 lat/long) for spatial distance queries
    pickup_geom GEOGRAPHY(Point, 4326) NOT NULL,
    dropoff_geom GEOGRAPHY(Point, 4326) NOT NULL,
    
    -- Digital Handshake QR
    verification_qr_code VARCHAR(255) UNIQUE NOT NULL,
    
    -- Photo verification of sealed package (on Pickup)
    sealed_package_photo_url VARCHAR(1024),
    
    receiver_name VARCHAR(255),
    receiver_phone VARCHAR(50),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 4. Secure QR Handover Scan Tracking History
CREATE TABLE IF NOT EXISTS parcel_scans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parcel_id UUID NOT NULL REFERENCES parcels(id) ON DELETE CASCADE,
    action VARCHAR(50) NOT NULL CHECK (action IN ('pickup', 'dropoff')),
    scanned_by UUID NOT NULL REFERENCES users(id),
    scan_lat DECIMAL(9, 6) NOT NULL,
    scan_lng DECIMAL(9, 6) NOT NULL,
    scan_location GEOGRAPHY(Point, 4326) NOT NULL,
    scanned_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Indexing for Geospatial Queries
CREATE INDEX IF NOT EXISTS idx_parcels_pickup_geom ON parcels USING GIST (pickup_geom);
CREATE INDEX IF NOT EXISTS idx_parcels_dropoff_geom ON parcels USING GIST (dropoff_geom);
CREATE INDEX IF NOT EXISTS idx_parcel_scans_geom ON parcel_scans USING GIST (scan_location);

-- Migration/Updates for Uber-style Login
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS username VARCHAR(100) UNIQUE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_number VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255);

ALTER TABLE parcels ADD COLUMN IF NOT EXISTS rating_stars INT CHECK (rating_stars >= 1 AND rating_stars <= 5);
ALTER TABLE parcels ADD COLUMN IF NOT EXISTS feedback_text TEXT;
