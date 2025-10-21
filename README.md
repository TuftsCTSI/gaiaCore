# gaiaCore

A PostgreSQL-based tool for ingesting, managing, and analyzing geospatial exposure data with LinkML/JSON-LD metadata support and RESTful API access via PostgREST.

## Features

- **JSON-LD Metadata Ingestion**: Parse and store dataset metadata from LinkML-compatible JSON-LD files or URLs
- **Automated Data Retrieval**: Download and ingest external data sources directly from URLs
- **URL-based Metadata Loading**: Fetch JSON-LD metadata files from remote URLs
- **Geospatial Data Management**: Store and query spatial datasets with PostGIS
- **SQL & Spatial Data Support**: Ingest both SQL dumps and spatial file formats
- **Location & History Tracking**: Manage person-location-time relationships
- **Spatial Join Engine**: Parameterized spatial joins for exposure calculations
- **RESTful API**: Query data via PostgREST HTTP API
- **Docker-based Deployment**: Easy setup with Docker Compose


## Database Schema

### backbone schema
Core metadata and template tables following the GAIA data model:

- **data_source**: Dataset metadata from JSON-LD files
- **variable_source**: Individual variables/attributes in datasets
- **geom_template**: Geometry records from external sources
- **attr_template**: Attribute values associated with geometries

### working schema
Operational tables for locations and exposure calculations:

- **location**: Geocoded addresses with point geometries
- **location_history**: Person-location-time relationships
- **location_merge**: View combining location and history with geometry
- **external_exposure**: Calculated exposure results from spatial joins

## Quick Start

### Prerequisites
- Docker and Docker Compose
- 4GB+ RAM recommended
- Ports 5432 and 3000 available

### Installation

1. Clone the repository:
```bash
git clone https://github.com/OHDSI/gaiaCore.git
cd gaiaCore
```

2. Start the services:
```bash
docker-compose up -d
```

3. Check the logs:
```bash
docker-compose logs -f gaiacore-db
```

4. Access the database:
```bash
docker exec -it gaiacore-postgres psql -U postgres -d gaiacore
```

5. Access the API:
```bash
# List data sources (backbone schema - default)
curl http://localhost:3000/data_source

# Query location data (working schema - requires header)
curl -H "Accept-Profile: working" http://localhost:3000/location

# Get OpenAPI documentation
curl http://localhost:3000/
```

**Important**: Tables in the `working` schema (location, location_history, external_exposure) require the `Accept-Profile: working` header. See [POSTGREST_API_GUIDE.md](POSTGREST_API_GUIDE.md) for details.

## Automated Data Retrieval

GaiaCore now features **automated data source retrieval**, allowing you to download and ingest external geospatial datasets with a single SQL function call.

### Before vs After

**Before (Manual - 3+ steps):**
```bash
# 1. Find and download URL from JSON-LD
curl -O https://example.com/pm25_data.zip

# 2. Extract the archive
unzip pm25_data.zip

# 3. Load with ogr2ogr
docker exec -it gaiacore-postgres ogr2ogr \
  -f PostgreSQL \
  PG:"dbname=gaiacore user=postgres" \
  /data/pm25_data.shp \
  -nln public.pm25_data \
  -lco GEOMETRY_NAME=wgs_geom
```

**After (Automated - 1 function):**
```sql
-- Single function call handles everything
SELECT * FROM backbone.quick_ingest_datasource('PM2.5');
```

## Usage

### Complete Workflow Example

Here's a complete end-to-end workflow using GaiaCore's automated features:

```sql
-- Step 1: Load JSON-LD metadata
SELECT * FROM backbone.load_jsonld_file(
    pg_read_file('/data/meta_json-ld_global_pm25_concentration_1998_2016.json')
);

-- Step 2: Load location data
SELECT * FROM working.load_location_data(
    '/csv/LOCATION.csv',
    '/csv/LOCATION_HISTORY.csv'
);

-- Step 3: List downloadable datasets
SELECT dataset_name, download_url, already_ingested
FROM backbone.list_downloadable_datasources();

-- Step 4: Automated data retrieval and ingestion
SELECT * FROM backbone.quick_ingest_datasource('PM2.5');

-- Step 5: Perform spatial join
SELECT working.spatial_join_exposure(
    'avpmu_2015',
    'public.annual_pm2_5_concentrations_for_countries_and_urban_areas_v1_1998_2016'
);

-- Step 6: Query results
SELECT
    ee.person_id,
    l.city,
    l.state,
    ee.value_as_number as pm25_concentration,
    ee.exposure_start_date,
    ee.exposure_end_date
FROM working.external_exposure ee
JOIN working.location l ON ee.location_id = l.location_id
WHERE ee.person_id > 0
ORDER BY ee.value_as_number DESC
LIMIT 10;
```

