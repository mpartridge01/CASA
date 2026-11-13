*********************************************************************************
** Purpose: Merge in county population
** Author: Emily
** Date: November 9, 2026
*********************************************************************************

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals



import excel using "$onedrive\data\raw_data\CASA\E-4_2010-2020_CountyPopulation.xlsx", cellrange(A2) sheet("Table 1 County State") firstrow clear

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

import excel using "$onedrive\data\raw_data\CASA\E-4_2021-2026_CountyPopulation.xlsx", cellrange(A3) sheet("Table 1 County State") firstrow clear

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
tostring year, replace 

replace county = strtrim(county)

merge 1:m county year using "$onedrive\data\clean_data\funding_ccwip.dta"
	// _m == 3 
	
drop _m 

save "$onedrive/data/clean_data/pop_fund_ccwip.dta", replace



