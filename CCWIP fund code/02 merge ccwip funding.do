********************************************************************************
** Purpose: Merge together CCWIP and funding data and harmonize to the program level
** Date: 10/13/2026
** Emily Marsh
********************************************************************************

********************************************************************************
** 							RUN GLOBALS                                       **
********************************************************************************
  ** EMF return to this **
  
global onedrive "C:\Users\emi\OneDrive - UC San Diego\Research\CASA\" 
********************************************************************************
** 						IMPORT FUNDING DATA                                   **
********************************************************************************

import delimited "$onedrive\data\raw_data\CASA\casa_funding_program_fy2015_2026.csv", varnames(1) clear

isid program_name fiscal_year

** Prepping funding to be merged into the CCWIP data
preserve
	ren fiscal_year year
	replace year = substr(year, 1, 4)
	
	keep year program_name jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b ca_casa_supplemental ca_casa_supp_row_label 
	
	tempfile funding_program
	save `funding_program'
restore

save "$onedrive\data\raw_data\CASA\casa_funding_fy2015_2026.csv", replace 

keep program_name county_* 
collapse (firstnm) county_* , by(program_name)

** somehow Sutter is getting overwritten in the collapse. 
replace county_2 = "Sutter" if county_2 == "Yuba"

isid program_name

reshape long county_, i(program_name) j(county_no)

ren county_ county
drop if mi(county)

duplicates drop county program_name, force

merge 1:m county using "$onedrive\data\raw_data\CCWIP/CCWIP_county.dta"
	assert _m != 1 
	** _m == 2 because some counties (Alpine, Colusa, Sierra, Trinity, Tuolumne) don't have CASA programs at all. 
	drop _m 
	
merge m:1 program_name year using `funding_program'
	drop _m 
	** Some _m == 1 because funding data isn't here for 2011-2014 or for the counties that don't have CASA programs (and thus don't have CASA funding)
	
	
** Funding data missing. 
drop if inlist(year, "2011", "2012", "2013", "2014")

save "$onedrive/data/clean_data"






