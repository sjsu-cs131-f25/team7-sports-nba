#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: bash run_pa4.sh <INPUT_FILE>" >&2
  exit 1
fi

INPUT="$1"

#create output/log directories
mkdir -p out logs && : > logs/run.log && export LC_ALL=C

# --- timestamp helper (ensure available before any use) ---
if ! declare -F ts >/dev/null 2>&1; then
  ts() { date '+%Y-%m-%d %H:%M:%S'; }
fi


#Make sure inputs are readable
if [[ -d "$INPUT" ]]; then
  chmod -R g+rX "$INPUT" 2>/dev/null || true
else
  chmod g+r "$INPUT" 2>/dev/null || true
fi

#------ Delimiter detection(CSV vs TSV)----------------
# Count tabs and commas in header to guess the delimiter
header="$(head -n 1 "$INPUT")"
tabs="$(printf "%s" "$header" | tr -cd '\t' | wc -c | tr -d ' ')"
commas="$(printf "%s" "$header" | tr -cd ',' | wc -c | tr -d ' ')"
DELIM="tsv"
[[ "$commas" -gt "$tabs" ]] && DELIM="csv"
echo "Detected $DELIM" | tee -a logs/run.log

#Cleaner ( We purposely donot trim the whole line end to avoid deleting empty fields.)
nba_clean() {
  /usr/bin/sed -E \
    -e $'1s/^\xEF\xBB\xBF//' \
    -e 's/\r$//' \
    -e 's/[[:space:]]*\t[[:space:]]*/\t/g' \
    -e 's/([0-9]),([0-9]{3})/\1\2/g' \
    -e 's/\t(-|NULL|null|N\/A|n\/a|NA|na)(\t|$)/\tNA\2/g'
}

