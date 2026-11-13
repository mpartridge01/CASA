*==============================================================================*
*                     06_merge_990_program_level.do                            *
*==============================================================================*

* Notes:
* 1. Merges the CASA 990 panel onto the funding-unit x year file from
*    05_aggregate_programlevel.do. A funding unit is one state CASA allocation
*    (program_name): a multi-county program funded as one is one unit.
*      In:  $onedrive/data/clean_data/program_pop_fund_ccwip.dta
*           $onedrive/data/clean_data/funding_ccwip.dta (county -> program crosswalk)
*           $cleandata/CASA/990_forms/casa_990_panel.dta
*      Out: $onedrive/data/clean_data/program_pop_fund_ccwip_990.dta
* 2. Each 990 maps to exactly one funding unit, except Voices for Children
*    (EIN 953786047), which files one 990 for two separately funded units
*    (Riverside, San Diego). Its dollars, staff and volunteers are split by
*    each county's share of children served (see section 2b).
* 3. year = start of the state FY (2015 = Jul 2015-Jun 2016) = 990 fy_start.


*==============================================================================*
*                              Run globals script                              *
*==============================================================================*

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals


*==============================================================================*
*               1. County -> funding unit (program_name) crosswalk             *
*==============================================================================*

use county program_name using "$onedrive/data/clean_data/funding_ccwip.dta", clear
drop if program_name == ""
duplicates drop
isid county
tempfile xwalk
save `xwalk'

*==============================================================================*
*                2. 990 panel: EIN x year -> funding unit x year               *
*==============================================================================*

use "$cleandata/CASA/990_forms/casa_990_panel.dta", clear

* One row per county the 990 covers
replace counties = subinstr(counties, ";", ",", .)
split counties, parse(",") gen(cty)
gen long row = _n
reshape long cty, i(row) j(cty_n)
drop if missing(cty)
gen county = strtrim(cty)
drop row cty cty_n

* Attach the funding unit for each county
merge m:1 county using `xwalk'
assert _merge != 1        // every 990 county belongs to a funding unit
drop if _merge == 2       // counties with no CASA program
drop _merge

rename fy_start year
drop programs counties fy_end county

* Counties of the same unit are now identical rows: keep one per unit-year.
* Voices for Children keeps two rows (Riverside and San Diego).
duplicates drop
isid program_name year

* Units per 990 in each year (2 only for Voices for Children)
bysort ein year: gen byte n_units_990 = _N
assert n_units_990 == 1 | ein == "953786047"

*------------------------------------------------------------------------------*
* 2b. Split Voices for Children by share of children served
*------------------------------------------------------------------------------*

* Let's weight Riverside and San Diego 990 information by weighted proportion of children who receive a CASA. Riverside started in 2015, so it makes sense that there is a slow build up.

* Riverside's share of children served (CASA volunteer or staff advocate), by
* state FY. San Diego excludes its Juvenile Justice program.
*   2022-2024: VFC county impact reports
*              Riverside 521, 586, 730; San Diego 1,774, 1,729, 1,632
*   2020-2021: VFC combined impact reports
*              Riverside 467, 486; San Diego 1,985 (2020); 2,390 combined (2021)
*   2014-2019: VFC 990 Part III text
*              Riverside 250 (2014-17), 412 (2018), 434 (2019); San Diego 3,000, 2,625
*   2025:      carried forward from 2024 (no report yet)
* Check: volunteer shares from the county reports (2022-2024: 25.9%, 28.3%,
* 32.0%) are within ~3 points of these.
gen double riv_share = .
replace riv_share = 250 / (3000 + 250)  if inrange(year, 2014, 2017)
replace riv_share = 412 / (2625 + 412)  if year == 2018
replace riv_share = 434 / (2625 + 434)  if year == 2019
replace riv_share = 467 / (1985 + 467)  if year == 2020
replace riv_share = 486 / 2390          if year == 2021
replace riv_share = 521 / (1774 + 521)  if year == 2022
replace riv_share = 586 / (1729 + 586)  if year == 2023
replace riv_share = 730 / (1632 + 730)  if year >= 2024

gen double share_990 = 1
replace share_990 = riv_share     if ein == "953786047" & program_name == "Voices for Children Riverside"
replace share_990 = 1 - riv_share if ein == "953786047" & program_name == "Voices for Children San Diego"
drop riv_share

* Every Voices for Children row got a share, and shares within each 990 add to 1
assert share_990 < 1 if ein == "953786047"
bysort ein year: egen double _s = total(share_990)
assert abs(_s - 1) < 1e-9
drop _s

* Keep the organization's own totals for reference
gen double org_rev_total = rev_total
gen double org_exp_total = exp_total
gen double org_emp_count = emp_count
gen double org_vol_count = vol_count

* Split dollars, staff and volunteers (no change for share_990 = 1)
foreach v of varlist rev_total rev_gov rev_fundraising rev_prog_svc rev_invest rev_oth ///
                     exp_total exp_salaries exp_grants exp_oth exp_prog exp_mgmt exp_fund ///
                     casa_spend emp_count vol_count {
    replace `v' = `v' * share_990
}

gen byte split_990 = (share_990 < 1)

label variable share_990     "Share of the 990 assigned to this unit (VFC: children served)"
label variable split_990     "990 split across funding units (Voices for Children)"
label variable n_units_990   "No. of funding units this 990 covers"
label variable org_rev_total "Total revenue, whole organization (before split)"
label variable org_exp_total "Total expenses, whole organization (before split)"
label variable org_emp_count "Employees, whole organization (before split)"
label variable org_vol_count "Volunteers, whole organization (before split)"

tempfile f990
save `f990'

*==============================================================================*
*              3. Merge onto the funding-unit x year CCWIP + funding file      *
*==============================================================================*

use "$onedrive/data/clean_data/program_pop_fund_ccwip.dta", clear
capture destring year, replace
isid program_name year

merge 1:1 program_name year using `f990'

* 990 rows that found no match (other than FY 2014-15)
tab program_name year if _merge == 2 & year != 2014

* Program-file rows with no 990
tab program_name year if _merge == 1

* 990 rows with no match should only be FY 2014-15 (before the funding data).
* If this fails, a program name differs between the two files.
assert year == 2014 if _merge == 2
drop if _merge == 2

gen byte has_990 = (_merge == 3)
label define yesno 0 "No" 1 "Yes", replace
label values has_990 yesno
label variable has_990 "990 data for this funding unit-year"
drop _merge

* Expect 990 data for: 42 units in 2015, 43 in 2016, 44 in 2017-2023,
* 42 in 2024, 3 in 2025, 0 in 2026. Counties with no CASA program never match.
tab year has_990

* Check the split: Voices for Children's two rows add back to the 990 total
list program_name year share_990 exp_total org_exp_total if split_990 == 1, sepby(year) noobs

*==============================================================================*
*                                   Save                                       *
*==============================================================================*

format rev_* exp_* casa_spend org_rev_total org_exp_total %15.0fc
order program_name year ein org_name tier has_990 split_990 share_990
sort program_name year
compress
save "$onedrive/data/clean_data/program_pop_fund_ccwip_990.dta", replace