### 1. Ingest JSON-LD Metadata

Load metadata from a JSON-LD file:

```sql
-- From SQL client
SELECT * FROM backbone.load_jsonld_file(
    pg_read_file('/data/meta_json-ld_global_pm25_concentration_1998_2016.json')
);

-- This creates records in:
-- - backbone.data_source (1 record for the dataset)
-- - backbone.variable_source (N records for each variable)
```

### 2. Load Location Data

Load LOCATION and LOCATION_HISTORY CSV files:

```sql
SELECT * FROM working.load_location_data(
    '/csv/LOCATION.csv',
    '/csv/LOCATION_HISTORY.csv'
);

-- Validate the loaded data
SELECT * FROM working.validate_location_data();

-- View statistics
SELECT * FROM working.location_statistics();
```

### 3. Load External Data Source

**Option A: Automated Retrieval (Recommended) 🆕**

Automatically download, extract, and load external data sources with a single function call:

```sql
-- Quick ingestion by dataset name (easiest method)
SELECT * FROM backbone.quick_ingest_datasource('PM2.5');

-- View progress and results
step              | status    | message
------------------+-----------+-----------------------------------
metadata_retrieval| success   | Retrieved metadata for: PM2.5
etl_info_extract. | success   | ETL information extracted
download          | success   | Download successful
ingestion         | success   | Imported into public.pm25_data
indexing          | success   | Created spatial index
complete          | success   | Data source successfully ingested

-- Or with full control over all parameters
SELECT * FROM backbone.retrieve_and_ingest_datasource(
    p_data_source_uuid := '<uuid>',
    p_download_url := 'https://example.com/data.zip',  -- Override URL
    p_target_schema := 'public',
    p_target_table := 'pm25_data',
    p_keep_downloaded := FALSE  -- Cleanup after
);

-- List what's available to download
SELECT dataset_name, download_url, already_ingested, ingested_table
FROM backbone.list_downloadable_datasources();
```

**What This Does:**
- Downloads the file from URL (from JSON-LD metadata or override)
- Automatically extracts ZIP, TAR.GZ, or other archives
- Loads data into PostgreSQL using ogr2ogr
- Creates spatial indexes automatically
- Updates metadata to track ingestion status
- Returns detailed progress information

**Option B: Manual ogr2ogr**

Load local files using GDAL/ogr2ogr:

```bash
docker exec -it gaiacore-postgres ogr2ogr \
  -f PostgreSQL \
  PG:"dbname=gaiacore user=postgres" \
  /data/your_shapefile.shp \
  -nln public.your_table_name \
  -lco GEOMETRY_NAME=wgs_geom
```

**Option C: Create Empty Table from Metadata**

```sql
SELECT backbone.create_datasource_table(
    '<data_source_uuid>',
    'public'
);
```

### 4. Perform Spatial Join

Execute a spatial join between locations and a data source:

```sql
-- Simple 1-point join (geometry in same table as attributes)
SELECT working.spatial_join_exposure(
    p_variable_name := 'avpmu_2015',
    p_data_source_table := 'public.global_pm25_concentration_1998_2016'
);

-- 2-point join (geometry in separate table)
SELECT working.spatial_join_exposure(
    p_variable_name := 'avpmu_2015',
    p_data_source_table := 'public.pm25_attributes',
    p_geometry_source_table := 'public.pm25_geometries',
    p_variable_merge_column := 'region_id',
    p_geometry_merge_column := 'region_id'
);

-- Process all variables from a data source
SELECT * FROM working.spatial_join_all_variables(
    '<data_source_uuid>',
    'public.global_pm25_concentration_1998_2016'
);

-- View results
SELECT * FROM working.external_exposure LIMIT 10;

-- Get statistics
SELECT * FROM working.exposure_statistics();
```

