"""Re-create the query results in data/results/ from the SQL files.

Every query whose result is used by a notebook is marked in its SQL file
with a comment line directly above it:

    -- export: dau_by_day.csv

This script runs all marked queries against ecommerce.duckdb and saves
each result to data/results/<analysis>/<name>.csv, where <analysis> is the
folder of the SQL file (for example, sql/01_engagement/ ->
data/results/01_engagement/). Queries without a mark are skipped.

Usage (from the project root):

    python scripts/export_results.py
    python scripts/export_results.py --db path/to/other.duckdb

The database must contain the tables created by setup/00_create_tables.sql
and setup/01_create_events_clean.sql. Close other clients that hold the
database open (e.g. DBeaver) before running: DuckDB allows only one
process to use a database file while it is open for writing.
"""
import argparse
import re
import sys
from pathlib import Path

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RESULTS_DIR = ROOT / "data" / "results"
SQL_FILES = [
    ROOT / "sql" / "01_engagement" / "00_data_quality.sql",
    ROOT / "sql" / "01_engagement" / "01_engagement.sql",
    ROOT / "sql" / "02_retention_cohorts" / "01_exact_day.sql",
    ROOT / "sql" / "02_retention_cohorts" / "02_bracket.sql",
    ROOT / "sql" / "02_retention_cohorts" / "03_unbounded.sql",
    ROOT / "sql" / "02_retention_cohorts" / "04_long_horizon.sql",
    ROOT / "sql" / "03_purchase_retention" / "01_exact_day.sql",
    ROOT / "sql" / "03_purchase_retention" / "02_bracket.sql",
    ROOT / "sql" / "03_purchase_retention" / "03_unbounded.sql",
    ROOT / "sql" / "03_purchase_retention" / "04_long_horizon.sql",
    ROOT / "sql" / "04_funnel" / "01_funnel.sql",
    ROOT / "sql" / "04_funnel" / "02_conversion_window.sql",
    ROOT / "sql" / "04_funnel" / "03_sequence_check.sql",
    ROOT / "sql" / "04_funnel" / "04_segments.sql",
    ROOT / "sql" / "05_user_behavior" / "01_activity.sql",
    ROOT / "sql" / "05_user_behavior" / "02_session_check.sql",
    ROOT / "sql" / "05_user_behavior" / "03_behavioral_cohorts.sql",
    ROOT / "sql" / "06_cac_ltv" / "00_data_checks.sql",
    ROOT / "sql" / "06_cac_ltv" / "01_cac.sql",
    ROOT / "sql" / "06_cac_ltv" / "02_revenue.sql",
    ROOT / "sql" / "06_cac_ltv" / "03_ltv_cac.sql",
    ROOT / "sql" / "06_cac_ltv" / "04_ltv_12_months.sql",
]
EXPORT_TAG = re.compile(r"^\s*--\s*export:\s*(\S+\.csv)\s*$", re.MULTILINE)


def save_csv(df, path):
    """Save in the same format as a DBeaver export: quoted header, timestamps with milliseconds."""
    df = df.copy()
    for col in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[col]):
            df[col] = df[col].dt.strftime("%Y-%m-%d %H:%M:%S.000")
    with open(path, "w") as f:
        f.write(",".join(f'"{col}"' for col in df.columns) + "\n")
        df.to_csv(f, index=False, header=False)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--db", default=str(ROOT / "ecommerce.duckdb"), help="path to the DuckDB database")
    args = parser.parse_args()

    try:
        con = duckdb.connect(args.db, read_only=True)
    except duckdb.IOException as e:
        sys.exit(f"Could not open {args.db}: {e}\nClose other clients (e.g. DBeaver) and try again.")

    exported = 0
    for sql_file in SQL_FILES:
        out_dir = RESULTS_DIR / sql_file.parent.name
        out_dir.mkdir(parents=True, exist_ok=True)
        for statement in duckdb.extract_statements(sql_file.read_text()):
            tag = EXPORT_TAG.search(statement.query)
            if not tag:
                continue
            out_path = out_dir / tag.group(1)
            df = con.sql(statement.query).df()
            save_csv(df, out_path)
            print(f"{sql_file.relative_to(ROOT)} -> {out_path.relative_to(ROOT)} ({len(df)} rows)")
            exported += 1

    print(f"Done: {exported} files exported.")


if __name__ == "__main__":
    main()
