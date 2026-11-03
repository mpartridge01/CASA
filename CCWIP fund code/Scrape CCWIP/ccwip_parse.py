"""
Turn raw CCWIP JSON (saved by ccwip_fetch.py) into tidy CSVs, one set per report.

Usage:
    py ccwip_parse.py all                   # every folder under raw/
    py ccwip_parse.py reentry               # one report
    py ccwip_parse.py exits --min-year 2014

Writes, for each report:
    tidy/<report>_long.csv    one row per county x category x period, with flags and unit
    tidy/<report>_panel.csv   one row per county x period, one column per category
    tidy/<report>_meta.txt    the report's titles, unit and layout (check these!)

'year' is the calendar year in which the period STARTS, so JUL2014-JUN2015 is
2014. The 'period' column keeps the original label.
"""
import argparse
import json
import re
from pathlib import Path

import pandas as pd

PERIOD_RE = re.compile(r"([A-Za-z]{3})\s?(\d{4})\s*-\s*([A-Za-z]{3})\s?(\d{4})")
YEAR_RE = re.compile(r"(?<!\d)((?:19|20)\d{2})(?!\d)")


def slug(text):
    text = str(text).replace("<", "lt ").replace(">", "gt ")
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


def period_year(label):
    """Start year of a period label such as JUL2014-JUN2015; None if no year."""
    label = str(label)
    m = PERIOD_RE.search(label)
    if m:
        return int(m.group(2))
    m = YEAR_RE.search(label)
    return int(m.group(1)) if m else None


def to_number(text):
    try:
        return float(str(text).replace(",", ""))
    except ValueError:
        return None


def column_labels(table_headers, n):
    """One label per data column, plus the unit row (e.g. '%' or 'Days').

    Header cells are expanded by colSpan. The row-label (stub) cell in the first
    header row is skipped. Header rows where every label is identical carry no
    column information; the last such row is reported as the unit.
    """
    rows = []
    for k, header in enumerate(table_headers):
        labels = []
        for j, cell in enumerate(header["headerTitles"]):
            is_stub = k == 0 and j == 0 and (cell.get("rowSpan") or 1) > 1 and not cell.get("colSpan")
            if is_stub:
                continue
            labels.extend([cell["text"]] * (cell.get("colSpan") or 1))
        if len(labels) == n:
            rows.append(labels)
    if not rows:
        return [f"col{i}" for i in range(n)], ""
    unit = rows[-1][0] if len(set(rows[-1])) == 1 else ""
    informative = [r for r in rows if len(set(r)) > 1]
    chosen = informative or rows[:1]
    return [" | ".join(parts) for parts in zip(*chosen)], unit


def parse_file(path, report):
    doc = json.loads(Path(path).read_text(encoding="utf-8"))
    result = doc["resultData"]
    county = result.get("county")
    county_code = int(re.search(r"county_(\d+)", Path(path).name).group(1))
    rows = result["dataRows"]
    n = len(rows[0]["dataValues"]) if rows else 0
    cols, unit = column_labels(result["tableHeaders"], n)

    col_hits = sum(period_year(c) is not None for c in cols)
    row_hits = sum(period_year(r["colHeader"]) is not None for r in rows)
    if col_hits and col_hits >= row_hits:
        years_in = "columns"
    elif row_hits:
        years_in = "rows"
    else:
        years_in = "none"

    records = []
    for row in rows:
        display = row.get("dV2") or [None] * n
        for col, num, shown in zip(cols, row["dataValues"], display):
            shown = "" if shown is None else str(shown)
            value = num if num is not None else to_number(shown)
            flag = "" if value is not None and to_number(shown) is not None else shown
            if years_in == "columns":
                period, category = col, row["colHeader"]
            elif years_in == "rows":
                period, category = row["colHeader"], col
            else:
                period, category = None, f"{row['colHeader']} | {col}"
            records.append(
                {
                    "report": report,
                    "county_code": county_code,
                    "county": county,
                    "category": category,
                    "period": period,
                    "year": period_year(period) if period else None,
                    "value": value,
                    "flag": flag,  # '**' not yet calculable, '.' no children, 'M'/'*' masked
                    "unit": unit,
                }
            )
    titles = [" ".join(t.split()) for t in (result.get("title") or {}).get("titles", []) if t and t.strip()]
    meta = {"titles": titles, "unit": unit, "years_in": years_in, "n_columns": n}
    return records, meta


def build_panel(long_df, report, min_year):
    sub = long_df[long_df["year"].notna() & (long_df["year"] >= min_year)].copy()
    if sub.empty:
        return None
    sub["year"] = sub["year"].astype(int)
    sub["var"] = report.lower() + "_" + sub["category"].map(slug)
    keys = ["county_code", "county", "year", "period"]
    wide = sub.groupby(keys + ["var"], dropna=False)["value"].first().unstack("var").reset_index()
    wide.columns.name = None
    return wide


def process(report, min_year):
    files = sorted((Path("raw") / report).glob("county_*.json"))
    if not files:
        print(f"{report}: no files in raw/{report}/")
        return
    records, meta = [], None
    for f in files:
        recs, m = parse_file(f, report)
        records.extend(recs)
        meta = meta or m
    long_df = pd.DataFrame(records)

    out = Path("tidy")
    out.mkdir(exist_ok=True)
    long_df.to_csv(out / f"{report}_long.csv", index=False)
    panel = build_panel(long_df, report, min_year)
    if panel is not None:
        panel.to_csv(out / f"{report}_panel.csv", index=False)

    lines = [f"report: {report}", f"unit: {meta['unit']!r}", f"years found in: {meta['years_in']}"]
    lines += [f"title: {t}" for t in meta["titles"]]
    (out / f"{report}_meta.txt").write_text("\n".join(lines), encoding="utf-8")

    yrs = long_df["year"].dropna()
    span = f"{int(yrs.min())}-{int(yrs.max())}" if len(yrs) else "none found"
    print(
        f"{report}: {len(files)} counties, {len(long_df)} cells, years {span}, "
        f"unit {meta['unit']!r}, flagged {int((long_df['flag'] != '').sum())}"
        + ("" if panel is not None else "  (no panel: no period labels with years)")
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report", help="report name, or 'all'")
    ap.add_argument("--min-year", type=int, default=2014)
    args = ap.parse_args()

    if args.report == "all":
        reports = sorted(p.name for p in Path("raw").iterdir() if p.is_dir())
    else:
        reports = [args.report]
    for report in reports:
        process(report, args.min_year)


if __name__ == "__main__":
    main()