### 5. Query via REST API

```bash
# Get all data sources
curl http://localhost:3000/data_source

# List downloadable data sources
curl -X POST http://localhost:3000/rpc/list_downloadable_datasources

# Automated data ingestion via API
curl -X POST http://localhost:3000/rpc/quick_ingest_datasource \
  -H "Content-Type: application/json" \
  -d '{"p_dataset_name": "PM2.5"}'

# Get variables for a specific data source
curl "http://localhost:3000/variable_source?data_source_uuid=eq.<uuid>"

# Get locations in a specific city
curl "http://localhost:3000/location?city=eq.FRESNO"

# Get exposure records for a specific person
curl "http://localhost:3000/external_exposure?person_id=eq.1234"

# Get exposure records with filtering and ordering
curl "http://localhost:3000/external_exposure?person_id=eq.1234&order=exposure_start_date.desc&limit=10"

# Get statistics (using PostgreSQL functions via RPC)
curl -X POST http://localhost:3000/rpc/location_statistics

curl -X POST http://localhost:3000/rpc/exposure_statistics
```

## Key Functions Reference

### JSON-LD Ingestion

- `backbone.ingest_jsonld_metadata`: Parses JSON-LD metadata and stores in data_source table
- `backbone.ingest_jsonld_variables`: Extracts variable definitions from JSON-LD and stores in variable_source;
- `backbone.load_jsonld_file`: Main entry point to load JSON-LD content from text;
- `backbone.load_jsonld_from_path`: Load JSON-LD from file path using pg_read_file;
- `backbone.download_jsonld_to_file`: Download JSON-LD file from URL to temporary location;
- `backbone.fetch_and_load_jsonld`: Fetch JSON-LD metadata from URL and load into database;
- `backbone.create_datasource_table`: Dynamically creates a table structure based on JSON-LD variable definitions;

### Data Source Retrieval 🆕
- `backbone.quick_ingest_datasource(dataset_name, url)`: One-line ingestion by name
- `backbone.retrieve_and_ingest_datasource(uuid, ...)`: Full-featured retrieval with all options
- `backbone.list_downloadable_datasources()`: List all data sources with download info
- `backbone.fetch_and_extract_file(url, dest, compression)`: Download and extract files
- `backbone.ingest_raw_data(file_path, table_name, ...)`: Load spatial data using ogr2ogr
- `backbone.extract_etl_info_from_jsonld(uuid)`: Extract ETL information from metadata

### Location Data
- `working.load_location_csv(csv_path)`: Load LOCATION CSV
- `working.load_location_history_csv(csv_path)`: Load LOCATION_HISTORY CSV
- `working.load_location_data(loc_path, hist_path)`: Load both files
- `working.validate_location_data()`: Validate loaded data
- `working.location_statistics()`: Get summary statistics

### Spatial Joins
- `working.spatial_join_exposure(...)`: Parameterized spatial join
- `working.spatial_join_simple(variable, table)`: Simplified wrapper
- `working.spatial_join_all_variables(uuid, table)`: Process all variables
- `working.exposure_statistics()`: Get exposure statistics
- `working.clear_exposure_data(variable)`: Clear exposure records

## Spatial Join Parameters

The `working.spatial_join_exposure()` function supports:

- **p_variable_name**: Variable to join (from variable_source)
- **p_data_source_table**: Table containing the data
- **p_geometry_source_table**: (Optional) Separate geometry table
- **p_variable_merge_column**: (Optional) Join key in data table
- **p_geometry_merge_column**: (Optional) Join key in geometry table
- **p_spatial_operator**: Spatial relationship (default: 'st_within')
  - `st_within`, `st_contains`, `st_intersects`, `st_dwithin`
- **p_buffer_meters**: Buffer distance in meters (default: 0)

## Test Data

The repository includes test data in the `test/` directory:

- **LOCATION.csv**: Sample geocoded addresses (20 locations)
- **LOCATION_HISTORY.csv**: Person-location-time relationships
- **meta_json-ld_global_pm25_concentration_1998_2016.json**: Sample JSON-LD metadata

