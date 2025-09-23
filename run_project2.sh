#!/bin/bash
# Usage: ./run_project2.sh <sample_dataset> <delimiter>
# Example: ./run_project2.sh data/samples/sample_play_by_play.csv ','

set -e

dataset=$1
delim=$2

echo "=== Running Project 2 Pipeline (Sample Only) ==="
mkdir -p out logs

./scripts/skinny_table.sh "$dataset" out/skinny_table.txt "$delim"

cut -d "$delim" -f8 "$dataset" | sort | uniq -c | sort -nr | tee out/freq_event_types.txt

cut -d "$delim" -f4 "$dataset" > out/player_ids.txt 2> logs/errors.log

echo "Pipeline complete. Outputs in /out and logs in /logs"

