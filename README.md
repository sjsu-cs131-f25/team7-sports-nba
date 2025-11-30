# Team 7 — NBA Basketball Analytics

### CS 131 — Processing Big Data (Fall 2025)

### Final Project — Distributed Data Engineering & Analysis

---

## 📘 Project Overview

This project performs large-scale analytics on a historical **NBA dataset (1946–present)** ([Kaggle: NBA Basketball Dataset](https://www.kaggle.com/datasets/wyattowalsh/basketball)) using **PySpark**.
We designed and executed a distributed data pipeline to clean, transform, and analyze NBA team and player statistics.
Outputs include processed analytical tables, Spark UI screenshots, and the final written report.

---

## 👥 Team Members

| Name |
 | ----- |
| **Ragavan Arivazhagan** |
| **David Hsiao** |
| **Kyungtae Kim** |
| **Nishan Bhattarai** |
| **Kareem Sheikh** |

---

## 📊 Dataset Description

### Source

[NBA Historical Dataset](https://www.kaggle.com/datasets/wyattowalsh/basketball)
Contains detailed season-by-season NBA data such as:

* Player-level statistics

* Team performance metrics

* Box scores

* Game logs

* Play-by-play events

### Dataset Card (Sample File)

**Path:** `data/samples/sample_play_by_play.csv`
**Format:** CSV (comma-delimited, UTF-8)
**Rows:** \~1,000
**Columns:** 34
**Header:** Present

The full dataset is assumed to reside under `data/input/` and contains multiple larger CSV files.

---

## 📁 Repository Structure

The project directory structure is as follows:

```
.
├── data/
│   ├── instructions.md         # Instructions or metadata about the dataset
│   └── samples/
│        └── sample_play_by_play.csv # Small sample data file for local testing
│
├── final_pipeline.py           # Main PySpark script for distributed data processing
├── Final_project_new_analysis.ipynb # Primary analysis and visualization notebook
├── logs/
│   └── errors.log              # Log file capturing errors or job outputs
│
├── notebook/                   # Directory used for intermediate notebooks or scratchpad
├── out/                        # Contains all final, processed, and aggregated results
│   ├── Bar chart fouls_per_game_team.png # Visualization output
│   ├── Barchart_avgfouls_per_player_per_game.png
│   ├── clean/
│   │   └── clean_play_by_play.csv # The main cleaned dataset
│   ├── cluster_histogram.png
│   ├── cluster_outcomes.tsv    # (and many other analysis outputs/charts)
│   └── top30_overall.txt
│
├── Project_Assignment_5_.ipynb # Intermediate assignment/analysis notebook (Version 1)
├── Project_Assignment_5.ipynb  # Intermediate assignment/analysis notebook (Version 2)
├── project2_session.txt        # Session log/output for a specific run
├── README.md
├── run_pa4.sh                  # Shell script to run Assignment 4 pipeline
├── run_project2.sh             # Shell script to run Project 2 main pipeline
├── scripts/                    # Contains reusable shell scripts for job execution
│   ├── eng1_edges.sh
│   ├── run_pa3.sh
│   ├── sample_data.sh
│   └── skinny_table.sh
└── Sprint_6_Step3_Step4_Final_ipynb.ipynb # Final processing steps notebook
```

---

## 🚀 How to Run the Distributed Job

The primary data transformation logic is in `final_pipeline.py` and is typically executed via the shell scripts in the root directory.

### 1. Prerequisites

* Python 3.x

* PySpark

* Local Spark OR access to a distributed Spark cluster

### 2. Run Locally (Standalone Spark)

From the repository root, execute the main shell script, or run `final_pipeline.py` directly:

```bash
# Option A: Run via the shell script (recommended, as it handles parameters)
./run_project2.sh 

# Option B: Direct spark-submit using the main PySpark file
spark-submit final_pipeline.py \
--input data/input/ \
--output data/out/
```

This process loads raw data (assumed to be in `data/input/`) and writes results into `data/out/`.

### 3. Run on Any Spark Cluster

```bash
spark-submit \
--master <your-cluster-master> \
--deploy-mode client \
final_pipeline.py \
--input <input-path> \
--output <output-path>
```

Examples for `<input-path>` and `<output-path>`:

* `gs://your-bucket/input/` and `gs://your-bucket/out/`

* `hdfs:///user/team7/input/` and `hdfs:///user/team7/out/`

### 4. Optional: Dataproc Serverless Execution

```bash
gcloud dataproc batches submit spark \
--region=us-central1 \
--batch=team7-nba-run \
--execute final_pipeline.py \
-- \
gs://your-bucket/input/ \
gs://your-bucket/out/
```

## 📥 Input Data Location

Local input path (assumed):
`data/input/`

Cluster / Cloud input path:
`gs://your-bucket/input/`

Contents include:

* Player statistics

* Team statistics

* Game logs

* Play-by-play datasets

## 📤 Output Data Location

Local output path:
`data/out/`

Cluster / Cloud output path:
`gs://your-bucket/out/`

Outputs include:

* Cleaned datasets (in `data/out/clean/`)

* Aggregated analysis tables (e.g., `top30_overall.txt`, `entity_counts.tsv`)

* Visualization charts (e.g., all `.png` files)

## 📈 Spark UI Evidence

A distributed Spark run includes:

* **Jobs tab** — stage and task breakdown

* **SQL tab** — physical execution plan

* **Executors tab** — resource usage metrics

Screenshots of the Spark UI are typically included in the final report (assumed to exist outside of this file structure).

## 🤖 AI Tooling Disclosure

AI tools (e.g., ChatGPT) were used **selectively and minimally**, specifically for:

* Clarifying Spark error messages

* Understanding PySpark configuration flags

* Improving documentation clarity

All code and analytic logic were manually written, tested, and validated by the team.

## 📚 License

This project is for academic use as part of **CS 131 — Processing Big Data**.

