#!/bin/bash
set -euo pipefail

echo "=============================================="
echo "     Starting Soccer Analytics Pipeline"
echo "=============================================="

# --- Prompt for Required Inputs ---
read -rp "Enter event table name (e.g., events): " EVENT
read -rp "Enter table name (e.g., tags2name): " TABLE
read -rp "Enter model name (e.g., soccer.xg_model): " MODEL
read -rp "Enter value for VALUE_X1: " VALUE_X1
read -rp "Enter value for VALUE_Y1: " VALUE_Y1
read -rp "Enter value for VALUE_X2: " VALUE_X2
read -rp "Enter value for VALUE_Y2: " VALUE_Y2
read -rp "Enter UDF function name for FUNC_1 (e.g., soccer.shot_distance): " FUNC_1
read -rp "Enter UDF function name for FUNC_2 (e.g., soccer.shot_angle): " FUNC_2


# --- Load Data into BigQuery ---
bq load --source_format=NEWLINE_DELIMITED_JSON --autodetect "$DEVSHELL_PROJECT_ID:soccer.$EVENT" gs://spls/bq-soccer-analytics/events.json
bq load --source_format=CSV --autodetect "$DEVSHELL_PROJECT_ID:soccer.$TABLE" gs://spls/bq-soccer-analytics/tags2name.csv
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON "$DEVSHELL_PROJECT_ID:soccer.competitions" gs://spls/bq-soccer-analytics/competitions.json
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON "$DEVSHELL_PROJECT_ID:soccer.matches" gs://spls/bq-soccer-analytics/matches.json
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON "$DEVSHELL_PROJECT_ID:soccer.teams" gs://spls/bq-soccer-analytics/teams.json
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON "$DEVSHELL_PROJECT_ID:soccer.players" gs://spls/bq-soccer-analytics/players.json
bq load --autodetect --source_format=NEWLINE_DELIMITED_JSON "$DEVSHELL_PROJECT_ID:soccer.events" gs://spls/bq-soccer-analytics/events.json

# --- Query: PK Success Rate ---
bq query --use_legacy_sql=false "
SELECT
  playerId,
  (Players.firstName || ' ' || Players.lastName) AS playerName,
  COUNT(id) AS numPKAtt,
  SUM(IF(101 IN UNNEST(tags.id), 1, 0)) AS numPKGoals,
  SAFE_DIVIDE(SUM(IF(101 IN UNNEST(tags.id), 1, 0)), COUNT(id)) AS PKSuccessRate
FROM
  \`soccer.$EVENT\` Events
LEFT JOIN \`soccer.players\` Players ON Events.playerId = Players.wyId
WHERE eventName = 'Free Kick' AND subEventName = 'Penalty'
GROUP BY playerId, playerName
HAVING numPKAtt >= 5
ORDER BY PKSuccessRate DESC, numPKAtt DESC
"

# --- Query: Shot Distance Summary ---
bq query --use_legacy_sql=false "
WITH Shots AS (
  SELECT
    *,
    (101 IN UNNEST(tags.id)) AS isGoal,
    SQRT(
      POW((100 - positions[ORDINAL(1)].x) * $VALUE_X1 / $VALUE_Y1, 2) +
      POW((60 - positions[ORDINAL(1)].y) * $VALUE_X2 / $VALUE_Y2, 2)
    ) AS shotDistance
  FROM \`soccer.$EVENT\`
  WHERE eventName = 'Shot' OR (eventName = 'Free Kick' AND subEventName IN ('Free kick shot', 'Penalty'))
)
SELECT
  ROUND(shotDistance, 0) AS ShotDistRound0,
  COUNT(*) AS numShots,
  SUM(IF(isGoal, 1, 0)) AS numGoals,
  AVG(IF(isGoal, 1, 0)) AS goalPct
FROM Shots
WHERE shotDistance <= 50
GROUP BY ShotDistRound0
ORDER BY ShotDistRound0
"

# --- Create Model ---
bq query --use_legacy_sql=false "
CREATE MODEL \`$MODEL\`
OPTIONS(
  model_type = 'LOGISTIC_REG',
  input_label_cols = ['isGoal']
) AS
SELECT
  Events.subEventName AS shotType,
  (101 IN UNNEST(Events.tags.id)) AS isGoal,
  \`$FUNC_1\`(Events.positions[ORDINAL(1)].x, Events.positions[ORDINAL(1)].y) AS shotDistance,
  \`$FUNC_2\`(Events.positions[ORDINAL(1)].x, Events.positions[ORDINAL(1)].y) AS shotAngle
FROM \`soccer.$EVENT\` Events
LEFT JOIN \`soccer.matches\` Matches ON Events.matchId = Matches.wyId
LEFT JOIN \`soccer.competitions\` Competitions ON Matches.competitionId = Competitions.wyId
WHERE Competitions.name != 'World Cup'
  AND (eventName = 'Shot' OR (eventName = 'Free Kick' AND subEventName IN ('Free kick shot', 'Penalty')))
  AND \`$FUNC_2\`(Events.positions[ORDINAL(1)].x, Events.positions[ORDINAL(1)].y) IS NOT NULL
"

# --- Predict with Model ---
bq query --use_legacy_sql=false "
SELECT
  predicted_isGoal_probs[ORDINAL(1)].prob AS predictedGoalProb,
  * EXCEPT (predicted_isGoal, predicted_isGoal_probs)
FROM
  ML.PREDICT(MODEL \`$MODEL\`, (
    SELECT
      Events.playerId,
      (Players.firstName || ' ' || Players.lastName) AS playerName,
      Teams.name AS teamName,
      CAST(Matches.dateutc AS DATE) AS matchDate,
      Matches.label AS match,
      CAST(
        (CASE
          WHEN Events.matchPeriod = '1H' THEN 0
          WHEN Events.matchPeriod = '2H' THEN 45
          WHEN Events.matchPeriod = 'E1' THEN 90
          WHEN Events.matchPeriod = 'E2' THEN 105
          ELSE 120
        END) + CEILING(Events.eventSec / 60)
      AS INT64) AS matchMinute,
      Events.subEventName AS shotType,
      (101 IN UNNEST(Events.tags.id)) AS isGoal,
      \`$FUNC_1\`(Events.positions[ORDINAL(1)].x, Events.positions[ORDINAL(1)].y) AS shotDistance,
      \`$FUNC_2\`(Events.positions[ORDINAL(1)].x, Events.positions[ORDINAL(1)].y) AS shotAngle
    FROM \`soccer.$EVENT\` Events
    LEFT JOIN \`soccer.matches\` Matches ON Events.matchId = Matches.wyId
    LEFT JOIN \`soccer.competitions\` Competitions ON Matches.competitionId = Competitions.wyId
    LEFT JOIN \`soccer.players\` Players ON Events.playerId = Players.wyId
    LEFT JOIN \`soccer.teams\` Teams ON Events.teamId = Teams.wyId
    WHERE Competitions.name = 'World Cup'
      AND (eventName = 'Shot' OR (eventName = 'Free Kick' AND subEventName = 'Free kick shot'))
      AND (101 IN UNNEST(Events.tags.id))
  ))
ORDER BY predictedGoalProb
"


echo "➡️  Open BigQuery Console to check your datasets:"
echo "🔗 https://console.cloud.google.com/bigquery"