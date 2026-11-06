********************************************************************************
** Purpose: Merge CCWIP variables together and synthesize to one dataset
** Date: 10/12/2026
** Author: Emily Marsh
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

** Importing data - first round of separate variables that had to be scraped, second round those downloaded directly (slightly different naming conventions). ** 
foreach var in case_closures entry_cohort entry_rates exits in_care_rates MLOS population recurrence reentry {
	clear
	import delimited using "$onedrive/data/raw_data/CCWIP/tidy/`var'_panel.csv", varn(1)
	
	cap tostring period , replace 
	
	tempfile `var'_data
	save ``var'_data' 
}

use `case_closures_data', clear 
	foreach var in entry_cohort entry_rates exits in_care_rates MLOS population recurrence reentry {
		merge 1:1 county year using ``var'_data'
			/// Some have 2025 and some variables don't depending on how long is needed to create the 12-month measure.
			
			drop _m 
			
	}
	tostring year , replace 
	
tempfile scrape
save `scrape'

foreach var in entries place_stability {
	clear
	import excel using "$onedrive/data/raw_data/CCWIP/`var'.xlsx", first cellra(A10:L70)
	
	ren A county 
	drop if mi(county) 
	
	ren JUL* `var'JUL*
	
	reshape long `var', i(county) j(year) s
	
	tempfile `var'_data
	save ``var'_data'
}


import excel using  "$onedrive/data/raw_data/CCWIP/in_care.xlsx", first cellra(A8:L68) clear

	ren A county 
	drop if mi(county) 
	
	ren Jul* in_careJul*
	
	reshape long in_care, i(county) j(year) s 
	
	tempfile in_care_data
	save `in_care_data'

	

import excel using  "$onedrive/data/raw_data/CCWIP/recur_malt.xlsx", first cellra(A8:L68) clear

	ren A county 
	drop if mi(county) 
	
	ren JUL* recur_maltJUL*
	
	reshape long recur_malt, i(county) j(year) s 
	
	tempfile recur_malt_data
	save `recur_malt_data'

	
import excel using  "$onedrive/data/raw_data/CCWIP/permanence_12m.xlsx", first cellra(A13:L73) clear

	ren A county 
	drop if mi(county) 
	
	ren JUL* permanence_12mJUL*
	
	reshape long permanence_12m, i(county) j(year) s 
	
	tempfile permanence_12m_data
	save `permanence_12m_data'
	
import excel using  "$onedrive/data/raw_data/CCWIP/reentry2.xlsx", first cellra(A13:L73) clear

	ren A county 
	drop if mi(county) 
	
	ren JUL* reentry2JUL*
	
	reshape long reentry2, i(county) j(year) s 
	
	tempfile reentry2_data
	save `reentry2_data'
	
import excel using "$onedrive/data/raw_data/CCWIP/stability.xlsx", first cellra(A9:L69) clear 

	ren A county 
	drop if mi(county) 
	ren JUL* stabilityJUL*
	
	reshape long stability, i(county) j(year) s
	
	tempfile stability_data 
	save `stability_data'
	
	

use `entries_data', clear
	foreach var in in_care permanence_12m place_stability recur_malt reentry2 stability {
		merge 1:1 county year using ``var'_data'
			//assert _m == 3
			drop _m
	}
	
	replace year = subinstr(year, "Jul1", "", .) 
	replace year = subinstr(year, "JUL", "", .) 
	replace year = substr(year, 1, 4)
	
	collapse (firstnm) entries in_care permanence_12m place_stability recur_malt reentry2 stability , by(county year) 
	
merge 1:1 county year using `scrape'
	tab _m 
	
	** Only interested in individual counties, not state wide. 
	drop if county == "California"
	
	drop _m 
	
save "$onedrive/data/raw_data/CCWIP/CCWIP_county.dta", replace 
