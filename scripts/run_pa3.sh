#!/usr/bin/env bash
# ================================================
# CS131 - PA3 Full Pipeline (Steps 1–6)
# Team: team7-sports-nba
# ================================================

set -euo pipefail

ROOT="$HOME/team7-sports-nba"
OUT="$ROOT/out"
TMP="$ROOT/tmp"
LOG="$ROOT/logs"

mkdir -p "$OUT" "$TMP" "$LOG"

echo "=== PA3 Full Pipeline (Steps 1–6) ==="
date

# Step 1 - Normalize edges
echo "[Step 1] Sorting edges..."
LC_ALL=C sort -k1,1 -k2,2 "$OUT/edges.tsv" > "$OUT/edges.sorted.tsv"
cp "$OUT/edges.sorted.tsv" "$OUT/edges.tsv"

# Step 2 - Filter clusters by frequency (threshold=2)
echo "[Step 2] Filtering clusters..."
cut -f1 "$OUT/edges.tsv" | sort | uniq -c | awk '{print $2"\t"$1}' | sort -k2,2nr > "$OUT/entity_counts.tsv"
awk -v N=2 'FNR==NR{f[$1]=$2; next} (f[$1]>=N)' "$OUT/entity_counts.tsv" "$OUT/edges.tsv" > "$OUT/edges_thresholded.tsv"

# Step 3 - Histogram (cluster sizes)
echo "[Step 3] Building cluster size histogram..."
cut -f1 "$OUT/edges_thresholded.tsv" | sort | uniq -c | awk '{print $1}' > "$TMP/sizes_raw.txt"
awk '{h[$1]++} END{for(k in h) print k"\t"h[k]}' "$TMP/sizes_raw.txt" | sort -k1,1n > "$OUT/cluster_sizes.tsv"

# Step 4 - Top 30 tokens (overall vs clusters)
echo "[Step 4] Computing top tokens..."
cut -f2 "$OUT/skinny_table.txt" | tr '[:upper:]' '[:lower:]' | grep -oE '[a-z]+' | sort | uniq -c | sort -nr | awk '{print $2"\t"$1}' > "$OUT/top30_overall.txt"
head -n 30 "$OUT/top30_overall.txt" > "$OUT/top30_clusters.txt"
diff -u "$OUT/top30_overall.txt" "$OUT/top30_clusters.txt" > "$OUT/diff_top30.txt" || true

# Step 5 - Network visualization subset
echo "[Step 5] Extracting visualization edges..."
TOP_LEFT=$(cut -f1 "$OUT/edges_thresholded.tsv" | sort | uniq -c | sort -nr | head -1 | awk '{$1=""; sub(/^ /,""); print}')
awk -F'\t' -v a="$TOP_LEFT" '$1==a{print $0}' "$OUT/edges_thresholded.tsv" > "$OUT/cluster_anchor_edges.tsv"
{ echo "source,target"; sed 's/\t/,/g' "$OUT/cluster_anchor_edges.tsv"; } > "$OUT/cluster_anchor_edges.csv"

# Step 6 - Summary statistics using datamash
echo "[Step 6] Computing summary statistics..."
source ~/.bashrc
if command -v datamash >/dev/null 2>&1; then
  awk -F'\t' '{print $1, length($2)}' "$OUT/skinny_table.txt" | datamash -g 1 count 2 mean 2 median 2 > "$OUT/cluster_outcomes.tsv"
  echo "✓ cluster_outcomes.tsv generated"
else
  echo "⚠️ datamash not found. Skipping Step 6."
fi

echo "=== DONE ==="
date

