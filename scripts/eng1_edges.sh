#!/usr/bin/env bash
set -euo pipefail
# Usage: scripts/eng1_edges.sh <input.tsv> <left_col> <right_col> <N>
# Outputs: out/edges.tsv, out/entity_counts.tsv, out/edges_thresholded.tsv

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <input.tsv> <left_col> <right_col> <N>" >&2
  exit 1
fi
IN="$1"; L="$2"; R="$3"; N="$4"

mkdir -p out logs

# 1) Build edge list (Left \t Right), skip header, drop empties
awk -F'\t' -v L="$L" -v R="$R" 'NR>1 && $L!="" && $R!="" {print $L "\t" $R}' "$IN" \
  | LC_ALL=C sort -t$'\t' -k1,1 -k2,2 > out/edges.tsv

# 2) Count Left-entity frequencies
cut -f1 out/edges.tsv | LC_ALL=C sort | uniq -c \
  | awk '{print $2 "\t" $1}' \
  | LC_ALL=C sort -t$'\t' -k2,2nr -k1,1 > out/entity_counts.tsv

# 3) Apply threshold (keep Left with freq >= N)
awk -v N="$N" -F'\t' '$2>=N{print $1}' out/entity_counts.tsv \
  | LC_ALL=C sort -u > out/_keepers.txt

LC_ALL=C join -t $'\t' -1 1 -2 1 \
  <(LC_ALL=C sort -t$'\t' -k1,1 out/_keepers.txt) \
  <(LC_ALL=C sort -t$'\t' -k1,1 out/edges.tsv) \
  > out/edges_thresholded.tsv

# Log
{
  echo "Input:        $IN"
  echo "Left col:     $L"
  echo "Right col:    $R"
  echo "Threshold N:  $N"
  echo "Edges:        $(wc -l < out/edges.tsv)"
  echo "Entities:     $(wc -l < out/entity_counts.tsv)"
  echo "Kept edges:   $(wc -l < out/edges_thresholded.tsv)"
  echo "Run date:     $(date -Is)"
} | tee logs/eng1_run.log

rm -f out/_keepers.txt
