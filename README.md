# team7-sports-nba
Project title: Team 7 NBA Basketball Analytics
Team Member:  Ragavan Arivazhagan – Product Manager 
              David Hsiao – Data Engineer 
              Kyungtae Kim – Data Engineer
              Nishan Bhattarai – Data Engineer 
              Kareem Sheikh – Data Storyteller 
Dataset discription: NBA dataset
Source: Kaggle 
Historical dataset of NBA with detailed box scores (games, players, team, points, assist, steals, rebounds and so on from 1946 to present.

## Data Card
**PATH:**`team7-sports-nba/data/samples/sample_play_by_play.csv`
**FORMAT:** CSV (comma delimited, utf-8)
**ROWS:** around 1,000 with header
**COLUMNS:** 34
**HEADER:** Present (first row is column names)

## Notes
- Only a 1,000 row sample is committed for testing
- Full dataset is excluded from Git (too large)
- Source: https://www.kaggle.com/datasets/wyattowalsh/basketball
- Some missing fields and placeholder IDs are present (ex: blank cells for player2/player3)
- `artifacts/` and `out/` directories are ignored to keep outputs and generated files out of version control  
ENG1 run: ./scripts/eng1_edges.sh data/samples/sample_play_by_play.tsv 14 21 2
Outputs: out/edges.tsv, out/entity_counts.tsv, out/edges_thresholded.tsv
