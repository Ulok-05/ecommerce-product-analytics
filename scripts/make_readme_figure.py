"""Create the overview figure for the README from the query results.

Reads CSVs from data/results/ (see export_results.py) and saves
docs/readme_overview.png with two panels:

    1. MAU on all data vs cleaned data (the June–August 2023 anomaly)
    2. Retention by day since the first event, up to Day 120

Usage (from the project root):

    python scripts/make_readme_figure.py
"""
from pathlib import Path

import matplotlib.dates as mdates
import matplotlib.pyplot as plt
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RESULTS = ROOT / "data" / "results"
OUTPUT = ROOT / "docs" / "readme_overview.png"

CLEAN_COLOR = "tab:blue"
ALL_COLOR = "silver"


def main():
    mau_all = pd.read_csv(RESULTS / "01_engagement" / "mau_by_month.csv", parse_dates=["month"])
    mau_clean = pd.read_csv(RESULTS / "01_engagement" / "mau_by_month_clean.csv", parse_dates=["month"])
    retention = pd.read_csv(RESULTS / "02_retention_cohorts" / "retention_long_horizon.csv")

    plt.rcParams.update({"font.size": 11, "axes.titlesize": 12, "axes.titleweight": "bold",
                         "axes.grid": True, "grid.alpha": 0.3})
    fig, axes = plt.subplots(1, 2, figsize=(13, 4.5))

    ax = axes[0]
    ax.plot(mau_all["month"], mau_all["mau"], color=ALL_COLOR, linewidth=1.5, label="All data")
    ax.plot(mau_clean["month"], mau_clean["mau"], color=CLEAN_COLOR, linewidth=2,
            label="Excluding anomalous sessions")
    ax.set_title("MAU: the June–August 2023 anomaly inflates MAU ~4×")
    ax.set_ylabel("Monthly active users")
    ax.xaxis.set_major_locator(mdates.MonthLocator(bymonth=[1, 7]))
    ax.xaxis.set_major_formatter(mdates.DateFormatter("%b %Y"))
    ax.tick_params(axis="x", rotation=45)
    ax.legend(loc="upper right")

    ax = axes[1]
    ax.plot(retention["day_n"], retention["exact_day_retention_pct"], marker="o", color=CLEAN_COLOR,
            label="Exact-Day Retention")
    ax.plot(retention["day_n"], retention["unbounded_retention_pct"], marker="s", color="tab:gray",
            label="Unbounded Retention (Day N or later)")
    ax.set_title("Retention: flat ~50% until Day 80, no activity after Day 91")
    ax.set_xlabel("Days since first event")
    ax.set_ylabel("% of eligible users")
    ax.set_ylim(0, 105)
    ax.legend(loc="lower left")

    fig.tight_layout()
    OUTPUT.parent.mkdir(exist_ok=True)
    fig.savefig(OUTPUT, dpi=120)
    print(f"saved {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
