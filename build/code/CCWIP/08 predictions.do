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

** Because our prediction variables are likely to be correlated (population, number of children in care, staff expenditure, etc) I am going to start with ElasticNet.

egen prog_id = group(program_name) 

** Creating lags for the 990 variables (employees/fundraising/expenditures/etc are factored in to the funding based on the prior year) 
tsset prog_id year
foreach v in emp_count rev_fundraising rev_invest exp_salaries exp_grants exp_prog exp_mgmt casa_spend {
	gen `v'_lag1 = L1.`v'
}


gen ln_fund = ln(total_fund)
** Fitting our model to predict total funding
local y "ln_fund"

** Potential predictors
local x "Pop entries in_care entry_rates_11_15 entry_rates_16_17 entry_rates_1_2 entry_rates_3_5 entry_rates_6_10 entry_rates_under_1 population_11_15 population_16_17 population_18_20 population_1_2 population_3_5 population_6_10 population_under_1 child_srv_casa n_counties *_lag1"


* Folds by program: every observation of a program goes in the same fold
gen fold = mod(prog_id, 5) + 1

elasticnet linear `y' `x', alpha(0.1(0.1)1)
	lassocoef, display(coef, penalized)       // shrunken coefficients from the selected model
	lassocoef, display(coef, standardized)    // same, on a standardized scale
	lassocoef, display(coef, postselection)   // OLS refit on the selected variables
	lassogof        						  // goodness of fit (MSE, R²) for the selected model
	
	
	
