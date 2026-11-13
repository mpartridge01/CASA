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
	replace `v' = "" if `v' == "M"
	 destring `v', replace 
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
foreach v of varlist Pop entries in_care stability case_closures_* entry_cohort_* exits_* population_* recurrence_* reentry_no_reentry_within_12_mon reentry_reentered_in_less_than_1 reentry_total {
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

isid program_name year
* Expect 49 units in every year (44 programs + 5 counties with no program)
tab year

save "$onedrive/data/clean_data/program_pop_fund_ccwip.dta", replace 
