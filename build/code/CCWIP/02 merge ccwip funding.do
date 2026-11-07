********************************************************************************
** Purpose: Merge together CCWIP and funding data and harmonize to the program level
** Date: 10/13/2026
** Emily Marsh
********************************************************************************

********************************************************************************
*                              Run globals script                              *
********************************************************************************

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

********************************************************************************
** 						IMPORT FUNDING DATA                                   **
********************************************************************************

import delimited "$onedrive/data/raw_data/CASA/casa_funding_program_fy2015_2026.csv", varnames(1) clear

isid program_name fiscal_year

** Prepping funding to be merged into the CCWIP data
preserve
	ren fiscal_year year
	replace year = substr(year, 1, 4)
	
	keep year program_name jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b ca_casa_supplemental ca_casa_supp_row_label 
	
	tempfile funding_program
	save `funding_program'
restore

save "$onedrive/data/raw_data/CASA/casa_funding_fy2015_2026.csv", replace 

keep program_name county_* 
collapse (firstnm) county_* , by(program_name)

** somehow Sutter is getting overwritten in the collapse. 
replace county_2 = "Sutter" if county_2 == "Yuba"

isid program_name

reshape long county_, i(program_name) j(county_no)

ren county_ county
drop if mi(county)

duplicates drop county program_name, force

merge 1:m county using "$onedrive/data/raw_data/CCWIP/CCWIP_county.dta"
	assert _m != 1 
	** _m == 2 because some counties (Alpine, Colusa, Sierra, Trinity, Tuolumne) don't have CASA programs at all. 
	drop _m 
	
merge m:1 program_name year using `funding_program'
	drop _m 
	** Some _m == 1 because funding data isn't here for 2011-2014 or for the counties that don't have CASA programs (and thus don't have CASA funding)
	
	
** Funding data missing. 
drop if inlist(year, "2011", "2012", "2013", "2014")


********************************************************************************
** 				       Generate variables for analysis                        **
********************************************************************************

foreach fund in jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b {
	replace `fund' = 0 if mi(`fund') 
}

** Want supplement to be 0 in counties that dont have a casa program in 2022, 2023, 2024 but missing in all counties in other years. 
replace ca_casa_supplemental = 0 if mi(ca_casa_supplemental) & inlist(year, "2022", "2023", "2024")

****** Create funding per child in care ********
destring year, replace 

foreach var in in_care stability reentry2 entries permanence_12m recur_malt place_stability {
	replace `var' = "" if `var' == "M"
	destring `var', replace 
}


** All baseline funding (outside of supplement) 
egen baseline_sum = rowtotal(jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b) 

** Total funding (baseline + supplement)
egen total_fund = rowtotal(baseline_sum ca_casa_supplemental) 


** Create baseline funding/child, total funding/child, supplement/child (where child is a child in foster care)
** The in-care variable is a point in time variable (instead of calculated over the course of the year) but I set the point as July (which corresponds to the beginning of the CA fiscal year). One thing to look into is when the actual disbursement happened. 
gen baseline_pc = baseline_sum/in_care 
gen tot_fund_pc = total_fund/in_care
gen supp_pc = ca_casa_supplemental/in_care 


save "$onedrive/data/clean_data/funding_ccwip.dta", replace






