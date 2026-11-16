*********************************************************************************
** Purpose: Merge in county population and children served by a CASA variables
** Author: Emily
** Date: November 16, 2026
*********************************************************************************

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals


********************************************************************************
*** 					Population 										********
*********************************************************************************

import excel using "$onedrive/data/raw_data/CASA/E-4_2010-2020_CountyPopulation.xlsx", cellrange(A2) sheet("Table 1 County State") firstrow clear

* Var names are getting messed up, but I only need 2018-2020 from this data. 
drop B C D E F M Column1 Column2 

ren G Pop2015
ren H Pop2016
ren I Pop2017
ren J Pop2018
ren K Pop2019
ren L Pop2020
ren COUNTY county
drop if mi(county)

reshape long Pop, i(county) j(year) 

tempfile pop1820
save `pop1820'

import excel using "$onedrive/data/raw_data/CASA/E-4_2021-2026_CountyPopulation.xlsx", cellrange(A3) sheet("Table 1 County State") firstrow clear

ren StateCounty county


drop B 
ren C Pop2021
ren D Pop2022
ren E Pop2023
ren F Pop2024
ren G Pop2025
ren H Pop2026

cap drop if mi(county) 

reshape long Pop, i(county) j(year)

append using `pop1820'

drop if inlist(county, "California", "Demographic Research Unit", "Department of Finance", "Phone: (916) 323-4086", "Released on May 1, 2026", "For more information:", "State Total")

drop if mi(Pop)

sort county year
** year stays numeric: 02 now saves funding_ccwip.dta with a numeric year (a string year here would not merge) 

replace county = strtrim(county)

merge 1:m county year using "$onedrive/data/clean_data/funding_ccwip.dta"
	// _m == 3 
	
drop _m 

tempfile popfile
save `popfile'


********************************************************************************
**** 				Children served by a CASA 							********
********************************************************************************

import delimited "$onedrive\data\raw_data\CASA\california_casa_children_served_by_program_statewide_reports.csv", varnames(1) clear 

gen year = 2017 if report == "FY2017/18"
replace year = 2018 if report == "FY2018/19"
replace year = 2019 if report == "FY2019/20"
replace year = 2020 if report == "FY2020/21"
replace year = 2021 if report == "FY2021/22" 
replace year = 2022 if report == "FY2022/23"
replace year = 2023 if report == "FY2023/24"
replace year = 2024 if report == "2024-2025"

ren data_period casasrv_period

drop report period_type period_start period_end period_basis pct_served_as_printed source notes counties

ren program program_name 

isid program_name year

** There are some differences in program naming between the datasets. For the merge, I am going to standardize to the funding ccwip file. 
replace program_name = "CASA Sacramento" if program_name == "Sacramento CASA"
replace program_name = "CASA of Butte, Glenn, Shasta, and Tehama Counties"  if program_name == "CASA of Butte, Glenn, Shasta and Tehama Counties"

** San Diego and Riverside were reported together in 2018 and 2019, inexplicably. Before and after there is separate data for both. For now, I am just going to drop the combined years and it will be missing in 2018 and 2019. 
drop if program_name == "Voices for Children San Diego + Riverside (combined)"

** Glenn and Shasta counties had individual reports in 2017, even though they merged with another CASA program. Just dropping for now.
drop if program_name == "Shasta County (now part of CASA of Butte, Glenn, Shasta and Tehama Counties)"
drop if program_name == "Glenn County (now part of CASA of Butte, Glenn, Shasta and Tehama Counties)"


merge 1:m program_name year using "`popfile'" 
	tab _m 
	** Not a perfect merge, but this is because of the data not being available for all years and the above harmonizations.
	drop _m 

ren children_served child_srv_casa

save "$onedrive/data/clean_data/pop_fund_ccwip.dta", replace



