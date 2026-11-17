*********************************************************************************
** Purpose: Simulated instrument for state CASA funding (FY 2018-19 to 2024-25)
**          - predict the CA CASA supplemental (2022-2024) from PRE-PERIOD program
**            characteristics with elastic net (lasso/ridge), cross-fitted by program
**          - build the instrument = predicted state funding per child in care
**          - first stages (pooled and by year), IV, and a pre-trend check
** Date: November 16, 2026
*********************************************************************************

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

* ssc install reghdfe ; ssc install ftools ; ssc install ivreg2 ; ssc install ivreghdfe (once)

********************************************************************************
**                               Choices                                       **
********************************************************************************

** Pre-period used to measure the program characteristics that go into the prediction.
**   2021 only:   closest to what the 2022 award was based on, but one noisy (COVID) year
**   2018-2021:   averages out year-to-year noise, but older

** Pick ONE before looking at the IV results (choose on out-of-sample R2 and first-stage F only).
local pre_start 2021
local pre_end   2021

** Sample years for the panel (instrument is 0 for the supplemental before 2022)
local first_year 2018
local last_year  2024

** Outcomes
local outcomes "permanence_12m place_stability reentry2 recur_malt"

** Elastic net mixing values: 0 = ridge, 1 = lasso (cross-validation picks the best one)
local alphas "0 0.25 0.5 0.75 1"

set seed 20261116

********************************************************************************
**                                  Data                                      **
********************************************************************************

** Program x year panel with the Judicial Council expected funding (made in 07)
use "$onedrive/data/clean_data/program_pop_fund_ccwip_990.dta", clear
capture destring year, replace
keep if has_program
isid program_name year

egen prog_id = group(program_name)
xtset prog_id year

********************************************************************************
**              1. Pre-period characteristics (time-invariant)                 **
********************************************************************************

** Everything is measured in the pre-period and copied to every year of the program, so the instrument can't respond to anything that happens after 2021 (including the funding itself).
** Outcomes (permanence etc.) are left out on purpose, so the instrument isn't built from pre-period outcome levels.
local counts "Pop pop2020 in_care children_in_foster_care child_srv_casa entries exits_total exp_salaries exp_total rev_total rev_gov rev_fundraising casa_spend emp_count vol_count"
local levels "n_counties jc_small jc_tier_2013 jc_multi in_care_rates_total entry_rates_total"

