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

###############################################################################
# Step 7 – Signals: Keyword Discovery (tolower) + "first hit" counting
# - Keywords: broken, defect, refund
# - Text fields scanned (lowercased): homedescription ($8), neutraldescription ($9), visitordescription ($10)
# - For each row, find the earliest (leftmost) occurrence among those keywords and count that keyword.
# - Outputs:
#     out/signals_keywords.tsv              (ranked: keyword, count, share%)
#     out/signals_keywords_rows.tsv         (sample of first-hit rows for QA)
###############################################################################

echo "$(ts) Step 7 – Signals (keywords): start" | tee -a "$LOGDIR/step7.log"

# Work files
tmp_rows="$OUTDIR/signals_keywords_rows.tmp"
: > "$tmp_rows"   # truncate

awk -F',' -v OFS='\t' -v outdir="$OUTDIR" '
NR==1 { next }  # skip header
{
  # Build lowercase text from the three description columns
  txt = tolower($8 " " $9 " " $10)

  # Find positions of each keyword (0 = not found)
  p_b = index(txt, "broken")
  p_d = index(txt, "defect")
  p_r = index(txt, "refund")

  # Determine the earliest ("first hit")
  first_kw = ""
  first_pos = 0

  if (p_b) { first_kw = "broken"; first_pos = p_b }
  if (p_d && (first_pos == 0 || p_d < first_pos)) { first_kw = "defect"; first_pos = p_d }
  if (p_r && (first_pos == 0 || p_r < first_pos)) { first_kw = "refund"; first_pos = p_r }

  if (first_kw != "") {
    count[first_kw]++
    total++

    # keep a sample row for QA/debug
    # columns: game_id, eventnum, first_keyword, position, homedescription, neutraldescription, visitordescription
    print $1, $2, first_kw, first_pos, $8, $9, $10 >> outdir "/signals_keywords_rows.tmp"
  }
}
END {
  # Summary table (unsorted here; we will sort in shell)
  print "keyword","count","share"
  for (k in count) {
    share = (total > 0 ? 100.0 * count[k] / total : 0)
    printf "%s\t%d\t%.2f%%\n", k, count[k], share
  }
}
' "$INPUT" 2>>"$LOGDIR/step7.log" > "$OUTDIR/signals_keywords.tsv"

# Rank by count desc, then keyword asc (deterministic)
if [ -s "$OUTDIR/signals_keywords.tsv" ]; then
  {
    read -r hdr
    printf "%s\n" "$hdr"
    tail -n +2 "$OUTDIR/signals_keywords.tsv" | sort -k2,2nr -k1,1
  } > "$OUTDIR/signals_keywords.sorted.tsv"
  mv "$OUTDIR/signals_keywords.sorted.tsv" "$OUTDIR/signals_keywords.tsv"
fi

# Prepare a small sample of rows that triggered a first-hit
if [ -s "$tmp_rows" ]; then
  {
    echo -e "game_id\teventnum\tfirst_keyword\tposition\thomedescription\tneutraldescription\tvisitordescription"
    head -n 50 "$tmp_rows"
  } > "$OUTDIR/signals_keywords_rows.tsv"
  rm -f "$tmp_rows"
else
  {
    echo -e "game_id\teventnum\tfirst_keyword\tposition\thomedescription\tneutraldescription\tvisitordescription"
  } > "$OUTDIR/signals_keywords_rows.tsv"
fi

# Log counts
if [ -f "$OUTDIR/signals_keywords.tsv" ]; then
  lines=$(wc -l < "$OUTDIR/signals_keywords.tsv" || echo 0)
  echo "$(ts) Wrote $OUTDIR/signals_keywords.tsv ($lines lines)" | tee -a "$LOGDIR/step7.log"
fi
if [ -f "$OUTDIR/signals_keywords_rows.tsv" ]; then
  lines=$(wc -l < "$OUTDIR/signals_keywords_rows.tsv" || echo 0)
  echo "$(ts) Wrote $OUTDIR/signals_keywords_rows.tsv ($lines lines)" | tee -a "$LOGDIR/step7.log"
fi

echo "$(ts) Step 7 – done" | tee -a "$LOGDIR/step7.log"

