#!/bin/bash
# GaiaCore Initialization Script
# This script loads test data after the database is initialized

set -e

echo "=================================================="
echo "GaiaCore Initialization Starting..."
echo "=================================================="

# Wait for PostgreSQL to be ready
until pg_isready -U postgres; do
  echo "Waiting for PostgreSQL to be ready..."
  sleep 2
done

echo "PostgreSQL is ready. Loading test data..."

# Load LOCATION and LOCATION_HISTORY CSV files
psql -U postgres -d gaiacore <<-EOSQL
    -- Load test location data
    SELECT working.load_location_data(
        '/csv/LOCATION.csv',
        '/csv/LOCATION_HISTORY.csv'
    );

    -- Validate location data
    SELECT * FROM working.validate_location_data();

    -- Show location statistics
    SELECT * FROM working.location_statistics();
EOSQL

# Load JSON-LD metadata if files exist
if [ -f /data/meta_json-ld_global_pm25_concentration_1998_2016.json ]; then
    echo "Loading JSON-LD metadata..."
    JSONLD_CONTENT=$(cat /data/meta_json-ld_global_pm25_concentration_1998_2016.json)

    psql -U postgres -d gaiacore <<-EOSQL
        -- Load JSON-LD metadata
        SELECT * FROM backbone.load_jsonld_file('$JSONLD_CONTENT');

        -- Show loaded data sources
        SELECT dataset_id, dataset_name, date_published FROM backbone.data_source;

        -- Show loaded variables
        SELECT vs.variable_name, vs.unit_text, ds.dataset_name
        FROM backbone.variable_source vs
        JOIN backbone.data_source ds ON vs.data_source_uuid = ds.data_source_uuid
        ORDER BY ds.dataset_name, vs.variable_name;
EOSQL
fi

echo "=================================================="
echo "GaiaCore Initialization Complete!"
echo ""
echo "Database: gaiacore"
echo "PostgreSQL Port: 5432"
echo "PostgREST API: http://localhost:3000"
echo ""
echo "Available API endpoints:"
echo "  - http://localhost:3000/data_source"
echo "  - http://localhost:3000/variable_source"
echo "  - http://localhost:3000/location"
echo "  - http://localhost:3000/location_history"
echo "  - http://localhost:3000/external_exposure"
echo ""
echo "For OpenAPI documentation:"
echo "  - http://localhost:3000/"
echo "=================================================="