local xpre ""
foreach v of local counts {
	gen double _ln = ln(1 + max(`v', 0)) if !missing(`v')
	bysort prog_id: egen double pre_ln_`v' = mean(cond(inrange(year, `pre_start', `pre_end'), _ln, .))
	drop _ln
	local xpre `xpre' pre_ln_`v'
}
foreach v of local levels {
	bysort prog_id: egen double pre_`v' = mean(cond(inrange(year, `pre_start', `pre_end'), `v', .))
	local xpre `xpre' pre_`v'
}
** Share of foster children served by a CASA (the small-program ranking variable)
gen double _r = child_srv_casa / children_in_foster_care
bysort prog_id: egen double pre_share_served = mean(cond(inrange(year, `pre_start', `pre_end'), _r, .))
drop _r
local xpre `xpre' pre_share_served

** Lasso drops any observation with a missing predictor, so fill gaps with the median and flag them
foreach v of local xpre {
	quietly count if missing(`v')
	if r(N) > 0 {
		gen byte miss_`v' = missing(`v')
		quietly summarize `v', detail
		replace `v' = r(p50) if missing(`v')
	}
}
capture ds miss_*
if !_rc local xpre `xpre' `r(varlist)'

** Denominator for per-child funding: children in care in the pre-period (fixed, so permanency can't move the denominator)
bysort prog_id: egen double care_pre = mean(cond(inrange(year, `pre_start', `pre_end'), in_care, .))

********************************************************************************
**   2. Predict the supplemental for each year, cross-fitted by program         **
********************************************************************************

** For each of 2022, 2023, 2024: regress ln(supplemental that year) on the pre-period characteristics.
** Cross-fitting: split the 44 programs into 11 groups of 4. Each program's prediction comes from a model fit on the OTHER 40 programs, so a program's own (possibly endogenous) award can't leak into its instrument.
gen int fold = mod(prog_id, 11) + 1

gen double ln_supp = ln(ca_casa_supplemental) if ca_casa_supplemental > 0
gen double supp_hat = 0          // predicted supplemental ($), 0 before 2022

foreach t in 2022 2023 2024 {
	gen double _xb = .
	forvalues f = 1/11 {
		quietly elasticnet linear ln_supp `xpre' if year == `t' & fold != `f', ///
			alpha(`alphas') selection(cv, folds(5)) rseed(`=1000*`t' + `f'')
		quietly predict double _p if year == `t' & fold == `f', penalized
		replace _xb = _p if year == `t' & fold == `f'
		drop _p
	}

	** Out-of-sample fit for this year (compare to ln population alone)
	quietly summarize ln_supp if year == `t'
	local tss = r(Var) * (r(N) - 1)
	gen double _e2 = (ln_supp - _xb)^2 if year == `t'
	quietly summarize _e2
	display as text "Out-of-sample R2, `t' (elastic net): " as result %5.3f 1 - r(sum) / `tss'
	quietly regress ln_supp pre_ln_pop2020 if year == `t'
	display as text "In-sample R2,     `t' (ln pop only): " as result %5.3f e(r2)

	** Back to dollars (smearing so predictions average to actual dollars)
	gen double _s = exp(ln_supp - _xb) if year == `t'
	quietly summarize _s
	replace supp_hat = exp(_xb) * r(mean) if year == `t'
	drop _xb _e2 _s
}

** Which predictors matter (full-sample fit; for interpretation only, not used in the instrument)
foreach t in 2022 2023 2024 {
	quietly elasticnet linear ln_supp `xpre' if year == `t', alpha(`alphas') selection(cv, folds(5)) rseed(`t')
	display as text _n "Selected predictors, `t' (alpha = " as result e(alpha_sel) as text ")"
	lassocoef, display(coef, standardized)
}

********************************************************************************
**                    3. Treatment and instrument                              **
********************************************************************************

** Treatment: actual state CASA funding (Judicial Council + supplemental), $1,000s per pre-period child in care
gen double fund_pc = (jc_total_act + cond(missing(ca_casa_supplemental), 0, ca_casa_supplemental)) / care_pre / 1000
** Instrument: predicted state funding = Judicial Council funding from the rule (07: tier base + augmentation + expected incentive) + predicted supplemental
gen double z_pc = (jc_total_exp + supp_hat) / care_pre / 1000

** One instrument per supplemental year
foreach t in 2022 2023 2024 {
	gen double z_`t' = z_pc * (year == `t')
}

** Size controls interacted with year: compare programs of the same size, so the instrument isn't just "big vs small programs"
** (this is the confounding concern: bigger programs get more money AND may be on different trends)
gen double c_lnpop  = pre_ln_pop2020
gen double c_lncare = pre_ln_in_care

keep if inrange(year, `first_year', `last_year')

********************************************************************************
**                          4. First stages                                    **
********************************************************************************

** (a) Pooled: one instrument, one coefficient
reghdfe fund_pc z_pc, absorb(prog_id year) cluster(prog_id)
reghdfe fund_pc z_pc, absorb(prog_id year year#c.c_lnpop year#c.c_lncare) cluster(prog_id)
test z_pc     // F-stat of the instrument (rule of thumb: well above 10)

** (b) By year: three instruments, joint F
reghdfe fund_pc z_2022 z_2023 z_2024, absorb(prog_id year year#c.c_lnpop year#c.c_lncare) cluster(prog_id)
test z_2022 z_2023 z_2024

********************************************************************************
**                        5. IV (2SLS) estimates                               **
********************************************************************************

foreach y of local outcomes {
	display as text _n "==================== `y' ===================="
	** Pooled instrument (main)
	ivreghdfe `y' (fund_pc = z_pc), absorb(prog_id year year#c.c_lnpop year#c.c_lncare) cluster(prog_id) first
	** Three instruments (robustness)
	ivreghdfe `y' (fund_pc = z_2022 z_2023 z_2024), absorb(prog_id year year#c.c_lnpop year#c.c_lncare) cluster(prog_id)
}

********************************************************************************
**              6. Pre-trend check (reduced form by year)                      **
********************************************************************************

** Exposure = average predicted supplemental per child over 2022-2024 (time-invariant).
** Coefficients for 2018-2020 (relative to 2021) should be near 0: high- and low-exposure programs were on the same path before the money arrived.
bysort prog_id: egen double expo = mean(cond(inrange(year, 2022, 2024), supp_hat / care_pre / 1000, .))
foreach y of local outcomes {
	reghdfe `y' ib2021.year#c.expo, absorb(prog_id year year#c.c_lnpop year#c.c_lncare) cluster(prog_id)
}
