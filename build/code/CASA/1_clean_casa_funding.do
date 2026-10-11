*==============================================================================*
*                            clean_casa_funding.do                             *
*==============================================================================*

/* Notes:
1. Imports county-level CASA funding data, FY2015-2026
2. Creates total_state_funds, the sum of all state funding components

Input:  $rawdata/CASA/casa_funding_county_fy2015_2026.csv
*/

*==============================================================================*
*                              Run globals script                              *
*==============================================================================*

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

*==============================================================================*
*                               Import data                                    *
*==============================================================================*

import delimited "$rawdata/CASA/casa_funding_county_fy2015_2026.csv", clear

*==============================================================================*
*                          Total state funding                                 *
*==============================================================================*

* rowtotal treats missing components as zero
egen total_state_funds = rowtotal(jc_base jc_incentive_volunteer_retention ///
	jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive ///
	jc_growth_incentive_a jc_growth_incentive_b ca_casa_supplemental)