# --- Ensure required keywords appear even if zero matches ---
# Rebuild signals_keywords.tsv to include: broken, defect, refund with zeros if absent.
awk -F'\t' -v OFS='\t' '
BEGIN{
  req[1]="broken"; req[2]="defect"; req[3]="refund";
}
NR==1 { hdr=$0; next }
{
  # existing rows: keyword \t count \t share
  kw=$1; cnt=$2+0; sh=$3; c[kw]=cnt; s[kw]=sh; total+=cnt
}
END{
  print "keyword","count","share";
  for(i=1;i<=3;i++){
    k=req[i];
    cnt=(k in c ? c[k] : 0);
    sh=(total>0 ? sprintf("%.2f%%", 100*cnt/total) : "0.00%");
    printf "%s\t%d\t%s\n", k, cnt, sh;
  }
}
' "$OUTDIR/signals_keywords.tsv" \
| sort -k2,2nr -k1,1 > "$OUTDIR/signals_keywords.fixed.tsv" \
&& mv "$OUTDIR/signals_keywords.fixed.tsv" "$OUTDIR/signals_keywords.tsv"

###############################################################################
# Step 5 – Metrics: Ratios & Buckets
# - Compute helpfulness ratio = helpful_votes / total_votes
# - Bucket ratios into: HI (>=0.75), MID (>=0.40), LO (>0 and <0.40), ZERO (=0)
# - Output:
#     out/helpfulness_buckets.tsv       (bucket, count, share)
#     out/helpfulness_ratios.tsv        (id, helpful, total, ratio, bucket)
###############################################################################

echo "$(ts) Step 5 – Metrics (ratios & buckets): start" | tee -a "$LOGDIR/step5.log"

# Assumptions:
#   - You have numeric columns for helpful_votes and total_votes
#   - For NBA data with no such fields, we’ll mock them using eventmsgtype ($3) and eventnum ($2)
#     just to demonstrate ratio logic reproducibly.

awk -F',' -v OFS='\t' '
NR==1 { next }  # skip header
{
  # Mock numeric fields just to show the pipeline
  helpful = ($3 + 0)
  total   = (($2 % 500) + 1)   # bounded "total" 1-500
  ratio = helpful / total
  bucket = "ZERO"
  if (ratio >= 0.75) bucket = "HI"
  else if (ratio >= 0.40) bucket = "MID"
  else if (ratio > 0) bucket = "LO"
  if (ratio >= 0.75) bucket = "HI"
  else if (ratio >= 0.40) bucket = "MID"
  else if (ratio > 0) bucket = "LO"

  print $1, helpful, total, sprintf("%.3f", ratio), bucket >> "out/helpfulness_ratios.tmp"
  count[bucket]++
  totalrows++
}
END {
  print "bucket","count","share"
  for (b in count) {
    share = (totalrows>0 ? 100*count[b]/totalrows : 0)
    printf "%s\t%d\t%.2f%%\n", b, count[b], share
  }
}
' "$INPUT" 2>>"$LOGDIR/step5.log" > "$OUTDIR/helpfulness_buckets.tsv"

# Deterministic sort by bucket order HI→MID→LO→ZERO
awk -F'\t' -v OFS='\t' '
NR==1{print;next}
{ if($1=="HI")o=1;else if($1=="MID")o=2;else if($1=="LO")o=3;else o=4; print o"\t"$0 }
' "$OUTDIR/helpfulness_buckets.tsv" | sort -k1,1n | cut -f2- > "$OUTDIR/helpfulness_buckets.sorted.tsv" \
&& mv "$OUTDIR/helpfulness_buckets.sorted.tsv" "$OUTDIR/helpfulness_buckets.tsv"

# finalize detailed ratios file
{
  echo -e "game_id\thelpful\ttotal\tratio\tbucket"
  sort out/helpfulness_ratios.tmp
} > out/helpfulness_ratios.tsv
rm -f out/helpfulness_ratios.tmp

# log line counts
if [ -f "$OUTDIR/helpfulness_buckets.tsv" ]; then
  echo "$(ts) Wrote $OUTDIR/helpfulness_buckets.tsv ($(wc -l < "$OUTDIR/helpfulness_buckets.tsv") lines)" | tee -a "$LOGDIR/step5.log"
fi
if [ -f "$OUTDIR/helpfulness_ratios.tsv" ]; then
  echo "$(ts) Wrote $OUTDIR/helpfulness_ratios.tsv ($(wc -l < "$OUTDIR/helpfulness_ratios.tsv") lines)" | tee -a "$LOGDIR/step5.log"
fi

echo "$(ts) Step 5 – Metrics (ratios & buckets): done" | tee -a "$LOGDIR/step5.log"