This test data is automatically loaded during container initialization.

## API Documentation

PostgREST provides automatic OpenAPI documentation:

```bash
# View OpenAPI spec
curl http://localhost:3000/

# Access in browser for Swagger UI
open http://localhost:3000/
```

## Development

### Running Tests

```bash
# Execute validation
docker exec -it gaiacore-postgres psql -U postgres -d gaiacore \
  -c "SELECT * FROM working.validate_location_data();"

# Check loaded data
docker exec -it gaiacore-postgres psql -U postgres -d gaiacore \
  -c "SELECT * FROM working.location_statistics();"
```

### Rebuilding the Container

```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Accessing Logs

```bash
# Database logs
docker-compose logs -f gaiacore-db

# API logs
docker-compose logs -f gaiacore-api
```

## Detailed Examples

### Example 1: Automated End-to-End Workflow

Complete workflow using automated data retrieval:

```sql
-- 1. Load JSON-LD metadata
SELECT * FROM backbone.load_jsonld_file(
    pg_read_file('/data/meta_json-ld_global_pm25_concentration_1998_2016.json')
);

-- 2. Load location data
SELECT * FROM working.load_location_data(
    '/csv/LOCATION.csv',
    '/csv/LOCATION_HISTORY.csv'
);

-- 3. List what's available to download
SELECT dataset_name, download_url, already_ingested
FROM backbone.list_downloadable_datasources();

-- 4. Automated data retrieval (one function call!)
SELECT * FROM backbone.quick_ingest_datasource('PM2.5');

-- 5. Perform spatial join
SELECT working.spatial_join_exposure(
    'avpmu_2015',
    'public.annual_pm2_5_concentrations_for_countries_and_urban_areas_v1_1998_2016'
);

-- 6. Query results
SELECT
    ee.person_id,
    l.city,
    l.state,
    ee.value_as_number as pm25_concentration,
    ee.exposure_start_date
FROM working.external_exposure ee
JOIN working.location l ON ee.location_id = l.location_id
WHERE ee.person_id > 0
ORDER BY ee.value_as_number DESC
LIMIT 10;
```

### Example 2: Batch Processing Multiple Datasets

```sql
-- Ingest all available datasets automatically
DO $$
DECLARE
    v_ds RECORD;
BEGIN
    FOR v_ds IN
        SELECT data_source_uuid, dataset_name
        FROM backbone.list_downloadable_datasources()
        WHERE has_download_url = TRUE
          AND already_ingested = FALSE
    LOOP
        RAISE NOTICE 'Processing: %', v_ds.dataset_name;

        PERFORM backbone.retrieve_and_ingest_datasource(
            v_ds.data_source_uuid
        );

        RAISE NOTICE 'Completed: %', v_ds.dataset_name;
    END LOOP;
END $$;
```

### Example 3: Query Variable Metadata

```sql
-- Find all temperature-related variables across all datasets
SELECT
    ds.dataset_name,
    vs.variable_name,
    vs.variable_description,
    vs.unit_text,
    vs.min_value,
    vs.max_value
FROM backbone.variable_source vs
JOIN backbone.data_source ds ON vs.data_source_uuid = ds.data_source_uuid
WHERE vs.variable_description ILIKE '%temperature%'
   OR vs.variable_name ILIKE '%temp%';

-- Get all variables from a specific dataset
SELECT
    variable_name,
    unit_text,
    start_date,
    end_date,
    min_value,
    max_value
FROM backbone.variable_source
WHERE data_source_uuid = (
    SELECT data_source_uuid
    FROM backbone.data_source
    WHERE dataset_name LIKE '%PM2.5%'
)
ORDER BY variable_name;
```

### Example 4: Advanced Spatial Joins

```sql
-- Proximity analysis with buffer
SELECT working.spatial_join_exposure(
    p_variable_name := 'pollution_level',
    p_data_source_table := 'public.pollution_sources',
    p_spatial_operator := 'st_dwithin',
    p_buffer_meters := 1000  -- Within 1km
);

-- Two-point join (separate attribute and geometry tables)
SELECT working.spatial_join_exposure(
    p_variable_name := 'air_quality_index',
    p_data_source_table := 'public.aq_measurements',
    p_geometry_source_table := 'public.aq_monitoring_stations',
    p_variable_merge_column := 'station_id',
    p_geometry_merge_column := 'station_id'
);

