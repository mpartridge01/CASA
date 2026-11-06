"""
Fetch raw CCWIP report data for every California county.

Report definitions live in ccwip_reports.py. Raw JSON is saved to
raw/<report>/county_NN.json so parsing can be rerun without hitting the site.

Usage (Windows):
    py ccwip_fetch.py --probe                  # Alameda only, all reports
    py ccwip_fetch.py --probe --report reentry # one report
    py ccwip_fetch.py                          # all reports, all counties
    py ccwip_fetch.py --report exits           # one report, all counties

The county selector is formatted differently by different reports (the
captured requests use "1", "0000" and "0" for the state). The probe tries a
few formats for county 1 and keeps the one that returns Alameda, saving the
answer in county_formats.json.
"""
import argparse
import json
import time
from pathlib import Path

import requests

from ccwip_reports import REPORTS

URL = "https://ccwip.berkeley.edu/PublicAPI/api/SasConnect/"
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
)
# {i100} is county number x 100: Alameda "0100", Alpine "0200", ... "5800".
# Re-entry, recurrence and (presumably) entry cohort use this; the rest use "{i}".
COUNTY_FORMATS = ["{i}", "{i100:04d}", "{i:02d}", "{i:04d}"]


def county_value(fmt, i):
    return fmt.format(i=i, i100=i * 100)
FORMAT_FILE = Path("county_formats.json")


def build_payload(report, county_value):
    cfg = REPORTS[report]
    overrides = cfg.get("overrides", {})
    payload = []
    for item in cfg["selections"]:
        item = dict(item)
        if item["sp"] in overrides:
            item["sel"] = overrides[item["sp"]]
        if item["sp"] == "AVCNTY":
            item["sel"] = county_value
        payload.append(item)
    return payload


def post(session, report, county_value, retries=3):
    headers = {
        "accept": "application/json, text/plain, */*",
        "content-type": "application/json",
        "origin": "https://ccwip.berkeley.edu",
        "referer": REPORTS[report]["referer"],
        "user-agent": USER_AGENT,
    }
    body = build_payload(report, county_value)
    for attempt in range(1, retries + 1):
        try:
            r = session.post(URL, headers=headers, json=body, timeout=90)
            r.raise_for_status()
            return r.json()
        except (requests.RequestException, ValueError) as exc:
            print(f"    attempt {attempt} failed ({exc})")
            time.sleep(2 * attempt)
    return None


def county_name(data):
    try:
        return str(data["resultData"]["county"] or "").strip()
    except (KeyError, TypeError):
        return ""


def load_formats():
    if FORMAT_FILE.exists():
        return json.loads(FORMAT_FILE.read_text(encoding="utf-8"))
    return {}


def save_formats(formats):
    FORMAT_FILE.write_text(json.dumps(formats, indent=1), encoding="utf-8")


def find_format(session, report, formats):
    """Return (format, response) whose county-1 request comes back as Alameda."""
    if report in formats:
        fmt = formats[report]
        data = post(session, report, county_value(fmt, 1))
        return (fmt, data) if data else (None, None)
    for fmt in COUNTY_FORMATS:
        value = county_value(fmt, 1)
        data = post(session, report, value, retries=1)
        name = county_name(data) if data else ""
        print(f"    tried county code {value!r}: got {name or 'nothing'!r}")
        if name.lower().startswith("alameda"):
            formats[report] = fmt
            save_formats(formats)
            return fmt, data
        time.sleep(0.5)
    return None, None


def summarize(data):
    """Print what a response contains so we can check units and periods."""
    result = data.get("resultData") or {}
    titles = [" ".join(t.split()) for t in (result.get("title") or {}).get("titles", []) if t and t.strip()]
    for t in titles:
        print(f"    title: {t[:110]}")
    heads = result.get("tableHeaders") or []
    if heads:
        print(f"    first header cell: {heads[0]['headerTitles'][0]['text']!r}")
        last = [c["text"] for c in heads[-1]["headerTitles"]]
        print(f"    last header row: {sorted(set(last))[:6]}")
        mid = [c["text"] for c in heads[1]["headerTitles"]] if len(heads) > 1 else []
        if mid:
            print(f"    columns: {len(mid)} ({mid[0]} ... {mid[-1]})")
    rows = result.get("dataRows") or []
    print(f"    data rows: {len(rows)}: {[r['colHeader'] for r in rows][:8]}")
    print(f"    successCode: {result.get('successCode')}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", action="store_true", help="county 1 only; print a summary")
    ap.add_argument("--report", action="append", choices=list(REPORTS), help="repeatable; default all")
    ap.add_argument("--first", type=int, default=1)
    ap.add_argument("--last", type=int, default=58)
    ap.add_argument("--delay", type=float, default=1.0, help="seconds between requests")
    args = ap.parse_args()

    session = requests.Session()
    formats = load_formats()

    for report in args.report or list(REPORTS):
        print(f"\n== {report} ==")
        out_dir = Path("raw") / report
        out_dir.mkdir(parents=True, exist_ok=True)

        fmt, first = find_format(session, report, formats)
        if fmt is None:
            print("  could not get an Alameda response; skipping (see attempts above)")
            continue
        (out_dir / "county_01.json").write_text(json.dumps(first, indent=1), encoding="utf-8")
        print(f"  county code format {fmt!r} works")
        if args.probe:
            summarize(first)
            continue

        for i in range(max(args.first, 2), args.last + 1):
            path = out_dir / f"county_{i:02d}.json"
            if path.exists():
                continue  # resume after a failure
            data = post(session, report, county_value(fmt, i))
            name = county_name(data) if data else ""
            if not data or not name or name == "California":
                print(f"  county {i}: no usable response (got {name or 'nothing'!r}), skipping")
                continue
            path.write_text(json.dumps(data, indent=1), encoding="utf-8")
            print(f"  county {i}: {name}")
            time.sleep(args.delay)


if __name__ == "__main__":
    main()
