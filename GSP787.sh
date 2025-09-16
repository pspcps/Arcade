#!/bin/bash
#!/bin/bash

echo "Task 1. Total confirmed cases"

# Prompt for month input
echo -n "Please enter the month (format: MM or Apr or April): "
read input_month_raw

# Normalize to lowercase for comparison
input_month=$(echo "$input_month_raw" | tr '[:upper:]' '[:lower:]')

# Map to MM
case $input_month in
  "01"|"jan"|"january")   input_month="01" ;;
  "02"|"feb"|"february")  input_month="02" ;;
  "03"|"mar"|"march")     input_month="03" ;;
  "04"|"apr"|"april")     input_month="04" ;;
  "05"|"may")             input_month="05" ;;
  "06"|"jun"|"june")      input_month="06" ;;
  "07"|"jul"|"july")      input_month="07" ;;
  "08"|"aug"|"august")    input_month="08" ;;
  "09"|"sep"|"september") input_month="09" ;;
  "10"|"oct"|"october")   input_month="10" ;;
  "11"|"nov"|"november")  input_month="11" ;;
  "12"|"dec"|"december")  input_month="12" ;;
  *)
    echo "❌ Invalid month input: '$input_month_raw'"
    exit 1
    ;;
esac

# Prompt for day
echo -n "Please enter the day (format: DD): "
read input_day

