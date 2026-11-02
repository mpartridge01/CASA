# CASA Form 990 scripts

**Folder:** `build/code/`
**Author:** Michael Partridge (UC San Diego), with help from Claude (Anthropic's AI assistant), October–November 2026
**Language:** R (tested with R 4.3+)

These scripts build a panel of revenue, expenses, staffing and balance-sheet data for California's 44 local CASA programs from their IRS Form 990 and 990-EZ tax returns, covering state fiscal years 2014–15 onward. The data folders have their own READMEs:

- `raw_data/CASA/990_forms/README.md`: where every return came from, including manual steps
- `clean_data/CASA/990_forms/README.md`: what is in the finished dataset and how to use it

---

## 1. Quick start

1. Open `CASA.Rproj`. The scripts use `here::here()` to find the repo root, so R must be started inside the repo.
2. Make sure your paths are in `SetGlobals.R` (Section 3).
3. Run in order:

| Order | Script | Takes | Needs internet | When to run |
|---|---|---|---|---|
| 1 | `casa_990_01_download.R` | ~5–15 min first time, ~2 min after | Yes | First time, and whenever newer returns may be available |
| 2 | `casa_990_02_parse.R` | ~1 min | No | After step 1, or after editing `casa_990_pdf_entry.csv` |
| 3 | `casa_990_03_check.R` | Seconds | No | After every run of step 2 |

Each script starts with:

```r
# Clear environment
rm(list = ls())

# Find and run build/code/SetGlobals.R (here() locates the CASA repo root)
source(here::here("build", "code", "SetGlobals.R"))
```

---

## 2. What flows where

```
ProPublica org pages ──► 01_download ──► raw_data/CASA/990_forms/
GivingTuesday XML archive ─┘               ├── casa_990_programs.csv
                                           ├── casa_990_filings_index.csv
                                           └── FY_<yyyy>_<yyyy>/<EIN>_<YYYYMM>_<form>_<objectid>.xml

Hand-saved recent XMLs ─────────────────► raw_data/CASA/990_forms/FY_*/        (by hand; see raw README)
Hand-downloaded PDFs ───────────────────► raw_data/CASA/990_forms/FY_*/*.pdf  (by hand)
PDF transcription ──────────────────────► raw_data/CASA/990_forms/casa_990_pdf_entry.csv

raw_data/CASA/990_forms/ ──► 02_parse ──► clean_data/CASA/990_forms/
                                           ├── casa_990_panel.csv
                                           ├── casa_990_codebook.csv
                                           ├── casa_990_other_expenses.csv
                                           └── casa_990_program_services.csv
                             02_parse ──► raw_data/CASA/990_forms/casa_990_pdf_entry_template.csv

clean_data + raw index ───► 03_check ───► clean_data/CASA/990_forms/
                                           ├── casa_990_coverage.csv
                                           └── casa_990_check_report.csv
```

---

## 3. `SetGlobals.R`

The R version of `SetGlobals.do`. It sets folder paths by computer and user, and loads every package the 990 scripts use.

- Detects the operating system and user with `Sys.info()`.
- Sets `github` (code) and `onedrive` (data) for each known user:
  - Michael (Mac, `mpart`): `/Users/mpart/Documents/GitHub/CASA` and `.../OneDrive-UCSanDiego/Marsh, Emily's files - CASA`
  - Emily (Windows, `emi`): `C:/Users/emi/Documents/GitHub/CASA` and `C:/Users/emi/OneDrive - UC San Diego/Research/CASA/data`
  - Any other user gets an error asking them to add their paths (a commented template is in the file).
- Defines `buildcode`, `analysiscode`, `rawdata` (`<onedrive>/data/raw_data`), `cleandata` (`<onedrive>/data/clean_data`) and `analysisoutput`.
- Loads `tidyverse`, `httr2` and `xml2`.

> Check Emily's path: her `onedrive` already ends in `/data`, so `rawdata` would become `.../data/data/raw_data`. Either drop `/data` from her `onedrive` or adjust the definitions.

**Packages:** `here`, `tidyverse` (dplyr, readr, purrr, stringr, tidyr), `httr2`, `xml2`. If `httr2` complains that `rlang` is too old, restart R, run `install.packages(c("rlang", "httr2"))`, and restart again.

---

## 4. `casa_990_01_download.R`

**Purpose:** find every Form 990 / 990-EZ filed by each CASA nonprofit and download the e-filed (XML) versions.

**Settings at the top:**

| Setting | Default | Meaning |
|---|---|---|
| `min_fy_start` | `2014` | First California state FY to keep (2014 = FY 2014–15). Earlier filings are skipped. |
| `try_pdfs` | `FALSE` | Try to download PDFs. Leave off: ProPublica's security check blocks scripted PDF downloads. |
| `download_all_pdfs` | `FALSE` | Only used if `try_pdfs` is on: also get PDFs for returns that have an XML. |

**What it does:**

1. **Program list.** A table (`programs`) of the 44 CASA programs: counties, program name, filing nonprofit, EIN and tier. It is written to `casa_990_programs.csv`. To add or fix a program, edit this table.
2. **List filings.** For each of the 43 unique EINs, reads `https://projects.propublica.org/nonprofits/organizations/<EIN>` and collects every link to an XML (`download-xml?object_id=...`) and every PDF viewer link (`display_990/...`). It pauses 1.5 seconds between requests and identifies itself as an academic research project.
3. **Download XMLs.** ProPublica's own XML links return a "Security Check" page to scripts, so each return is fetched by object ID from public mirrors of the IRS e-file data:
   - first `https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/<objectid>_public.xml` (GivingTuesday 990 Data Lake),
   - then `https://s3.amazonaws.com/irs-form-990/<objectid>_public.xml` (older IRS bucket).

   The script reads the tax period end date (`TaxPeriodEndDt`) and form type (`ReturnTypeCd`) from each file's header. It skips returns before `min_fy_start` and saves the rest to `FY_<start>_<end>/<EIN>_<YYYYMM>_<form>_<objectid>.xml`.
4. **Files already on disk are reused.** Any `.xml` anywhere under `990_forms/` whose name contains the object ID counts as downloaded. That is how hand-saved files are picked up; one saved elsewhere, e.g. in `manual_xml/`, is copied into the right FY folder.
5. **PDFs are not downloaded** (see the setting above). Each PDF's ProPublica link is kept in the index so it can be opened in a browser.
6. **Filing index.** Writes `casa_990_filings_index.csv`, one row per 990 / 990-EZ return from FY 2014–15 on: program, EIN, tier, FY, tax period, form, `has_xml`, object ID, XML file path, and the XML and PDF links. It also prints a program × FY table (`X` = XML, `P` = PDF only).

**Writes:** `raw_data/CASA/990_forms/casa_990_programs.csv`, `casa_990_filings_index.csv`, and the `FY_*/` XML files.

**Folder creation:** this script creates `990_forms/` and the `FY_*` folders itself, because which FY folders are needed depends on what is found. `raw_data/CASA/` must already exist. This is the only script that creates folders.

**Known limits:**

- The GivingTuesday archive lags the IRS by several months. Returns processed recently (e.g. in 2026) may be listed on ProPublica but not downloadable yet. The index shows them with `has_xml = FALSE` and an XML link. Save them by hand from ProPublica and rerun (see the raw-data README, Step 3).
- Paper-filed returns only have PDFs and must be transcribed (raw-data README, Steps 4–5).

**Testing on a few EINs:** right after `eins <- unique(programs$ein)`, add for example `eins <- c("330069334", "203594007")`. Remove it afterwards.

---

## 5. `casa_990_02_parse.R`

**Purpose:** turn the raw returns into a clean EIN × year panel.

**What it does:**

1. **Reads every `.xml`** under `raw_data/CASA/990_forms/` (except a `manual_xml/` folder, whose files script 01 has already copied into FY folders). Returns other than 990 and 990-EZ (e.g. 990-T) are skipped.
2. **Form 990** (`parse_990()`). XML tags are matched by name with namespaces stripped. It pulls:
   - Part I: employees, volunteers, current and prior-year total revenue and expenses, investment income.
   - Part VIII: revenue lines 1a–1h, 2g, 3, 8a–8c, other revenue and total revenue.
   - Part IX: all 30 expense lines × 4 columns (total, program, management, fundraising), the itemized 24a–d lines and the line 25 totals.
   - Part III: each program line (4a–4d) with its description, expenses, grants and revenue, plus the program total.
   - Part X: beginning and end-of-year total assets, liabilities and net assets.
3. **Form 990-EZ** (`parse_990ez()`): EZ lines 1–9 (revenue), 10–17 (expenses), Part II balance sheet, and Part III program lines.
4. **Blank lines:** a line left off a full 990's XML is set to 0. A missing count (employees, volunteers) or missing total stays `NA`. `parse_fail = 1` if neither total revenue nor total expenses could be read (an older XML schema). None did.
5. **Amended returns:** when there are several filings for one EIN × tax period, keeps the one with the highest object ID (the latest). `n_versions` and `amended` record this.
6. **CASA program line:** finds the Part III line whose description matches `CASA`, `court appointed` or `special advocate` (case-insensitive) → `casa_line`, `casa_exp`, `casa_line_is_other` (1 if it is line 4d "Other").
7. **PDF returns:**
   - Writes `raw_data/CASA/990_forms/casa_990_pdf_entry_template.csv`, one blank row (with every column) for each return in the filing index that still has no data. When everything is entered, it is header-only.
   - Reads `raw_data/CASA/990_forms/casa_990_pdf_entry.csv` (never writes to it), converts the amounts to numbers (commas and `$` are allowed), and adds the rows with `source = "pdf_manual"`. If an XML now exists for the same EIN × tax period, the PDF row is dropped with a message.
   - `pdf_vars` in the script lists every variable that can be entered by hand.
8. **Derived variables:** `fy`, `fy_start`, `fy_end` (state FY in which the tax year ends); `exp_personnel_tot` (Part IX lines 5–10, or EZ line 12); and quick checks `chk_contrib_diff`, `chk_exp_diff`, `chk_flag`. These are computed the same way for XML and PDF rows.
9. **Program information:** joins program names, counties and tier from `casa_990_programs.csv`.

**Writes** to `clean_data/CASA/990_forms/`: `casa_990_panel.csv`, `casa_990_codebook.csv`, `casa_990_other_expenses.csv` and `casa_990_program_services.csv`. Also writes `raw_data/CASA/990_forms/casa_990_pdf_entry_template.csv`. Output is CSV only, with `NA` written as blank.

**Prints:** how many returns still have no data, how many hand-entered rows were added, and a count by source, tier, form, `parse_fail` and `chk_flag`.

---

## 6. `casa_990_03_check.R`

**Purpose:** confirm the panel is complete and internally consistent. It reads the panel and changes no data.

**Coverage:** builds a program × state FY grid and labels each cell:

| Status | Meaning |
|---|---|
| `xml` / `pdf_manual` | Data in the panel |
| `MISSING` | ProPublica lists a return but it is not in the panel (**fix**) |
| `gap` | No return listed, but there are returns before and after (**look into it**) |
| `before_first` | Before the organization's first listed return |
| `not_yet` | After its latest listed return (not filed or published yet) |

**Checks** (`diff` = left side − right side; flagged when |diff| > $1):

| Check | Severity | Test |
|---|---|---|
| `contrib_sum` | error | VIII 1a–1f = 1h |
| `rev_sum` | error | Part I lines 8–11 = total revenue (990); EZ lines 1–8 = line 9 |
| `rev_p1_vs_viii` | error | Part I line 12 = Part VIII line 12 |
| `events_net` | error | VIII 8a − 8b = 8c |
| `exp_sum` | error | IX lines 1–24 = line 25 (990); EZ lines 10–16 = 17 |
| `exp_cols` | error | IX 25: program + management + fundraising = total |
| `exp_p1_vs_ix` | error | Part I line 18 = IX line 25 |
| `prog_vs_ix` | error | Part III total = IX 25 column B |
| `bal_boy`, `bal_eoy` | error | Assets − liabilities = net assets |
| `missing_core` | error | Total revenue, total expenses or ending net assets blank |
| `parse_fail` | error | XML could not be read |
| `missing_return` | error | Listed on ProPublica but not in the panel |
| `py_rev`, `py_exp` | warn | This return's prior-year column = last year's return |
| `boy_assets`, `boy_net_assets` | warn | Beginning-of-year = last year's end-of-year |
| `yoy_jump` | warn | Revenue or expenses changed > 50% |
| `short_year` | warn | Tax period not 12 months after the previous one (a missing year or a changed year-end) |
| `dup_fy` | warn | Two returns in one state FY |
| `pdf_not_found` | warn | A PDF row's PDF is not saved in its FY folder |

The cross-year checks only compare returns exactly 12 months apart. They also test hand-entered PDF rows against the XML year after them.

**Writes** to `clean_data/CASA/990_forms/`: `casa_990_coverage.csv` and `casa_990_check_report.csv`.

**Prints:** coverage counts, rows by source and form, a count of each check, and the first 50 errors.

**What a good run looks like:** 0 errors, no `MISSING` or `gap` cells. Warnings are expected; they come from organizations restating figures and from real swings in funding (see the clean-data README, Section 5). Latest run (2 Nov 2026): 469 returns, 0 errors, 79 warnings.

---

## 7. Troubleshooting

| Problem | Fix |
|---|---|
| `User ... not recognized` | Add your computer and paths to `SetGlobals.R` |
| `here()` points at the wrong folder | Open `CASA.Rproj` first, or `setwd()` into the repo |
| `namespace 'rlang' ... is already loaded, but >= 1.3.0 is required` | Restart R; `install.packages(c("rlang", "httr2"))`; restart again |
| HTTP 403 "Security Check" | ProPublica blocks scripted XML/PDF downloads. Script 01 avoids those links; open them in a browser instead |
| Return listed but `has_xml = FALSE` | Not yet in the GivingTuesday archive (or paper-filed). Save the XML by hand, or transcribe the PDF |
| `missing_return` errors in script 03 | Rerun 01 then 02. If it persists, the return needs a hand-saved XML or PDF entry |
| `Can't combine ... <logical> and <character>` in script 03 | Fixed 2 Nov 2026 (`bind_fixed()`); update to the current script |
