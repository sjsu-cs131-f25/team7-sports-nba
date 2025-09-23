#!/bin/bash
# Usage: ./scripts/skinny_table.sh <input_file> <output_file> <delimiter>
# Example: ./scripts/skinny_table.sh data/samples/sample_play_by_play.csv out/skinny_table.txt ','

input=$1
output=$2
delim=$3

cut -d "$delim" -f1,4,8 "$input" | sort -u > "$output"

echo "Skinny table saved to $output"