-- Process all variables from a dataset at once
SELECT * FROM working.spatial_join_all_variables(
    (SELECT data_source_uuid FROM backbone.data_source WHERE dataset_name LIKE '%PM2.5%'),
    'public.pm25_urban_areas'
);
```

### Example 5: Custom URL Override

```sql
-- When the JSON-LD doesn't have a URL or you want to use a different source
SELECT * FROM backbone.retrieve_and_ingest_datasource(
    p_data_source_uuid := (
        SELECT data_source_uuid
        FROM backbone.data_source
        WHERE dataset_name LIKE '%PM2.5%'
    ),
    p_download_url := 'https://custom-source.org/data.zip',
    p_target_table := 'my_custom_table',
    p_keep_downloaded := TRUE  -- Keep for debugging
);
```

### Example 6: Analyze Exposure Results

```sql
-- Find people with highest cumulative exposure
SELECT
    person_id,
    COUNT(*) as exposure_events,
    AVG(value_as_number) as avg_exposure,
    SUM(value_as_number * (exposure_end_date - exposure_start_date)) as cumulative_exposure_days,
    MIN(exposure_start_date) as first_exposure,
    MAX(exposure_end_date) as last_exposure
FROM working.external_exposure
WHERE person_id > 0
GROUP BY person_id
ORDER BY cumulative_exposure_days DESC
LIMIT 20;

-- Compare exposure by city
SELECT
    l.city,
    l.state,
    COUNT(DISTINCT ee.person_id) as people_exposed,
    AVG(ee.value_as_number) as avg_pm25,
    MAX(ee.value_as_number) as max_pm25
FROM working.external_exposure ee
JOIN working.location l ON ee.location_id = l.location_id
WHERE ee.person_id > 0
GROUP BY l.city, l.state
ORDER BY avg_pm25 DESC;
```

### Example 7: REST API Usage

```bash
# List all downloadable data sources
curl -X POST http://localhost:3000/rpc/list_downloadable_datasources

# Automated ingestion via API
curl -X POST http://localhost:3000/rpc/quick_ingest_datasource \
  -H "Content-Type: application/json" \
  -d '{"p_dataset_name": "PM2.5"}'

# Get exposure data with filters
curl "http://localhost:3000/external_exposure?person_id=gt.0&value_as_number=gte.50&order=value_as_number.desc&limit=10"

# Get statistics
curl -X POST http://localhost:3000/rpc/exposure_statistics

# Complex query with embedding
curl "http://localhost:3000/external_exposure?select=*,location(city,state)&person_id=eq.1234"
```

### Example 8: Data Validation

```sql
-- Validate all location data
SELECT * FROM working.validate_location_data();

-- Expected output:
check_name             | status | details
-----------------------+--------+----------------------------------
Missing Geometry       | PASS   | 0 locations missing geometry
Invalid Coordinates    | PASS   | 0 locations with invalid coords
Orphaned History Recs  | PASS   | 0 history records with no match
Invalid Date Ranges    | PASS   | 0 records where end < start

-- View statistics
SELECT * FROM working.location_statistics();
SELECT * FROM working.exposure_statistics();
```

## Troubleshooting

### Port Already in Use
```bash
# Change ports in docker-compose.yml
ports:
  - "5433:5432"  # PostgreSQL
  - "3001:3000"  # PostgREST
```

### Database Connection Issues
```bash
# Check database health
docker exec -it gaiacore-postgres pg_isready -U postgres

# View connection settings
docker exec -it gaiacore-postgres psql -U postgres -c "SHOW all;"
```

### PostgREST Not Starting
```bash
# Check logs
docker-compose logs gaiacore-api

# Verify database is ready
docker-compose ps
```

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

See LICENSE.md file for details.

## References

- [PostGIS Documentation](https://postgis.net/documentation/)
- [PostgREST Documentation](https://postgrest.org/)
- [LinkML](https://linkml.io/)
- [JSON-LD](https://json-ld.org/)
- [OMOP CDM](https://ohdsi.github.io/CommonDataModel/)
