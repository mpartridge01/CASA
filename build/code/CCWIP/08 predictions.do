*********************************************************************************
** Purpose: LASSO / Ridge Regression to predit funding.
** Author: Emily
** Date: November 16, 2026
*********************************************************************************

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

** Creating lags for the 990 variables (employees/fundraising/expenditures/etc are factored in to the funding based on the prior year) 
tsset prog_id year
foreach v in emp_count rev_fundraising rev_invest exp_salaries exp_grants exp_prog exp_mgmt casa_spend {
	gen `v'_lag1 = L1.`v'
}
	

gen ln_fund = ln(total_fund)
gen ln_pop = ln(Pop)
** Fitting our model to predict total funding
local y "ln_fund"

** Potential predictors -- I think some of the problem is coming from missings. If any variable is missing, the whole observation is dropped, which is significantly eating into the observation count. 
local x "Pop entries in_care place_stability entry_rates_11_15 entry_rates_16_17 entry_rates_1_2 entry_rates_3_5 entry_rates_6_10 entry_rates_under_1 population_11_15 population_16_17 population_18_20 population_1_2 population_3_5 population_6_10 population_under_1 child_srv_casa n_counties *_lag1"

/*
* Folds by program: every observation of a program goes in the same fold
** If I include i.prog_id, the R2 in sample gets larger (.76) but the out-of-sample R2 gets smaller (.37) 
elasticnet linear `y' `x', alpha(0(0.1)1) 
	lassocoef, display(coef, penalized)       // shrunken coefficients from the selected model
	lassocoef, display(coef, standardized)    // same, on a standardized scale
	lassocoef, display(coef, postselection)   // OLS refit on the selected variables
	lassogof        						  // goodness of fit (MSE, R²) for the selected model
	
*/	
** Now, running the prediction for each year separately. 

** Baseline Funding ** 
preserve
	
keep if year < 2022 & year > 2017
drop if strpos(program_name, "NA" )

** Starting with 220 obs
local x1 "ln_pop in_care entries place_stability i.tier case_closures_total child_srv_casa recurrence_assessment_only reentry_total recurrence_no_recurrence recurrence_total n_counties emp_count rev_invest exp_salaries i.casa_type *_lag1"


elasticnet linear `y' `x1', alpha(0(0.1)1) 
	lassocoef, display(coef, penalized)       // shrunken coefficients from the selected model
	lassocoef, display(coef, standardized)    // same, on a standardized scale
	lassocoef, display(coef, postselection)   // OLS refit on the selected variables
	lassogof   

restore



// 2022

preserve

keep if year == 2022
drop if strpos(program_name, "NA" )
// 44 observations (one per program)



local x2 "i.tier child_srv_casa children_in_foster_care ln_pop entries in_care case_closures_total exits_reunified exits_total in_care_rates_total recurrence_no_recurrence recurrence_total pop2020 n_counties emp_count rev_fundraising exp_salaries exp_mgmt i.casa_type *_lag1"

elasticnet linear `y' `x2', alpha(0(0.1)1) 
	lassocoef, display(coef, penalized)       // shrunken coefficients from the selected model
	lassocoef, display(coef, standardized)    // same, on a standardized scale
	lassocoef, display(coef, postselection)   // OLS refit on the selected variables
	lassogof   

restore 


// 2023
 preserve
keep if year == 2023
drop if strpos(program_name, "NA") 
// 44 obs, one per county.

local x3 "i.tier child_srv_casa children_in_foster_care ln_pop entries in_care case_closures_total exits_total in_care_rates_total recurrence_no_recurrence recurrence_total reentry_total pop2020 n_counties emp_count rev_fundraising rev_invest exp_salaries exp_mgmt i.casa_type *_lag1"

elasticnet linear `y' `x3', alpha(0(0.1)1) cluster(program_name)
	lassocoef, display(coef, penalized)       // shrunken coefficients from the selected model
	lassocoef, display(coef, standardized)    // same, on a standardized scale
	lassocoef, display(coef, postselection)   // OLS refit on the selected variables
	lassogof   


restore 




// 2024

preserve
keep if year == 2024
drop if strpos(program_name, "NA") 
// 44 obs, one per county.


replace tier = 0 if mi(tier)

local x3 "i.tier child_srv_casa children_in_foster_care ln_pop entries in_care case_closures_total exits_total in_care_rates_total recurrence_no_recurrence recurrence_total reentry_total pop2020 n_counties emp_count rev_fundraising rev_invest exp_salaries exp_mgmt i.casa_type *_lag1"

elasticnet linear `y' `x3', alpha(0(0.1)1) 
	lassocoef, display(coef, penalized)       // shrunken coefficients from the selected model
	lassocoef, display(coef, standardized)    // same, on a standardized scale
	lassocoef, display(coef, postselection)   // OLS refit on the selected variables
	lassogof   


restore 

	
preserve 

keep if year >= 2022 & year <=2024
drop if strpos(program_name, "NA")


replace tier = 0 if mi(tier)

local x3 "i.tier child_srv_casa children_in_foster_care ln_pop entries in_care case_closures_total exits_total in_care_rates_total recurrence_no_recurrence recurrence_total reentry_total pop2020 n_counties emp_count rev_fundraising rev_invest exp_salaries exp_mgmt i.casa_type *_lag1"

elasticnet linear `y' `x3', alpha(0(0.1)1) 
	lassocoef, display(coef, penalized)       // shrunken coefficients from the selected model
	lassocoef, display(coef, standardized)    // same, on a standardized scale
	lassocoef, display(coef, postselection)   // OLS refit on the selected variables
	lassogof   
restore

