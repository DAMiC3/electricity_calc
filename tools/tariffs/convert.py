import json
import sys
from datetime import datetime

import pandas as pd


REQUIRED_COLS = [
    "regionKey",
    "displayName",
    "startDate",
    "endDate",
    "tierFrom",
    "tierTo",
    "rate",
]


def norm_date(v):
    if pd.isna(v) or str(v).strip() == "":
        return None
    if isinstance(v, (pd.Timestamp, datetime)):
        return v.strftime("%Y-%m-%d")
    return pd.to_datetime(str(v)).strftime("%Y-%m-%d")


def convert(xlsx_path: str, out_path: str):
    df = pd.read_excel(xlsx_path)

    # Validate required columns
    missing = [c for c in REQUIRED_COLS if c not in df.columns]
    if missing:
        raise SystemExit(f"Missing column(s): {', '.join(missing)}")

    # Normalize types
    df = df.copy()
    df["startDate"] = df["startDate"].apply(norm_date)
    df["endDate"] = df["endDate"].apply(norm_date)
    if df["startDate"].isna().any():
        raise SystemExit("Found blank startDate values.")

    df["tierFrom"] = df["tierFrom"].astype("int64")
    df["tierTo"] = df["tierTo"].apply(
        lambda v: None if pd.isna(v) or str(v).strip() == "" else int(v)
    )
    try:
        df["rate"] = df["rate"].astype("float64")
    except Exception:
        raise SystemExit("Column 'rate' must be numeric (e.g., 3.5525)")

    if (df["rate"] <= 0).any():
        raise SystemExit("All rates must be > 0")

    # Group rows by region-period, then collect blocks
    regions = []
    for (rk, sd, dn), g in df.groupby(["regionKey", "startDate", "displayName"], dropna=False):
        # Use the first non-null endDate in the group, if any
        ed = g["endDate"].dropna().iloc[0] if g["endDate"].notna().any() else None

        # Sort by tierFrom then tierTo
        g2 = g.sort_values(["tierFrom", "tierTo"], kind="stable")

        # Quick sanity: no overlapping or descending tiers (best-effort)
        last_to = 0
        for _, row in g2.iterrows():
            fr = int(row["tierFrom"]) if row["tierFrom"] is not None else 0
            to = None if pd.isna(row["tierTo"]) else int(row["tierTo"])
            if to is not None and to < fr:
                raise SystemExit(
                    f"Bad tier in {rk} {sd}: tierTo {to} < tierFrom {fr}"
                )
            if fr < last_to:
                raise SystemExit(
                    f"Overlapping tiers in {rk} {sd}: tierFrom {fr} < previous end {last_to}"
                )
            last_to = 10**12 if to is None else to

        blocks = [
            {
                "from": int(row["tierFrom"]),
                "to": (None if pd.isna(row["tierTo"]) else int(row["tierTo"])),
                "rate": float(row["rate"]),
            }
            for _, row in g2.iterrows()
        ]

        regions.append(
            {
                "regionKey": rk,
                "displayName": dn,
                "startDate": sd,
                "endDate": ed,
                "blocks": blocks,
            }
        )

    payload = {
        "versionYear": datetime.now().year,
        "regions": regions,
    }

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)

    print(f"OK: wrote {out_path} with {len(regions)} region-periods")


def main():
    if len(sys.argv) == 1:
        # Default paths when running from tools/tariffs/
        # Repo layout:
        #   flutter/ 
        #     electricity_calc/ (this repo)
        #       tools/tariffs/convert.py (cwd here)
        #       docs/ (output)
        #     electricity_calc_extra/ (sibling folder with Excel)
        src = r"..\..\..\electricity_calc_extra\Tarif_prices.xlsx"
        out = r"..\..\docs\tariffs.json"
    elif len(sys.argv) == 3:
        src, out = sys.argv[1], sys.argv[2]
    else:
        print("Usage: python convert.py <input.xlsx> <output.json>")
        print("Or run with no args to use default locations.")
        sys.exit(1)
    convert(src, out)


if __name__ == "__main__":
    main()
