*********************************************************************************
** Purpose: Harmonize variables to program-name level
** Author: Emily
** Date: November 9, 2026
*********************************************************************************


** Want the output to be a dataset on program-name year level - Multiple counties will join together under one CASA program and funding will be allocated that way. 

** Need to figure out the runglobals ado in GitHub to do the globals through that. 
global onedrive "C:\Users\emi\OneDrive - UC San Diego\Research\CASA" 

use "$onedrive/data/clean_data/pop_fund_ccwip.dta", clear

isid county year 


** A couple counties don't have a CASA program, but I want to keep them in as zeros, for now. 
replace program_name = county + " NA" if mi(program_name)



** Locals of vars 
local ccwip "entries in_care permanence_12m place_stability recur_malt reentry2 stability case_closures_adoption case_closures_age_emancipation case_closures_court_ordered_term case_closures_criminal_justice_i case_closures_exceeded_time_limi case_closures_family_stabilized case_closures_guardianship case_closures_missing case_closures_nmd_nrlg_eligible_ case_closures_other case_closures_refused_services case_closures_reunification case_closures_total entry_cohort_adopted entry_cohort_aged_out_emancipate entry_cohort_guardianship entry_cohort_other entry_cohort_reunified entry_cohort_still_in_care entry_cohort_total entry_rates_11_15 entry_rates_16_17 entry_rates_1_2 entry_rates_3_5 entry_rates_6_10 entry_rates_total entry_rates_under_1 exits_adopted exits_aged_out_emancipated exits_kin_gap exits_other exits_other_guardianship exits_reunified exits_total in_care_rates_11_15 in_care_rates_16_17 in_care_rates_1_2 in_care_rates_3_5 in_care_rates_6_10 in_care_rates_total in_care_rates_under_1 mlos_11_15_yrs mlos_16_17_yrs mlos_1_11_mo mlos_1_2_yrs mlos_3_5_yrs mlos_6_10_yrs mlos_lt_1_mo mlos_total population_11_15 population_16_17 population_18_20 population_1_2 population_3_5 population_6_10 population_total population_under_1 recurrence_assessment_only recurrence_inconclusive recurrence_no_recurrence recurrence_not_yet_determined recurrence_substantiated recurrence_total recurrence_unfounded reentry_no_reentry_within_12_mon reentry_reentered_in_less_than_1 reentry_total mlos_11_15_yrs_prog mlos_16_17_yrs_prog mlos_1_11_mo_prog mlos_1_2_yrs_prog mlos_3_5_yrs_prog mlos_6_10_yrs_prog mlos_lt_1_mo_prog mlos_total_prog"


foreach v in entries in_care permanence_12m place_stability recur_malt reentry2 stability {
	replace `v' = "" if `v' == "M"
	 destring `v', replace 
}


** The funding is to the program level, so that doesn't need to be aggregated. 
** Population needs to be aggregated to the program level (just a sum) 

** Pulling MLOS out of the collapse, because I am going to average over the medians, using the number of children in care as weights -- I'm pulling it outside the collapse because the collapse mean uses entry cohort count (not current in care rates). Could create an iteration weighted differently for a robusteness check, if time. 
bysort program year: egen double sum_incare = total(in_care)

foreach v in mlos_11_15_yrs mlos_16_17_yrs mlos_1_11_mo mlos_1_2_yrs mlos_3_5_yrs mlos_6_10_yrs mlos_lt_1_mo mlos_total {

gen double `v'_scale = `v' * in_care

bysort program year: egen double `v'_scale_t = total(`v'_scale)

gen double `v'_prog = `v'_scale_t / sum_incare
label var `v'_prog "Avg of county median LOS, weighted by children in care"

drop `v'_scale_t `v'_scale
}
drop sum_incare 

collapse (rawsum)  Pop entries in_care case_closures_adoption case_closures_age_emancipation case_closures_court_ordered_term case_closures_criminal_justice_i case_closures_exceeded_time_limi case_closures_family_stabilized case_closures_guardianship case_closures_missing case_closures_nmd_nrlg_eligible_ case_closures_other case_closures_refused_services case_closures_reunification case_closures_total entry_cohort_adopted entry_cohort_aged_out_emancipate entry_cohort_guardianship entry_cohort_other entry_cohort_reunified entry_cohort_still_in_care entry_cohort_total exits_adopted exits_aged_out_emancipated exits_kin_gap exits_other exits_other_guardianship exits_reunified exits_total population_11_15 population_16_17 population_18_20 population_1_2 population_3_5 population_6_10 population_total population_under_1 ///
(firstnm) jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b ca_casa_supplemental ca_casa_supp_row_label  mlos_*_prog  ///
(mean) *_rates_* recurrence_assessment_only recurrence_inconclusive recurrence_no_recurrence recurrence_not_yet_determined recurrence_substantiated recurrence_total recurrence_unfounded permanence_12m place_stability recur_malt reentry2 stability [aw = entry_cohort_total], by(program_name year)


isid program_name year 

save "$onedrive/data/clean_data/program_pop_fund_ccwip.dta", replace 