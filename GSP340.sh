
# Set dataset names
export DATASET_NAME_1=covid
export DATASET_NAME_2=covid_data

# Task 1: Create dataset and partitioned table
echo "TASK 1: Creating COVID dataset and partitioned table"
bq mk --dataset $DEVSHELL_PROJECT_ID:covid
sleep 10

echo "Creating partitioned oxford_policy_tracker table..."
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE TABLE $DATASET_NAME_1.oxford_policy_tracker
PARTITION BY date
OPTIONS(
partition_expiration_days=2175,
description='oxford_policy_tracker table in the COVID 19 Government Response public dataset with expiry time set to 2175 days.'
) AS
SELECT
   *
FROM
   \`bigquery-public-data.covid19_govt_response.oxford_policy_tracker\`
WHERE
   alpha_3_code NOT IN ('GBR', 'BRA', 'CAN','USA')
"
echo "$Task 1 completed successfully!"
echo

# Task 2: Alter table to add columns
echo "TASK 2: Adding columns to global_mobility_tracker_data"
echo "Adding population, country_area and mobility structure..."
bq query --use_legacy_sql=false \
"
ALTER TABLE $DATASET_NAME_2.global_mobility_tracker_data
ADD COLUMN population INT64,
ADD COLUMN country_area FLOAT64,
ADD COLUMN mobility STRUCT<
   avg_retail      FLOAT64,
   avg_grocery     FLOAT64,
   avg_parks       FLOAT64,
   avg_transit     FLOAT64,
   avg_workplace   FLOAT64,
   avg_residential FLOAT64
>
"
echo "$Task 2 completed successfully!"
echo

# Task 3: Create population data table and update
echo "TASK 3: Creating and updating population data"
echo "Creating pop_data_2019 table (full schema copy)..."
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE TABLE $DATASET_NAME_2.pop_data_2019 AS
SELECT *
FROM 
  \`bigquery-public-data.covid19_ecdc.covid_19_geographic_distribution_worldwide\`
"

echo "Creating lightweight projection (country_territory_code, pop_data_2019) for joins..."
bq query --use_legacy_sql=false \
"
CREATE OR REPLACE TABLE $DATASET_NAME_2.pop_data_2019_small AS
SELECT
  country_territory_code,
  pop_data_2019
FROM 
  \`$DEVSHELL_PROJECT_ID.$DATASET_NAME_2.pop_data_2019\`
GROUP BY
  country_territory_code,
  pop_data_2019
ORDER BY
  country_territory_code
"

echo "Updating population data..."
bq query --use_legacy_sql=false \
"
UPDATE
   \`$DATASET_NAME_2.consolidate_covid_tracker_data\` t0
SET
   population = t1.pop_data_2019
FROM
   \`$DATASET_NAME_2.pop_data_2019_small\` t1
WHERE
   TRIM(t0.alpha_3_code) = TRIM(t1.country_territory_code);
"
echo "$Task 3 completed successfully!"
echo

# Task 4: Update country area data
echo "TASK 4: Updating country area data"
echo "Updating country_area from census data..."
bq query --use_legacy_sql=false \
"
UPDATE
   \`$DATASET_NAME_2.consolidate_covid_tracker_data\` t0
SET
   t0.country_area = t1.country_area
FROM
   \`bigquery-public-data.census_bureau_international.country_names_area\` t1
WHERE
   t0.country_name = t1.country_name
"
echo "$Task 4 completed successfully!"
echo

# Bonus Task: Update mobility data
echo "BONUS TASK: Updating mobility data"
echo "Updating mobility metrics..."
bq query --use_legacy_sql=false \
"
UPDATE
   \`$DATASET_NAME_2.consolidate_covid_tracker_data\` t0
SET
   t0.mobility.avg_retail      = t1.avg_retail,
   t0.mobility.avg_grocery     = t1.avg_grocery,
   t0.mobility.avg_parks       = t1.avg_parks,
   t0.mobility.avg_transit     = t1.avg_transit,
   t0.mobility.avg_workplace   = t1.avg_workplace,
   t0.mobility.avg_residential = t1.avg_residential
FROM
   (SELECT country_region, date,
      AVG(retail_and_recreation_percent_change_from_baseline) as avg_retail,
      AVG(grocery_and_pharmacy_percent_change_from_baseline)  as avg_grocery,
      AVG(parks_percent_change_from_baseline) as avg_parks,
      AVG(transit_stations_percent_change_from_baseline) as avg_transit,
      AVG(workplaces_percent_change_from_baseline) as avg_workplace,
      AVG(residential_percent_change_from_baseline)  as avg_residential
      FROM \`bigquery-public-data.covid19_google_mobility.mobility_report\`
      GROUP BY country_region, date
   ) AS t1
WHERE
   CONCAT(t0.country_name, t0.date) = CONCAT(t1.country_region, t1.date)
"
echo "$Bonus task completed successfully!"
echo

# Additional data quality checks
echo "Running data quality checks..."
echo "Identifying countries with missing data..."
bq query --use_legacy_sql=false \
"
SELECT DISTINCT country_name
FROM \`$DATASET_NAME_2.oxford_policy_tracker_worldwide\`
WHERE population is NULL
UNION ALL
SELECT DISTINCT country_name
FROM \`$DATASET_NAME_2.oxford_policy_tracker_worldwide\`
WHERE country_area IS NULL
ORDER BY country_name ASC
"

# Create additional tables for analysis
echo "Creating country_area_data table..."
bq query --use_legacy_sql=false \
"
CREATE TABLE $DATASET_NAME_2.country_area_data AS
SELECT *
FROM \`bigquery-public-data.census_bureau_international.country_names_area\`;
"

echo "Creating mobility_data table..."
bq query --use_legacy_sql=false \
"CREATE TABLE $DATASET_NAME_2.mobility_data AS
SELECT *
FROM \`bigquery-public-data.covid19_google_mobility.mobility_report\`"

# Data cleaning
echo "Cleaning data by removing NULL values..."
bq query --use_legacy_sql=false \
"DELETE FROM covid_data.oxford_policy_tracker_by_countries
WHERE population IS NULL"


bq query --use_legacy_sql=false \
"DELETE FROM covid_data.oxford_policy_tracker_by_countries
WHERE country_area IS NULL"
