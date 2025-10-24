#!/usr/bin/env bash
set -euo pipefail

OUTDIR="out"
LOGDIR="logs"
mkdir -p "$OUTDIR" "$LOGDIR"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

if [ $# -ne 1 ]; then
  echo "Usage: bash run_pa4.sh <INPUT_CSV>" >&2
  exit 1
fi

INPUT="$1"

# Make sure we (and graders) can read inputs
chmod -R g+rX "$(dirname "$INPUT")" 2>/dev/null || true

if [ ! -r "$INPUT" ]; then
  echo "Error: cannot read input file: $INPUT" >&2
  exit 1
fi

echo "$(ts) Step 6 – Temporal Summary by Season-Year: start" | tee -a "$LOGDIR/step6.log"

# CSV layout (confirmed via header):
# $1=game_id (e.g., 0021400117). YY season is substr($1,4,2) -> 14 -> 2014 season
# $12=scoremargin (numeric; may be blank)
#
# Output: out/temporal_summary.tsv with header: season_year \t avg_scoremargin \t n
# Deterministic sort by season_year ascending.

awk -F',' -v OFS='\t' '
NR==1 { next }  # skip header
{
  # derive season year (YYYY) from game_id "002YY....."
  yy = substr($1, 4, 2)
  if (yy ~ /^[0-9][0-9]$/) {
    year = 2000 + yy + 0
    m = $12
    if (m ~ /^-?[0-9]+(\.[0-9]+)?$/) {
      sum[year] += m + 0
      cnt[year] += 1
    }
  }
}
END {
  print "season_year","avg_scoremargin","n"
  for (y in sum) {
    avg = (cnt[y] ? sum[y]/cnt[y] : 0)
    printf "%d\t%.4f\t%d\n", y, avg, cnt[y]
  }
}
' "$INPUT" 2>>"$LOGDIR/step6.log" | sort -k1,1n > "$OUTDIR/temporal_summary.tsv"

# log a quick line count
if [ -f "$OUTDIR/temporal_summary.tsv" ]; then
  lines=$(wc -l < "$OUTDIR/temporal_summary.tsv" || echo 0)
  echo "$(ts) Wrote $OUTDIR/temporal_summary.tsv ($lines lines)" | tee -a "$LOGDIR/step6.log"
fi

echo "$(ts) Step 6 – done" | tee -a "$LOGDIR/step6.log"