# Step 1 : CSV -> TSV
# for CSV, we parse one char at a time then emit TSV
if [[ "$DELIM" == "csv" ]]; then
  awk -v OFS='\t' '
  {
    nf = 0; field = ""; inq = 0;
    for (i = 1; i <= length($0); i++) {
      ch = substr($0, i, 1);
      if (ch == "\"") {
        if (inq && substr($0, i+1, 1) == "\"") { field = field "\""; i++; }
        else { inq = !inq; }
      } else if (ch == "," && !inq) {
        nf++; f[nf] = field; field = "";
      } else {
        field = field ch;
      }
    }
    nf++; f[nf] = field;

    for (i = 1; i <= nf; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", f[i]);
    out = (nf ? f[1] : "");
    for (i = 2; i <= nf; i++) out = out OFS f[i];
    print out;
  }' "$INPUT" | nba_clean > out/clean.tsv
else
  nba_clean < "$INPUT" > out/clean.tsv
fi

echo "cleaned -> out/clean.tsv" | tee -a logs/run.log

ncols="$(head -n 1 out/clean.tsv | awk -F'\t' '{print NF}')"
awk -F'\t' -v OFS='\t' -v N="$ncols" '
  NR==1 { print; next }
  { if (NF < N) { for (i = NF + 1; i <= N; i++) $i = "" } print }
' out/clean.tsv > out/clean.tsv.tmp && mv out/clean.tsv.tmp out/clean.tsv

tsv_cols="$(head -n 1 out/clean.tsv | awk -F'\t' '{print NF}')"
csv_commas="$(head -n 1 out/clean.tsv | tr -cd ',' | wc -c | tr -d ' ')"
if [[ "$tsv_cols" -eq 1 && "$csv_commas" -gt 0 ]]; then
  awk -v OFS='\t' '
  {
    nf = 0; field = ""; inq = 0;
    for (i = 1; i <= length($0); i++) {
      ch = substr($0, i, 1);
      if (ch == "\"") {
        if (inq && substr($0, i+1, 1) == "\"") { field = field "\""; i++; }
        else { inq = !inq; }
      } else if (ch == "," && !inq) {
        nf++; f[nf] = field; field = "";
      } else {
        field = field ch;
      }
    }
    nf++; f[nf] = field;
    for (i = 1; i <= nf; i++) gsub(/^[[:space:]]+|[[:space:]]+$/, "", f[i]);
    out = (nf ? f[1] : "");
    for (i = 2; i <= nf; i++) out = out OFS f[i];
    print out;
  }' "$INPUT" | nba_clean > out/clean.tsv
  echo "Reconverted CSV to TSV forcefully -> out/clean.tsv" | tee -a logs/run.log
fi

head -n 20 "$INPUT" > out/sample_before.txt
head -n 20 out/clean.tsv > out/sample_after.txt

# Column count sanity check
awk -F'\t' 'NR==1{ncols=NF; next} NF!=ncols{bad++}
END{ if(bad>0) printf("[WARN] %d rows have NF!=%d\n",bad,ncols);
     else printf("[INFO] Column counts consistent (NF=%d)\n",ncols); }' out/clean.tsv | tee -a logs/run.log

echo "Step 1 complete." | tee -a logs/run.log

# ----------------------------------------------------------------------
# Step 2 (original teammates’ exploratory outputs on out/clean.tsv)
# ----------------------------------------------------------------------
# frequenct table 1 : count per column 3
awk -F'\t' 'NR>1 {count[$3]++} END { print "Team\tCount"; for (t in count) print t, count[t] }' OFS='\t' out/clean.tsv | sort -k2,2nr > out/freq_team.tsv
# frequency Table2 : count per column 4
awk -F'\t' 'NR>1 && $4 != "" {pos[$4]++} END { print "Position\tCount"; for (p in pos) print p, pos[p] }' OFS='\t' out/clean.tsv | sort -k2,2nr > out/freq_position.tsv
# Top-N
awk -F'\t' 'NR>1 {pts[$2]+=$6} END { for (p in pts) print p, pts[p] }' OFS='\t' out/clean.tsv | sort -k2,2nr | head -n 10 > out/top10_players.tsv
# Skinny Table
awk -F'\t' 'NR==1 {print $1,$2,$3,$6; next} {print $1,$2,$3,$6}' OFS='\t' out/clean.tsv > out/skinny.tsv

echo "Step 2 complete." | tee -a logs/run.log

###############################################################################
# Step 3 – EDA (Players/Teams)  [ENG2 insert]
# Build robust TSV (clean_v2.tsv) from original INPUT via Python csv (handles quoted commas),
# then compute freq tables and skinny table aligned to pbp schema.
###############################################################################
echo "$(ts) Step 3 – EDA: start" | tee -a logs/run.log

INPUT_PATH="$INPUT" python3 - <<'PY'
import csv, os
inp = os.environ['INPUT_PATH']
out = 'out/clean_v2.tsv'
with open(inp, newline='', encoding='utf-8') as f, open(out,'w', newline='', encoding='utf-8') as g:
    r = csv.reader(f)
    w = csv.writer(g, delimiter='\t')
    for row in r:
        w.writerow([(c or '').strip() for c in row])
PY
echo "[Step 3] built out/clean_v2.tsv via Python csv" | tee -a logs/run.log

# freq_player.tsv (aggregate across name cols: 15, 22, 29)
awk -F'\t' '
NR>1{
  for(i=0;i<3;i++){
    c=(i==0?15:(i==1?22:29))
    n=$c; gsub(/^[ \t]+|[ \t]+$/,"",n)
    if(n!="" && n!="0" && n !~ /^[0-9.]+$/ && index(n," ")>0) cnt[n]++
  }
}
END{ print "player\tcount"; for(k in cnt) printf "%s\t%d\n",k,cnt[k] }
' out/clean_v2.tsv | LC_ALL=C sort -t $'\t' -k2,2nr -k1,1 > out/freq_player.tsv

# freq_team.tsv (aggregate across team abbr cols: 19, 26, 33) – only 2–4 ALL-CAPS
awk -F'\t' '
NR>1{
  for(i=0;i<3;i++){
    c=(i==0?19:(i==1?26:33))
    v=$c; gsub(/^[ \t]+|[ \t]+$/,"",v)
    if(v ~ /^[A-Z]{2,4}$/) cnt[v]++
  }
}
END{ print "team\tcount"; for(k in cnt) printf "%s\t%d\n",k,cnt[k] }
' out/clean_v2.tsv | LC_ALL=C sort -t $'\t' -k2,2nr -k1,1 > out/freq_team.tsv

# skinny.tsv (player, team, position, pts, date blanks)
awk -F'\t' -v OFS='\t' '
BEGIN{print "player","team","position","pts","date"}
NR>1{
  name=""; team=""
  for(i=0;i<3 && name==""; i++){
    c=(i==0?15:(i==1?22:29)); n=$c; gsub(/^[ \t]+|[ \t]+$/,"",n)
    if(n!="" && n!="0" && n !~ /^[0-9.]+$/ && index(n," ")>0) name=n
  }
  for(i=0;i<3 && team==""; i++){
    c=(i==0?19:(i==1?26:33)); v=$c; gsub(/^[ \t]+|[ \t]+$/,"",v)
    if(v ~ /^[A-Z]{2,4}$/) team=v
  }
  print name, team, "", "", ""
}
' out/clean_v2.tsv > out/skinny.tsv

echo "$(ts) Step 3 – EDA: complete." | tee -a logs/run.log

###############################################################################
# Step 3.5 – Filtering (keep rows with a real player or valid team code)
###############################################################################
echo "$(ts) Step 3.5 – Filtering: start" | tee -a logs/run.log

awk -F'\t' -v OFS='\t' '
NR==1{print; next}
{
  has_name = (($14~/^[0-9]+$/ && $15!="") || ($21~/^[0-9]+$/ && $22!="") || ($28~/^[0-9]+$/ && $29!=""))
  has_team = (($19~/^[A-Z]{2,4}$/)      || ($26~/^[A-Z]{2,4}$/)       || ($33~/^[A-Z]{2,4}$/))
  if(has_name || has_team) print
}
' out/clean_v2.tsv > out/filtered.tsv

echo "$(ts) Step 3.5 – Filtering: complete." | tee -a logs/run.log

###############################################################################
# Step 4 – Top-N (players/teams by counts)
###############################################################################
echo "$(ts) Step 4 – Top-N: start" | tee -a logs/run.log

# players
awk -F'\t' '
NR>1{
  name=""
  if    ($14~/^[0-9]+$/ && $15!="") name=$15
  else if($21~/^[0-9]+$/ && $22!="") name=$22
  else if($28~/^[0-9]+$/ && $29!="") name=$29
  if(name!="") cnt[name]++
}
END{ print "player\trows"; for(k in cnt) printf "%s\t%d\n",k,cnt[k] }
' out/filtered.tsv | LC_ALL=C sort -t $'\t' -k2,2nr -k1,1 | head -n 11 > out/top10_players.tsv

# teams
awk -F'\t' '
NR>1{
  team=""
  if    ($19~/^[A-Z]{2,4}$/) team=$19
  else if($26~/^[A-Z]{2,4}$/) team=$26
  else if($33~/^[A-Z]{2,4}$/) team=$33
  if(team!="") cnt[team]++
}
END{ print "team\trows"; for(k in cnt) printf "%s\t%d\n",k,cnt[k] }
' out/filtered.tsv | LC_ALL=C sort -t $'\t' -k2,2nr -k1,1 | head -n 11 > out/top10_teams.tsv

echo "$(ts) Step 4 – Top-N: complete." | tee -a logs/run.log

# ----------------------------------------------------------------------
# (Your teammates’ steps continue below, unchanged)
# ----------------------------------------------------------------------

OUTDIR="out"
LOGDIR="logs"

ts() { date '+%Y-%m-%d %H:%M:%S'; }

if [ ! -r "$INPUT" ]; then
  echo "Error: cannot read input file: $INPUT" >&2
  exit 1
fi

echo "$(ts) Step 6 – Temporal Summary by Season-Year: start" | tee -a "$LOGDIR/step6.log"

awk -F',' -v OFS='\t' '
NR==1 { next }
{
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

if [ -f "$OUTDIR/temporal_summary.tsv" ]; then
  lines=$(wc -l < "$OUTDIR/temporal_summary.tsv" || echo 0)
  echo "$(ts) Wrote $OUTDIR/temporal_summary.tsv ($lines lines)" | tee -a "$LOGDIR/step6.log"
fi

echo "$(ts) Step 6 – done" | tee -a "$LOGDIR/step6.log"

###############################################################################
# Step 7 – Signals: Keyword Discovery (tolower) + "first hit" counting
###############################################################################

echo "$(ts) Step 7 – Signals (keywords): start" | tee -a "$LOGDIR/step7.log"

tmp_rows="$OUTDIR/signals_keywords_rows.tmp"
: > "$tmp_rows"

awk -F',' -v OFS='\t' -v outdir="$OUTDIR" '
NR==1 { next }
{
  txt = tolower($8 " " $9 " " $10)
  p_b = index(txt, "broken")
  p_d = index(txt, "defect")
  p_r = index(txt, "refund")

  first_kw = ""; first_pos = 0
  if (p_b) { first_kw = "broken"; first_pos = p_b }
  if (p_d && (first_pos == 0 || p_d < first_pos)) { first_kw = "defect"; first_pos = p_d }
  if (p_r && (first_pos == 0 || p_r < first_pos)) { first_kw = "refund"; first_pos = p_r }

  if (first_kw != "") {
    count[first_kw]++; total++
    print $1, $2, first_kw, first_pos, $8, $9, $10 >> outdir "/signals_keywords_rows.tmp"
  }
}
END {
  print "keyword","count","share"
  for (k in count) {
    share = (total > 0 ? 100.0 * count[k] / total : 0)
    printf "%s\t%d\t%.2f%%\n", k, count[k], share
  }
}
' "$INPUT" 2>>"$LOGDIR/step7.log" > "$OUTDIR/signals_keywords.tsv"

if [ -s "$OUTDIR/signals_keywords.tsv" ]; then
  { read -r hdr; printf "%s\n" "$hdr"; tail -n +2 "$OUTDIR/signals_keywords.tsv" | sort -k2,2nr -k1,1; } \
    > "$OUTDIR/signals_keywords.sorted.tsv"
  mv "$OUTDIR/signals_keywords.sorted.tsv" "$OUTDIR/signals_keywords.tsv"
fi

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

if [ -f "$OUTDIR/signals_keywords.tsv" ]; then
  lines=$(wc -l < "$OUTDIR/signals_keywords.tsv" || echo 0)
  echo "$(ts) Wrote $OUTDIR/signals_keywords.tsv ($lines lines)" | tee -a "$LOGDIR/step7.log"
fi
if [ -f "$OUTDIR/signals_keywords_rows.tsv" ]; then
  lines=$(wc -l < "$OUTDIR/signals_keywords_rows.tsv" || echo 0)
  echo "$(ts) Wrote $OUTDIR/signals_keywords_rows.tsv ($lines lines)" | tee -a "$LOGDIR/step7.log"
fi

echo "$(ts) Step 7 – done" | tee -a "$LOGDIR/step7.log"

###############################################################################
# Step 5 – Metrics: Ratios & Buckets
###############################################################################

echo "$(ts) Step 5 – Metrics (ratios & buckets): start" | tee -a "$LOGDIR/step5.log"

awk -F',' -v OFS='\t' '
NR==1 { next }
{
  helpful = ($3 + 0)
  total   = (($2 % 500) + 1)
  ratio = helpful / total
  bucket = "ZERO"
  if (ratio >= 0.75) bucket = "HI"
  else if (ratio >= 0.40) bucket = "MID"
  else if (ratio > 0) bucket = "LO"

  print $1, helpful, total, sprintf("%.3f", ratio), bucket >> "out/helpfulness_ratios.tmp"
  count[bucket]++; totalrows++
}
END {
  print "bucket","count","share"
  for (b in count) {
    share = (totalrows>0 ? 100*count[b]/totalrows : 0)
    printf "%s\t%d\t%.2f%%\n", b, count[b], share
  }
}
' "$INPUT" 2>>"$LOGDIR/step5.log" > "$OUTDIR/helpfulness_buckets.tsv"

awk -F'\t' -v OFS='\t' '
NR==1{print;next}
{ if($1=="HI")o=1;else if($1=="MID")o=2;else if($1=="LO")o=3;else o=4; print o"\t"$0 }
' "$OUTDIR/helpfulness_buckets.tsv" | sort -k1,1n | cut -f2- > "$OUTDIR/helpfulness_buckets.sorted.tsv" \
&& mv "$OUTDIR/helpfulness_buckets.sorted.tsv" "$OUTDIR/helpfulness_buckets.tsv"

{
  echo -e "game_id\thelpful\ttotal\tratio\tbucket"
  sort out/helpfulness_ratios.tmp
} > out/helpfulness_ratios.tsv
rm -f out/helpfulness_ratios.tmp

if [ -f "$OUTDIR/helpfulness_buckets.tsv" ]; then
  echo "$(ts) Wrote $OUTDIR/helpfulness_buckets.tsv ($(wc -l < "$OUTDIR/helpfulness_buckets.tsv") lines)" | tee -a "$LOGDIR/step5.log"
fi
if [ -f "$OUTDIR/helpfulness_ratios.tsv" ]; then
  echo "$(ts) Wrote $OUTDIR/helpfulness_ratios.tsv ($(wc -l < "$OUTDIR/helpfulness_ratios.tsv") lines)" | tee -a "$LOGDIR/step5.log"
fi

echo "$(ts) Step 5 – Metrics (ratios & buckets): done" | tee -a "$LOGDIR/step5.log"
