*********************************************************************************
** Purpose: Harmonize variables to program-name level
** Author: Emily
** Date: November 9, 2026
*********************************************************************************

********************************************************************************
*                              Run globals script                              *
********************************************************************************

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

********************************************************************************

** Want the output to be a dataset on program-name year level - Multiple counties will join together under one CASA program and funding will be allocated that way. 

use "$onedrive/data/clean_data/pop_fund_ccwip.dta", clear

* destring year
capture destring year, replace

isid county year 


** A couple counties don't have a CASA program, but I want to keep them in as zeros, for now. 
replace program_name = county + " NA" if mi(program_name)



** Locals of vars 
local ccwip "entries in_care permanence_12m place_stability recur_malt reentry2 stability case_closures_adoption case_closures_age_emancipation case_closures_court_ordered_term case_closures_criminal_justice_i case_closures_exceeded_time_limi case_closures_family_stabilized case_closures_guardianship case_closures_missing case_closures_nmd_nrlg_eligible_ case_closures_other case_closures_refused_services case_closures_reunification case_closures_total entry_cohort_adopted entry_cohort_aged_out_emancipate entry_cohort_guardianship entry_cohort_other entry_cohort_reunified entry_cohort_still_in_care entry_cohort_total entry_rates_11_15 entry_rates_16_17 entry_rates_1_2 entry_rates_3_5 entry_rates_6_10 entry_rates_total entry_rates_under_1 exits_adopted exits_aged_out_emancipated exits_kin_gap exits_other exits_other_guardianship exits_reunified exits_total in_care_rates_11_15 in_care_rates_16_17 in_care_rates_1_2 in_care_rates_3_5 in_care_rates_6_10 in_care_rates_total in_care_rates_under_1 mlos_11_15_yrs mlos_16_17_yrs mlos_1_11_mo mlos_1_2_yrs mlos_3_5_yrs mlos_6_10_yrs mlos_lt_1_mo mlos_total population_11_15 population_16_17 population_18_20 population_1_2 population_3_5 population_6_10 population_total population_under_1 recurrence_assessment_only recurrence_inconclusive recurrence_no_recurrence recurrence_not_yet_determined recurrence_substantiated recurrence_total recurrence_unfounded reentry_no_reentry_within_12_mon reentry_reentered_in_less_than_1 reentry_total mlos_11_15_yrs_prog mlos_16_17_yrs_prog mlos_1_11_mo_prog mlos_1_2_yrs_prog mlos_3_5_yrs_prog mlos_6_10_yrs_prog mlos_lt_1_mo_prog mlos_total_prog"


