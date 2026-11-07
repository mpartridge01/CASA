*==============================================================================*
*                              Run globals script                              *
*==============================================================================*

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

*==============================================================================*
*                  990 panel: one row per county x year                        *
*==============================================================================*

use "$cleandata/CASA/990_forms/casa_990_panel.dta", clear

* Counties served are in one string ("Butte, Glenn, Shasta, Tehama"; Voices for
* Children uses "Riverside; San Diego"). Split into one row per county.
replace counties = subinstr(counties, ";", ",", .)
gen byte prog_n_counties = length(counties) - length(subinstr(counties, ",", "", .)) + 1
label variable prog_n_counties "No. of counties on this 990 (dollars are org-wide, shared)"

split counties, parse(",") gen(cty)
gen long row = _n
reshape long cty, i(row) j(cty_n)
drop if missing(cty)
gen county = strtrim(cty)
drop row cty cty_n counties

* Funding data's year = start of the state FY (year 2015 = JUL2015-JUN2016),
* the same as fy_start here
rename fy_start year

* Program names come from the funding data; drop the 990's version
drop programs fy_end

isid county year
tempfile f990
save `f990'

*==============================================================================*
*                     Merge onto the county funding data                       *
*==============================================================================*

use "$onedrive/data/clean_data/funding_ccwip.dta", clear
isid county year

* keep(master match): keeps every funding row; drops 990 FY 2014-15, which has
* no funding year. Use keep(master match using) to keep those too.
merge 1:1 county year using `f990', keep(master match)

gen byte has_990 = (_merge == 3)
label define yesno 0 "No" 1 "Yes", replace
label values has_990 yesno
label variable has_990 "990 data for this county-year"
drop _merge

* Check: each 990 maps to one program name (Voices for Children has two, one per county)
bysort ein (program_name): assert program_name[1] == program_name[_N] if !missing(ein) & ein != "953786047"

* County-years with no 990: no CASA program (Colusa, Alpine, Sierra, Trinity,
* Tuolumne), before a program's first 990 (Marin 2015-16, Amador and Calaveras
* 2015), or not filed yet (Del Norte and Mariposa 2024, most of 2025, all of 2026)
tab year has_990

*==============================================================================*
*          Optional: split multi-county dollars across counties                *
*==============================================================================*

* The 990 dollars are for the whole organization, repeated on each county it
* serves. To split them, e.g. by each county's child population:

/*
bysort ein year: egen prog_pop = total(population_total)
gen cnty_share = cond(prog_n_counties == 1, 1, population_total / prog_pop)
foreach v of varlist rev_* exp_* casa_spend {
    gen `v'_cnty = `v' * cnty_share
}
*/

*==============================================================================*
*                                   Save                                       *
*==============================================================================*

order program_name county county_no county_code year period ein org_name tier has_990 prog_n_counties
sort county year
compress
save "$onedrive/data/clean_data/funding_ccwip_990.dta", replace