# Pad day with leading zero if needed
if [[ ${#input_day} -eq 1 ]]; then
  input_day="0$input_day"
fi

# Construct full date
year="2020"
input_date="${year}-${input_month}-${input_day}"

echo "📅 Querying for date: $input_date"

# Run BigQuery
bq query --use_legacy_sql=false \
"SELECT SUM(cumulative_confirmed) AS total_cases_worldwide
 FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\`
 WHERE date = '${input_date}'"


# Task 2 - Worst affected areas
echo
echo "Task 2. Worst affected areas"
echo -n "Please enter the death count threshold: "
read death_threshold

bq query --use_legacy_sql=false \
"WITH deaths_by_states AS (
    SELECT subregion1_name as state, sum(cumulative_deceased) as death_count
    FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\`
    WHERE country_name='United States of America' 
      AND date='${input_date}' 
      AND subregion1_name IS NOT NULL
    GROUP BY subregion1_name
)
SELECT count(*) as count_of_states
FROM deaths_by_states
WHERE death_count > ${death_threshold}"

# Task 3 - Identify hotspots
echo
echo "Task 3. Identify hotspots"
echo -n "Please enter the confirmed case threshold: "
read case_threshold

bq query --use_legacy_sql=false \
"SELECT * FROM (
    SELECT subregion1_name as state, sum(cumulative_confirmed) as total_confirmed_cases
    FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\`
    WHERE country_code='US' AND date='${input_date}' AND subregion1_name IS NOT NULL
    GROUP BY subregion1_name
    ORDER BY total_confirmed_cases DESC
)
WHERE total_confirmed_cases > ${case_threshold}"
#!/bin/bash

# Task 4 - Fatality ratio
echo
echo "Task 4. Fatality ratio"

# Prompt for month input
echo -n "Please enter the month (format: MM, Apr, April, etc.): "
read input_month_raw

# Normalize to lowercase
input_month=$(echo "$input_month_raw" | tr '[:upper:]' '[:lower:]')

# Hardcoded year
year="2020"

# Convert to MM and determine max days
case $input_month in
  "01"|"jan"|"january")   mm="01"; max_day="31" ;;
  "02"|"feb"|"february")
    mm="02"
    # Leap year check for 2020
    max_day="29"
    ;;
  "03"|"mar"|"march")     mm="03"; max_day="31" ;;
  "04"|"apr"|"april")     mm="04"; max_day="30" ;;
  "05"|"may")             mm="05"; max_day="31" ;;
  "06"|"jun"|"june")      mm="06"; max_day="30" ;;
  "07"|"jul"|"july")      mm="07"; max_day="31" ;;
  "08"|"aug"|"august")    mm="08"; max_day="31" ;;
  "09"|"sep"|"september") mm="09"; max_day="30" ;;
  "10"|"oct"|"october")   mm="10"; max_day="31" ;;
  "11"|"nov"|"november")  mm="11"; max_day="30" ;;
  "12"|"dec"|"december")  mm="12"; max_day="31" ;;
  *)
    echo "❌ Invalid month input: '$input_month_raw'"
    exit 1
    ;;
esac

# Build start and end date
start_date="${year}-${mm}-01"
end_date="${year}-${mm}-${max_day}"

echo "📅 Calculating fatality ratio for: $start_date to $end_date"

# Run BigQuery
bq query --use_legacy_sql=false \
"SELECT
   SUM(cumulative_confirmed) AS total_confirmed_cases,
   SUM(cumulative_deceased) AS total_deaths,
   SAFE_DIVIDE(SUM(cumulative_deceased), SUM(cumulative_confirmed)) * 100 AS case_fatality_ratio
FROM
  \`bigquery-public-data.covid19_open_data.covid19_open_data\`
WHERE
  country_name = 'Italy'
  AND date BETWEEN '${start_date}' AND '${end_date}'"


# Task 5 - Identifying specific day
echo
echo "Task 5. Identifying specific day"
echo -n "Please enter the death threshold: "
read death_threshold

bq query --use_legacy_sql=false \
"SELECT date
 FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\`
 WHERE country_name='Italy' AND cumulative_deceased > ${death_threshold}
 ORDER BY date ASC
 LIMIT 1"
#!/bin/bash

echo
echo "Task 6. Finding days with zero net new cases"

#!/bin/bash

# Function to convert "23, Feb 2020" -> "2020-02-23"
convert_to_yyyymmdd() {
  local input="$1"

  # Remove commas
  input=${input//,/}

  # Split into day, month, year
  read -r day month year <<< "$input"

  # Check if all parts exist
  if [[ -z "$day" || -z "$month" || -z "$year" ]]; then
    echo ""
    return 1
  fi

  # Normalize month to lowercase
  month=$(echo "$month" | tr '[:upper:]' '[:lower:]')

  # Map month name to number
  case "$month" in
    jan* ) month_num="01" ;;
    feb* ) month_num="02" ;;
    mar* ) month_num="03" ;;
    apr* ) month_num="04" ;;
    may  ) month_num="05" ;;
    jun* ) month_num="06" ;;
    jul* ) month_num="07" ;;
    aug* ) month_num="08" ;;
    sep* ) month_num="09" ;;
    oct* ) month_num="10" ;;
    nov* ) month_num="11" ;;
    dec* ) month_num="12" ;;
    * )
      echo ""
      return 1
      ;;
  esac

  # Pad day with leading zero if needed
  if (( 10#$day < 10 )); then
    day="0$day"
  fi

  # Return ISO format date
  echo "${year}-${month_num}-${day}"
}

echo
echo "🧮 Task 6. Finding days with zero net new cases"

# Prompt user
echo -n "📅 Please enter the start date (e.g. 23, Feb 2020): "
read raw_start_date
echo -n "📅 Please enter the end date (e.g. 11, March 2020): "
read raw_end_date

# Convert dates
start_date=$(convert_to_yyyymmdd "$raw_start_date")
end_date=$(convert_to_yyyymmdd "$raw_end_date")

# Check conversion success
if [[ -z "$start_date" || -z "$end_date" ]]; then
  echo "❌ Could not parse one or both dates."
  echo "⚠️ Skipping query. Please check your date format."
else
  echo "✅ Using date range: $start_date to $end_date"
  echo

  # Run BigQuery query
  bq query --use_legacy_sql=false \
  "WITH india_cases_by_date AS (
      SELECT date, SUM(cumulative_confirmed) AS cases
      FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\`
      WHERE country_name = 'India' AND date BETWEEN '${start_date}' AND '${end_date}'
      GROUP BY date
      ORDER BY date
  ),
  india_previous_day_comparison AS (
      SELECT
        date,
        cases,
        LAG(cases) OVER (ORDER BY date) AS previous_day,
        cases - LAG(cases) OVER (ORDER BY date) AS net_new_cases
      FROM india_cases_by_date
  )
  SELECT COUNT(*) AS zero_new_case_days
  FROM india_previous_day_comparison
  WHERE net_new_cases = 0"
fi

echo
echo "✅ Task 6 complete. Continuing script..."




# Task 7 - Doubling rate
echo
echo "Task 7. Doubling rate"
echo -n "Please enter the percentage increase threshold: "
read percentage_threshold

bq query --use_legacy_sql=false \
"WITH us_cases_by_date AS (
    SELECT date, SUM(cumulative_confirmed) AS cases
    FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\`
    WHERE country_name='United States of America' AND date BETWEEN '2020-03-22' AND '2020-04-20'
    GROUP BY date
    ORDER BY date ASC
), us_previous_day_comparison AS (
    SELECT date, cases, LAG(cases) OVER(ORDER BY date) AS previous_day,
           cases - LAG(cases) OVER(ORDER BY date) AS net_new_cases,
           (cases - LAG(cases) OVER(ORDER BY date))*100/LAG(cases) OVER(ORDER BY date) AS percentage_increase
    FROM us_cases_by_date
)
SELECT Date, cases AS Confirmed_Cases_On_Day, previous_day AS Confirmed_Cases_Previous_Day, percentage_increase AS Percentage_Increase_In_Cases
FROM us_previous_day_comparison
WHERE percentage_increase > ${percentage_threshold}"

# Task 8 - Recovery rate
echo
echo "Task 8. Recovery rate"
echo -n "Please enter the limit: "
read limit

bq query --use_legacy_sql=false \
"WITH cases_by_country AS (
  SELECT
    country_name AS country,
    sum(cumulative_confirmed) AS cases,
    sum(cumulative_recovered) AS recovered_cases
  FROM
    bigquery-public-data.covid19_open_data.covid19_open_data
  WHERE
    date = '2020-05-10'
  GROUP BY
    country_name
), recovered_rate AS
(SELECT
  country, cases, recovered_cases,
  (recovered_cases * 100)/cases AS recovery_rate
FROM cases_by_country
)
SELECT country, cases AS confirmed_cases, recovered_cases, recovery_rate
FROM recovered_rate
WHERE cases > 50000
ORDER BY recovery_rate DESC
LIMIT ${limit}"

#!/bin/bash
#!/bin/bash

# Function to convert "June 20, 2020" -> "2020-06-20"
convert_month_day_year_to_yyyymmdd() {
  local input="$1"

  # Remove commas
  input=${input//,/}

  # Split into parts: month day year
  read -r month day year <<< "$input"

  # Check if all parts exist
  if [[ -z "$month" || -z "$day" || -z "$year" ]]; then
    echo ""
    return 1
  fi

  # Normalize month name to lowercase
  month=$(echo "$month" | tr '[:upper:]' '[:lower:]')

  # Map month name to number
  case "$month" in
    jan* ) month_num="01" ;;
    feb* ) month_num="02" ;;
    mar* ) month_num="03" ;;
    apr* ) month_num="04" ;;
    may  ) month_num="05" ;;
    jun* ) month_num="06" ;;
    jul* ) month_num="07" ;;
    aug* ) month_num="08" ;;
    sep* ) month_num="09" ;;
    oct* ) month_num="10" ;;
    nov* ) month_num="11" ;;
    dec* ) month_num="12" ;;
    * )
      echo ""
      return 1
      ;;
  esac

  # Pad day with leading zero if needed
  if (( 10#$day < 10 )); then
    day="0$day"
  fi

  # Return ISO format date
  echo "${year}-${month_num}-${day}"
}

echo
echo "🧮 Task 9. CDGR - Cumulative daily growth rate"
echo -n "📅 Please enter the second date (format: June 20, 2020): "
read raw_second_date

second_date=$(convert_month_day_year_to_yyyymmdd "$raw_second_date")

if [[ -z "$second_date" ]]; then
  echo "❌ Invalid date format. Please enter something like: June 20, 2020"
  exit 1
fi

echo "✅ Calculating CDGR between 2020-01-24 and $second_date"
echo

# Run BigQuery query
bq query --use_legacy_sql=false \
"WITH france_cases AS (
    SELECT date, SUM(cumulative_confirmed) AS total_cases
    FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\`
    WHERE country_name = 'France' AND date IN ('2020-01-24', '${second_date}')
    GROUP BY date
    ORDER BY date
), summary AS (
    SELECT
      total_cases AS first_day_cases,
      LEAD(total_cases) OVER(ORDER BY date) AS last_day_cases,
      DATE_DIFF(LEAD(date) OVER(ORDER BY date), date, DAY) AS days_diff
    FROM france_cases
    LIMIT 1
)
SELECT
  first_day_cases,
  last_day_cases,
  days_diff,
  SAFE_MULTIPLY(POWER(SAFE_DIVIDE(last_day_cases, first_day_cases), (1.0 / days_diff)) - 1, 100) AS cdgr_percent
FROM summary"


# Task 10 - Create a Looker Studio report
echo
echo "Task 10. Create a Looker Studio report"
echo -n "Please enter the start date (format: YYYY-MM-DD): "
read start_date
echo -n "Please enter the end date (format: YYYY-MM-DD): "
read end_date

bq query --use_legacy_sql=false \
"SELECT date, SUM(cumulative_confirmed) AS country_cases,
       SUM(cumulative_deceased) AS country_deaths
FROM \`bigquery-public-data.covid19_open_data.covid19_open_data\`
WHERE date BETWEEN '${start_date}' AND '${end_date}'
  AND country_name='United States of America'
GROUP BY date
ORDER BY date"

# Completion message
echo
echo "Analysis Completed Successfully!"
