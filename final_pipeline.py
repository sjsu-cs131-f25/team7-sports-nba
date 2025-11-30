from pyspark.sql import SparkSession

spark = SparkSession.builder \
    .appName("Team7_Final_Pipeline") \
    .getOrCreate()

# -----------------------------
# Load data (root of bucket)
# -----------------------------
input_path = "gs://team7-nba-data/*.csv"
df = spark.read.option("header", "true").csv(input_path)

# -----------------------------
# Transformation
# -----------------------------
df_clean = df.dropna()

# -----------------------------
# Write to GCS
# -----------------------------
output_path = "gs://team7-nba-data/output/final_parquet/"
df_clean.write.mode("overwrite").parquet(output_path)

spark.stop()
