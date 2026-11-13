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


** save "$onedrive/data/raw_data/CASA/casa_funding_fy2015_2026.csv", replace 

** County -> program crosswalk BY YEAR. The funding file lists each program's counties in each fiscal year (county_1-county_4), and counties join a program in the year the state starts funding them together: 
**   Calaveras joins Amador in FY 2018-19; Yuba joins Placer in FY 2023-24; Sutter joins Placer in FY 2026-27. 
** In years a county isn't in a program it is a county without a program (blank program_name), like Alpine. 
** (This replaces the old collapse of county_* by program_name, which put every county a program ever had into every year -- e.g. Sutter and Yuba under Placer in all years.) 
gen year = substr(fiscal_year, 1, 4)
keep program_name year county_* 

reshape long county_, i(program_name year) j(county_no)

ren county_ county
drop if mi(county)

** A county is in at most one program in a given year 
isid county year

merge 1:1 county year using "$onedrive/data/raw_data/CCWIP/CCWIP_county.dta"
	** _m == 1: program-years with no CCWIP data for that year. 
	** _m == 2: counties without a program that year (Alpine, Colusa, Sierra, Trinity, Tuolumne every year; Calaveras before 2018, Yuba before 2023, Sutter before 2026), plus CCWIP years before the funding data. 
	drop _m 
	
merge m:1 program_name year using `funding_program'
	** Every funded program-year should match; _m == 1 are counties without a program that year 
	assert _m != 2
	drop _m 
	
	
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






