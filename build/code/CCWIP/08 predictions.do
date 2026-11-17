*********************************************************************************
** Purpose: LASSO / Ridge Regression to predit funding
** 			Creates instrument, z
** Author: Emily
** Date: November 16, 2026
*********************************************************************************
set trace on
set tracedepth 2
* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

********************************************************************************

use "$onedrive/data/clean_data/program_pop_fund_ccwip_990.dta", clear
set seed 12345
** Because our prediction variables are likely to be correlated (population, number of children in care, staff expenditure, etc) I am going to start with ElasticNet.

egen prog_id = group(program_name) 
keep if has_program

gen ln_fund = ln(total_fund)
gen ln_pop = ln(Pop)

replace tier = 0 if mi(tier)

** Creating lags for the 990 variables (employees/fundraising/expenditures/etc are factored in to the funding based on the prior year) 
tsset prog_id year
foreach v in emp_count rev_fundraising rev_invest exp_salaries exp_grants exp_prog exp_mgmt casa_spend {
	gen `v'_lag1 = L1.`v'
}
	
*******************************************************************************
// 			LOCALS 
*******************************************************************************
local base 2021
local y "ln_fund"
local x1 "ln_pop in_care entries place_stability i.tier case_closures_total child_srv_casa recurrence_assessment_only reentry_total recurrence_no_recurrence recurrence_total n_counties emp_count rev_invest exp_salaries i.casa_type *_lag1 jc_tier_2013"

local x2 "i.tier child_srv_casa children_in_foster_care ln_pop entries in_care case_closures_total exits_total in_care_rates_total recurrence_no_recurrence recurrence_total pop2020 n_counties emp_count rev_fundraising rev_invest exp_salaries exp_mgmt i.casa_type *_lag1 jc_tier_2013"

local x3 "tier child_srv_casa children_in_foster_care ln_pop entries in_care case_closures_total exits_total in_care_rates_total recurrence_no_recurrence recurrence_total pop2020 n_counties emp_count rev_fundraising rev_invest exp_salaries exp_mgmt casa_type jc_tier_2013 emp_count_lag1 rev_fundraising_lag1 rev_invest_lag1 exp_salaries_lag1 exp_grants_lag1 exp_prog_lag1 exp_mgmt_lag1 casa_spend_lag1"

********************************************************************************
// 			PREDICTIONS
********************************************************************************

foreach v in `x3' {
    bysort prog_id: egen double b_`v' = max(cond(year == `base', `v', .))
}

bysort prog_id: egen  F0_act = max(cond(year == `base', total_fund, .))

**********************************
** Old Formula 
************************************
gen int fold = mod(prog_id, 5) + 1


** Baseline Funding ** 
gen _F0 = 0
gen xb0 = . 

forvalues f = 1/5 {
	elasticnet linear `y' `x1' if year < 2022 & year > 2017 & fold != `f', alpha(0(0.1)1) selection(cv, folds(3))
		qui predict _p if year < 2022 & year > 2017 & fold == `f', penalized 
		replace xb0 = _p if year < 2022 & year > 2017 & fold == `f'
		drop _p
		

}	
	** Back to dollars (smearing so predictions average to actual dollars)
	gen double _s = exp(`y' - xb0) if year < 2022 & year > 2017
	quietly summarize _s
	replace _F0 = exp(xb0) * r(mean) if year < 2022 & year > 2017
	bys prog_id : egen F0_X0 = max(_F0)
	drop xb0 _s
	*/
****************************************
** New Formula 
****************************************
	
// Pooled across supplemental years

gen xb1_X1 = . 
gen xb1_X0 = .

forvalues f = 1/5 {
	
elasticnet linear `y' `x2' if year >= 2022 & year <=2024 & fold != `f', alpha(0(0.1)1)  selection(cv, folds(3))
 
	qui predict _p1 if year >= 2022 & year <=2024 & fold == `f', penalized
	
	** Re-predicting at baseline (2021) characteristic values
	foreach v in `x3' {
		gen double _o_`v' = `v'
		quietly replace `v' = b_`v' if year >= 2022 & year <=2024 & fold == `f'
	}
	quietly predict double _p0 if year >= 2022 & year <=2024 & fold == `f', penalized
	
	** Restore original values
	foreach v in `x3' {
		qui replace `v' = _o_`v'
		drop _o_`v'
	}
	
	
	replace xb1_X1 = _p1 if  year >= 2022 & year <=2024 & fold == `f'
	replace xb1_X0 = _p0 if year >= 2022 & year <=2024 & fold == `f'
	drop _p1 _p0
}

** Back to dollars (smearing so predictions average to actual dollars)
	gen F1_X0_pool = . 
	gen double _s = exp(`y' - xb1_X1) if year >= 2022 & year <=2024
	quietly summarize _s
	replace F1_X0_pool = exp(xb1_X0) * r(mean) if year >= 2022 & year <=2024
	drop _s
	
	
// Individual year instruments

foreach t in 2022 2023 2024 {
	forvalues f = 1/5 {
		elasticnet linear `y' `x2'  if year == `t' & fold != `f', alpha(0(0.1)1) selection(cv, folds(3)) 
		
		qui predict _p1 if year == `t' & fold == `f', penalized
		
		** Re-predicting at baseline (2021) characteristic values
		foreach v in `x3' {
			gen double _o_`v' = `v'
			quietly replace `v' = b_`v' if year == `t' & fold == `f'
		}
		
		qui predict double _p0 if year == `t' & fold == `f', penalized
		
	** Restore original values
	foreach v in `x3' {
		qui replace `v' = _o_`v'
		drop _o_`v'
	}
	
	replace xb1_X1 = _p1 if year == `t' & fold == `f'
	replace xb1_X0 = _p0 if year == `t' & fold == `f'
	drop _p1 _p0
}
}

** Back to dollars (smearing so predictions average to actual dollars)
	gen F1_X0 = .  
	foreach t in 2022 2023 2024 {
	gen double _s = exp(`y' - xb1_X1) if year == `t'
	quietly summarize _s
	replace F1_X0 = exp(xb1_X0) * r(mean) if year == `t'
	drop _s
	
        }
	

	
********************************************************************************
// 			CREATE INSTRUMENT 
********************************************************************************
** Treatment: Change in funds from before supplemental funding to after. Each will be the difference between funding in 2021 and the supp year.
gen D_fund = (total_fund - F0_act)

** Instrument: change in funding due to the change in the formula. ie: F_1(X_0) - F_0(X_0)
gen Z_pool = (F1_X0_pool - F0_X0)
gen Z = (F1_X0 - F0_X0)

foreach t in 2022 2023 2024 {
	gen Z_`t' = Z * (year == `t')
}
drop Z 
save "$onedrive/data/clean_data/instr_reg.dta", replace 
