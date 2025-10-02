
echo -n "Enter the TABLE_NAME:"
read -r TABLE_NAME
    

echo -n "Enter the FARE_AMOUNT_NAME:"
read -r FARE_AMOUNT_NAME


echo -n "Enter the TRIP_DISTANCE_NO:"
read -r TRIP_DISTANCE_NO


echo -n "Enter the FARE_AMOUNT:"
read -r FARE_AMOUNT


# echo -n "Enter the PASSENGER_COUNT:"
# read -r PASSENGER_COUNT


echo -n "Enter the MODEL_NAME:"
read -r MODEL_NAME


bq query --use_legacy_sql=false "

CREATE OR REPLACE TABLE
  taxirides.${TABLE_NAME} AS
SELECT
  (tolls_amount + fare_amount) AS ${FARE_AMOUNT_NAME},
  pickup_datetime,
  pickup_longitude AS pickuplon,
  pickup_latitude AS pickuplat,
  dropoff_longitude AS dropofflon,
  dropoff_latitude AS dropofflat,
  passenger_count AS passengers,
FROM
  taxirides.historical_taxi_rides_raw
WHERE
  RAND() < 0.001
  AND trip_distance > ${TRIP_DISTANCE_NO}
  AND fare_amount >= ${FARE_AMOUNT}
  AND pickup_longitude > -78
  AND pickup_longitude < -70
  AND dropoff_longitude > -78
  AND dropoff_longitude < -70
  AND pickup_latitude > 37
  AND pickup_latitude < 45
  AND dropoff_latitude > 37
  AND dropoff_latitude < 45
  AND passenger_count > ${TRIP_DISTANCE_NO};
"

bq query --use_legacy_sql=false "
  CREATE OR REPLACE MODEL taxirides.${MODEL_NAME}
TRANSFORM(
  * EXCEPT(pickup_datetime)

  , ST_Distance(ST_GeogPoint(pickuplon, pickuplat), ST_GeogPoint(dropofflon, dropofflat)) AS euclidean
  , CAST(EXTRACT(DAYOFWEEK FROM pickup_datetime) AS STRING) AS dayofweek
  , CAST(EXTRACT(HOUR FROM pickup_datetime) AS STRING) AS hourofday
)
OPTIONS(input_label_cols=['${FARE_AMOUNT_NAME}'], model_type='linear_reg')
AS
SELECT * FROM taxirides.${TABLE_NAME};
"


bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE taxirides.2015_fare_amount_predictions
  AS
SELECT * FROM ML.PREDICT(MODEL taxirides.${MODEL_NAME},(
  SELECT * FROM taxirides.report_prediction_data)
);"