import os
from psycopg2.pool import ThreadedConnectionPool
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", 5432))
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres")
DB_NAME = os.getenv("DB_NAME", "pick_o")

connection_pool = None
POSTGIS_AVAILABLE = False

def get_connection_pool():
    global connection_pool
    if connection_pool is None:
        try:
            # Connect to DB
            connection_pool = ThreadedConnectionPool(
                minconn=1,
                maxconn=20,
                host=DB_HOST,
                port=DB_PORT,
                user=DB_USER,
                password=DB_PASSWORD,
                database=DB_NAME
            )
            print(f"Connected to database '{DB_NAME}' successfully.")
        except Exception as e:
            print(f"Database '{DB_NAME}' does not exist or connection failed. Attempting to create database. Error: {e}")
            try:
                import psycopg2
                # Connect to default postgres DB
                conn = psycopg2.connect(
                    host=DB_HOST,
                    port=DB_PORT,
                    user=DB_USER,
                    password=DB_PASSWORD,
                    database="postgres"
                )
                conn.autocommit = True
                cursor = conn.cursor()
                cursor.execute(f"CREATE DATABASE {DB_NAME};")
                cursor.close()
                conn.close()
                print(f"Database '{DB_NAME}' created successfully.")
                
                # Retry connection
                connection_pool = ThreadedConnectionPool(
                    minconn=1,
                    maxconn=20,
                    host=DB_HOST,
                    port=DB_PORT,
                    user=DB_USER,
                    password=DB_PASSWORD,
                    database=DB_NAME
                )
            except Exception as e_create:
                print(f"Critical error creating/connecting to database: {e_create}")
                raise e_create
    return connection_pool

def get_db_connection():
    pool = get_connection_pool()
    return pool.getconn()

def release_db_connection(conn):
    if connection_pool and conn:
        connection_pool.putconn(conn)

def init_db(schema_path="schema.sql"):
    global POSTGIS_AVAILABLE
    conn = get_db_connection()
    try:
        conn.autocommit = True
        with conn.cursor() as cursor:
            # Check if PostGIS extension is available
            try:
                cursor.execute("CREATE EXTENSION IF NOT EXISTS postgis;")
                POSTGIS_AVAILABLE = True
                print("PostGIS spatial extension enabled in database.")
            except Exception as pg_err:
                POSTGIS_AVAILABLE = False
                print(f"PostGIS extension not available. Falling back to standard geometry. Detail: {pg_err}")
            
            # Select schema based on PostGIS availability
            actual_schema_path = "schema_postgis.sql" if POSTGIS_AVAILABLE else "schema_fallback.sql"
            if os.path.exists(actual_schema_path):
                with open(actual_schema_path, "r") as f:
                    schema_sql = f.read()
                cursor.execute(schema_sql)
                print(f"Database tables initialized using {actual_schema_path}.")
                
                # Apply dynamic migrations
                cursor.execute("ALTER TABLE parcels ADD COLUMN IF NOT EXISTS receiver_name VARCHAR(255);")
                cursor.execute("ALTER TABLE parcels ADD COLUMN IF NOT EXISTS receiver_phone VARCHAR(50);")
                cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(500);")
                cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS start_city VARCHAR(255);")
                cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS nic_front_url VARCHAR(1024);")
                cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS nic_back_url VARCHAR(1024);")
                cursor.execute("ALTER TABLE users ADD COLUMN IF NOT EXISTS terms_accepted BOOLEAN DEFAULT FALSE;")
                print("Database migrations (receiver, avatar, and commuter NIC/route details) applied successfully.")
            else:
                print(f"Warning: Specific schema file not found at {actual_schema_path}")
    except Exception as e:
        print(f"Error executing schema script and migrations: {e}")
        raise e
    finally:
        release_db_connection(conn)
