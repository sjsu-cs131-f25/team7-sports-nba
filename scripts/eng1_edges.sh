#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <input.tsv> <left_col> <right_col> <N>" >&2
  exit 1
fi
IN="$1"; L="$2"; R="$3"; N="$4"

mkdir -p out logs

awk -F'\t' -v L="$L" -v R="$R" '
  NR>1 {
    l = $L; r = $R
    sub(/\.0$/, "", l); sub(/\.0$/, "", r)
    if (l != "" && r != "" && l != "0" && r != "0") {
      print l "\t" r
    }
  }
' "$IN" | LC_ALL=C sort -t$'\t' -k1,1 -k2,2 > out/edges.tsv

cut -f1 out/edges.tsv | LC_ALL=C sort | uniq -c \
  | awk '{print $2 "\t" $1}' \
  | LC_ALL=C sort -t$'\t' -k2,2nr -k1,1 > out/entity_counts.tsv

awk -v N="$N" -F'\t' '$2>=N{print $1}' out/entity_counts.tsv \
  | LC_ALL=C sort -u > out/_keepers.txt

LC_ALL=C join -t $'\t' -1 1 -2 1 \
  <(LC_ALL=C sort -t$'\t' -k1,1 out/_keepers.txt) \
  <(LC_ALL=C sort -t$'\t' -k1,1 out/edges.tsv) \
  > out/edges_thresholded.tsv

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