foreach v in entries in_care permanence_12m place_stability recur_malt reentry2 stability {
	capture replace `v' = "" if `v' == "M"
	capture destring `v', replace 
}


** The funding is to the program level, so that doesn't need to be aggregated  
** Counts (entries, in care, exits, closures, population, recurrence and reentry counts) need to be aggregated to the program level (just a sum across counties). 
** Rates, percentages and medians can't be summed, so I average them over the counties in the program, weighting each one by its own denominator. 

** NOTE: Not using [aw = ] in the collapse anymore. Collapse drops any observation where the weight is 0 or missing, and that was deleting whole program-years (Alpine, Sierra, some years of small programs, and all of 2025-2026 because the entry cohort isn't calculated yet). Instead compute every weighted average by hand with egen (same idea as the MLOS block before), and then collapse with no weights. 


** Baseline and total funding. These are made in 02 but aren't in this file, so rebuild them here. 
** Same definitions as 02: baseline = all Judicial Council funding (everything but the supplement); total = baseline + supplement. 
capture drop baseline_sum total_fund
egen baseline_sum = rowtotal(jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b)
egen total_fund = rowtotal(baseline_sum ca_casa_supplemental)


** 2020 population of each county, carried to every year (the Judicial Council's small/large rule uses 2020 population). It's summed over the counties in the program below, so pop2020 = the program's 2020 population given the counties it has that year. 
bysort county: egen double pop2020 = max(cond(year == 2020, Pop, .))


** Quick check that the funding really is the same on every county row of a program 
foreach v in jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b ca_casa_supplemental ca_casa_supp_row_label baseline_sum total_fund {
	bysort program_name year (`v'): assert `v'[1] == `v'[_N]
}


** Rates: weighted average over the counties in the program. 
** Each rate gets its own weight: 
**    entry_rates_* and in_care_rates_* (per 1,000 kids) -> population of the same age group. This gives exactly total count / total population for the program. 
**    permanence_12m -> entries 
**    reentry2 -> reentry_total 
**    recur_malt -> recurrence_total 
**    place_stability -> in_care 
**    mlos_* (medians) -> in_care, same as before. This is an approximation since you can't combine medians exactly. 
** Only counties that report the rate count toward the weights (so a county with a suppressed value doesn't pull the average toward 0). 
** This has to happen before the counts are summed below, since the weights are the county-level counts. 

local rates ""
local wts   ""
foreach a in under_1 1_2 3_5 6_10 11_15 16_17 total {
	local rates `rates' entry_rates_`a' in_care_rates_`a'
	local wts   `wts'   population_`a'  population_`a'
}
local rates `rates' permanence_12m reentry2      recur_malt       place_stability
local wts   `wts'   entries        reentry_total recurrence_total in_care
foreach v of varlist mlos_* {
	local rates `rates' `v'
	local wts   `wts'   in_care
}

local nr : word count `rates'
forvalues j = 1/`nr' {
	local v : word `j' of `rates'
	local w : word `j' of `wts'
	
	gen double _num = `v' * `w'                  // rate x weight for each county 
	gen double _den = `w' if !missing(`v')       // weight, only for counties that report the rate 
	
	bysort program_name year: egen double _tnum = total(_num), missing
	bysort program_name year: egen double _tden = total(_den), missing
	
	replace `v' = cond(_tden > 0, _tnum / _tden, .)
	label var `v' "`v' (avg over counties, weighted by `w')"
	
	drop _num _den _tnum _tden
}


** Counts: sum over the counties in the program. The "missing" option keeps it missing (instead of 0) if every county is missing that year. 
foreach v of varlist Pop pop2020 entries in_care stability case_closures_* entry_cohort_* exits_* population_* recurrence_* reentry_no_reentry_within_12_mon reentry_reentered_in_less_than_1 reentry_total {
	bysort program_name year: egen double _t = total(`v'), missing
	replace `v' = _t
	drop _t
}


** Keep a list of which counties are in each program 
sort program_name year county
by program_name year: gen counties = county if _n == 1
by program_name year: replace counties = counties[_n-1] + ", " + county if _n > 1
by program_name year: replace counties = counties[_N]
by program_name year: gen n_counties = _N


** Now every county row of a program has the same values, so the collapse just keeps one row per program-year. No weights, so nothing gets dropped. 
** The per-child funding variables (if they're in the file) are dropped here and rebuilt at the program level below (the old ones divided program funding by one county's kids). 
drop county county_no county_code
capture drop baseline_pc tot_fund_pc supp_pc

ds program_name year, not
collapse (firstnm) `r(varlist)', by(program_name year)


* Per-child funding, recomputed at the program level
gen baseline_pc = baseline_sum / in_care
gen tot_fund_pc = total_fund / in_care
gen supp_pc     = ca_casa_supplemental / in_care

label var Pop     "Population of the program's counties that year (DOF E-4)"
label var pop2020 "2020 population of the program's counties (DOF E-4, Jan 1 2020)"


********************************************************************************
** 				 Judicial Council funding rule indicators                     **
********************************************************************************

** Program indicator 
gen byte has_program = !strmatch(program_name, "* NA")
label var has_program "Unit is a state-funded CASA program"

** Number of Judicial Council grant lines in the unit. Butte/Glenn and Shasta/Tehama are two Judicial Council grant lines (each a tier 2 two-county program) but one unit here, because the CA CASA supplemental funds the four counties as one program. Every other unit is one line. 
gen byte jc_n_lines = cond(program_name == "CASA of Butte, Glenn, Shasta, and Tehama Counties", 2, 1) if has_program
label var jc_n_lines "No. of Judicial Council grant lines in this unit"

** Multi-county program: counties funded together as one program that year (Judicial Council base x 1.5) 
gen byte jc_multi = has_program & n_counties >= 2
label var jc_multi "Multi-county program (Judicial Council base x 1.5)"

** Judicial Council population tier as set in 2013 (Aug 23, 2013 report, Attachment B): programs ranked by county population (combined for multi-county programs). Programs that later added a county kept their tier. 
gen byte jc_tier_2013 = .
replace jc_tier_2013 = 1 if inlist(program_name, "CASA of Del Norte", "CASA of Humboldt", "CASA of Lassen Family Services", "CASA of Mariposa County", "Modoc CASA", "Child Advocates of Nevada County")
replace jc_tier_2013 = 1 if inlist(program_name, "Plumas CASA", "CASA of San Benito County", "CASA of Siskiyou County", "CASA of Amador and Calaveras Counties", "CASA of the Eastern Sierra")
replace jc_tier_2013 = 2 if inlist(program_name, "Child Advocates of El Dorado County", "CASA of Imperial County", "CASA of Kings County", "Marin CASA", "CASA of Merced County", "Napa CASA")
replace jc_tier_2013 = 2 if inlist(program_name, "CASA of San Luis Obispo County", "CASA of Santa Cruz County", "Yolo County CASA", "CASA of Butte, Glenn, Shasta, and Tehama Counties", "CASA of Mendocino and Lake Counties")
replace jc_tier_2013 = 3 if inlist(program_name, "CASA of Monterey County", "Child Advocates of Placer County", "San Francisco CASA", "CASA of San Joaquin County", "CASA of San Mateo County", "CASA of Santa Barbara County")
replace jc_tier_2013 = 3 if inlist(program_name, "CASA of Solano County", "CASA of Sonoma County", "CASA of Stanislaus County", "CASA of Tulare County", "CASA of Ventura County")
replace jc_tier_2013 = 4 if inlist(program_name, "Alameda County CASA", "CASA of Contra Costa County", "CASA of Kern County", "CASA of Los Angeles", "CASA of Orange County", "Voices for Children Riverside")
replace jc_tier_2013 = 4 if inlist(program_name, "CASA Sacramento", "CASA of San Bernardino County", "Voices for Children San Diego", "Child Advocates of Silicon Valley", "CASA of Fresno and Madera Counties")
label var jc_tier_2013 "Judicial Council population tier as set in 2013 (1-4)"
assert !missing(jc_tier_2013) if has_program
assert  missing(jc_tier_2013) if !has_program

** Tier the program was actually funded at that year, read off its base: base per grant line = tier amount (26,000 / 34,000 / 42,000 / 50,000) x 1.15 from FY 2018-19 x 1.5 if multi-county. 
gen double _b13 = jc_base / jc_n_lines / cond(year >= 2018, 1.15, 1) / cond(jc_multi, 1.5, 1)
gen byte jc_tier = .
replace jc_tier = 1 if abs(_b13 - 26000) < 1
replace jc_tier = 2 if abs(_b13 - 34000) < 1
replace jc_tier = 3 if abs(_b13 - 42000) < 1
replace jc_tier = 4 if abs(_b13 - 50000) < 1
drop _b13
label var jc_tier "Judicial Council population tier the program was funded at that year (1-4)"
** Every program's base fits one tier exactly 
list program_name year jc_base jc_multi jc_n_lines if has_program & missing(jc_tier), noobs
assert !missing(jc_tier) if has_program

** The funded tier matches 2013 in every year except two (from the funding tables): San Luis Obispo in FY 2015-16 (funded at tier 3) and Napa in FY 2026-27 (funded at tier 1). 
list program_name year jc_tier_2013 jc_tier jc_base if has_program & jc_tier != jc_tier_2013, noobs
assert jc_tier == jc_tier_2013 if has_program & !(program_name == "CASA of San Luis Obispo County" & year == 2015) & !(program_name == "Napa CASA" & year == 2026)

** Tier dummies (tier funded at that year) 
forvalues t = 1/4 {
	gen byte jc_tier`t' = (jc_tier == `t') if has_program
	label var jc_tier`t' "Funded at Judicial Council tier `t'"
}

** Small/large program (rule written down in 2024: 2020 population under 300,000 = small; combined population for multi-county programs). 
** Butte/Glenn/Shasta/Tehama: the Judicial Council classifies each of its two grant lines on its own (about 240,000 and 250,000 people), so both are small, even though the four counties together are over 300,000. 
gen byte jc_small = (pop2020 < 300000) if has_program
replace jc_small = 1 if program_name == "CASA of Butte, Glenn, Shasta, and Tehama Counties"
label var jc_small "Small program (2020 population < 300,000, per Judicial Council grant line)"

** Check: small/large matches the Judicial Council's FY 2024-25 list of small programs 
gen byte _jc_small_list = inlist(program_name, "CASA of Amador and Calaveras Counties", "CASA of Butte, Glenn, Shasta, and Tehama Counties", "CASA of Del Norte", "Child Advocates of El Dorado County", "CASA of Humboldt", "CASA of Imperial County", "CASA of the Eastern Sierra", "CASA of Kings County") ///
	| inlist(program_name, "CASA of Lassen Family Services", "Marin CASA", "CASA of Mariposa County", "CASA of Mendocino and Lake Counties", "CASA of Merced County", "Modoc CASA", "Napa CASA", "Child Advocates of Nevada County") ///
	| inlist(program_name, "Plumas CASA", "CASA of San Benito County", "CASA of San Luis Obispo County", "CASA of Santa Cruz County", "CASA of Siskiyou County", "Yolo County CASA")
list program_name year pop2020 jc_small if has_program & inlist(year, 2024, 2025) & jc_small != _jc_small_list, noobs
assert jc_small == _jc_small_list if has_program & inlist(year, 2024, 2025)
drop _jc_small_list


isid program_name year
* Expect 44 programs every year, plus counties without a program: 52 units in 2015-2017 (Alpine, Calaveras, Colusa, Sierra, Sutter, Trinity, Tuolumne, Yuba), 51 in 2018-2022 (Calaveras joins Amador), 50 in 2023-2025 (Yuba joins Placer), 49 in 2026 (Sutter joins Placer)
tab year has_program

save "$onedrive/data/clean_data/program_pop_fund_ccwip.dta", replace 
