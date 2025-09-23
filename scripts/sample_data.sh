#!/bin/bash
# Usage: ./scripts/sample_data.sh <input_file> <output_file>
# Example: ./scripts/sample_data.sh data/raw/play_by_play.csv data/samples/sample_play_by_play.csv

input=$1
output=$2

if command -v shuf > /dev/null; then
    sampler="shuf -n 1000"
else
    sampler="sort -R | head -n 1000"
fi

{ head -n 1 "$input" && tail -n +2 "$input" | eval $sampler; } > "$output"

echo "Sample saved to $output" 

