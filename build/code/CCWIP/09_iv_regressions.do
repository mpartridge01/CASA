*********************************************************************************
** Purpose: IV regressions
** Author: Michael
** Date: November 16, 2026
*********************************************************************************
/*
* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

* Packages used: ssc install ftools ; ssc install reghdfe ; ssc install ivreg2 ; ssc install ranktest ; ssc install ivreghdfe ; ssc install weakiv

********************************************************************************

********************************************************************************
* 				Import data and define locals for iv regressions			   *
********************************************************************************

* import data
use "$onedrive/data/clean_data/instr_reg.dta", clear

local y    "NAME OF OUTCOME VARIABLE"
local d    "total_fund"             // endogenous variable. Should this be per child? Claude tells me that it should be: state funding per child in care, with children in care fixed at the pre-period (2021) so the outcome can't move the denominator. Scale the instrument the same way.
local z_pooled    "Z"     // Simulated funding pooled between 2022-2024

** Fixed effects and controls
local fe   "prog_id year" // program and year fixed effects
local ctrl ""             // Which controls do we add?
local samp "has_program & inrange(year, 2018, 2024)" // Only look at programs (not counties without one) between 2018-2024

xtset prog_id year


* DEPENDS ON HOW INSTRUMENTS ARE SET UP
** Year-specific endogenous variables and instruments (funding/instrument in that year, 0 otherwise)
foreach t in 2022 2023 2024 {
	gen d_`t' = `d'        * (year == `t')
	gen z_`t' = `z_pooled' * (year == `t')
}
local d_nonpooled "d_2022 d_2023 d_2024"
local z_nonpooled "z_2022 z_2023 z_2024"

** Last year's funding and instrument (built before restricting the sample, so 2018 gets its 2017 value)
bysort prog_id (year): gen d_lag = `d'[_n-1]        if year == year[_n-1] + 1
bysort prog_id (year): gen z_lag = `z_pooled'[_n-1] if year == year[_n-1] + 1

keep if `samp'

********************************************************************************
* 								Run iv regressions						       *
********************************************************************************


***** Pooled: all three years together (one endogenous, one instrument)
** Assumes a dollar has the same effect in every year. Strongest first stage, just-identified.
** Report: the Kleibergen-Paap rk Wald F (cluster-robust first-stage F) and the Anderson-Rubin test (valid even if the instrument is weak); both are in the ivreghdfe output.
ivreghdfe `y' (`d' = `z_pooled') `ctrl', absorb(`fe') cluster(prog_id) first
gen esamp_pool = e(sample)

* Anderson-Rubin confidence interval (weak-instrument robust)
capture noisily weakiv

* First stage by hand, with cluster-robust F
reghdfe `d' `z_pooled' `ctrl' if esamp_pool, absorb(`fe') cluster(prog_id)
testparm `z_pooled'







***** Pooled effect, three instruments (one endogenous, overidentified)
** Same single effect as A, identified from each year's instrument. Hansen J (in the output) tests whether the three years point to the same effect, i.e. whether A's assumption holds.
ivreghdfe `y' (`d' = `z_nonpooled') `ctrl', absorb(`fe') cluster(prog_id) first








***** By year: each year's funding gets its own instrument (three endogenous, three instruments)
** Lets the effect differ by year. Each first stage only uses one year of data, so check the Sanderson-Windmeijer F for EACH endogenous variable (in the first-stage output), not just the joint F.
** Funding is persistent across years, so the 2023 and 2024 effects partly pick up earlier years' money. More of a check than what we should be doing
ivreghdfe `y' (`d_nonpooled' = `z_nonpooled') `ctrl', absorb(`fe') cluster(prog_id) first
lincom (d_2022 + d_2023 + d_2024) / 3    // average effect across the three years (this is similar to what Gordon does I think)
gen esamp_yr = e(sample)

* The three first stages by hand, each with a cluster-robust joint F
foreach t in 2022 2023 2024 {
	reghdfe d_`t' `z_nonpooled' `ctrl' if esamp_yr, absorb(`fe') cluster(prog_id)
	testparm `z_nonpooled'
}




***** Current and last year's funding (two endogenous, two instruments) 
** Does money take a year to show up in outcomes? The sum is the cumulative effect of a dollar kept for two years. Dahl does something like this in Table 5. Maybe it makes sense in our setting?
ivreghdfe `y' (`d' d_lag = `z_pooled' z_lag) `ctrl', absorb(`fe') cluster(prog_id) first
lincom `d' + d_lag
gen esamp_lag = e(sample)

* The two first stages by hand
reghdfe `d'  `z_pooled' z_lag `ctrl' if esamp_lag, absorb(`fe') cluster(prog_id)
testparm `z_pooled' z_lag
reghdfe d_lag `z_pooled' z_lag `ctrl' if esamp_lag, absorb(`fe') cluster(prog_id)
testparm `z_pooled' z_lag


*/

* CLAUDE VERSION BELOW taking into account 08






*********************************************************************************
** Purpose: IV regressions
** Author: Michael
** Date: November 16, 2026
*********************************************************************************

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

* Packages used: ssc install ftools ; ssc install reghdfe ; ssc install ivreg2 ; ssc install ranktest ; ssc install ivreghdfe ; ssc install weakiv

********************************************************************************

********************************************************************************
* 				Import data and define locals for iv regressions			   *
********************************************************************************

* import data (made in 08_predictions.do)
use "$onedrive/data/clean_data/instr_reg.dta", clear

local base 2021                    // pre-period year
local y    "mlos_total"        // outcome (in levels; differenced from 2021 below)

** Per child: state funding per child in care, with children in care fixed at the base year so the outcome can't move the denominator. Instrument scaled the same way. Set to 0 to use dollars. THIS IS A SUGGESTION FROM CLAUDE THAT I HAVE TURNED OFF RIGHT NOW.
local per_child 1

** Fixed effects and controls
** Everything is a change from 2021, so the program fixed effect is already differenced out (like Dahl & Lochner's d02 variables). Only year effects are needed.
local fe   "year"                  // add "year#c.b_ln_pop" to compare programs of the same size (b_ln_pop = 2021 ln population, made in 08)
local ctrl ""                      // Which controls do we add?
local samp "has_program & inrange(year, 2022, 2024)" // Supplemental years only: the instrument (change in funding from the formula change) is defined 2022-2024

xtset prog_id year

********************************************************************************
* 						Treatment, instrument and outcome				       *
********************************************************************************

** Children in care in the base year (denominator for per-child versions)
bysort prog_id: egen double care0 = max(cond(year == `base', in_care, .))

** Treatment: change in state funding since 2021 (D_fund from 08). Instrument: change in funding due to the formula change, F1(X0) - F0(X0) (Z from 08)
if `per_child' {
	gen double dfund = D_fund / care0 / 1000      // $1,000s per 2021 child in care
	gen double zfund = Z_pool      / care0 / 1000
}
else {
	gen double dfund = D_fund / 1000              // $1,000s
	gen double zfund = Z_pool      / 1000
}
local d        "dfund"
local z_pooled "zfund"

** Outcome: change since 2021, to match the treatment and instrument
bysort prog_id: egen double y0 = max(cond(year == `base', `y', .))
gen double dy = `y' - y0

** Year-specific endogenous variables and instruments (change in that year, 0 otherwise)
foreach t in 2022 2023 2024 {
	gen double d_`t' = `d'        * (year == `t')
	** EM Edit for consistency with 08
	//gen double z_`t' = `z_pooled' * (year == `t')
	gen double zfund_`t' = Z_`t' / care0 / 1000
}
local d_nonpooled "d_2022 d_2023 d_2024"
local z_nonpooled "zfund_2022 zfund_2023 zfund_2024"

** Last year's change in funding and instrument. In 2021 both are 0 by construction (no change from itself), so 2022's lag is 0.
replace `d'        = 0 if year == `base'
replace `z_pooled' = 0 if year == `base'
bysort prog_id (year): gen double d_lag = `d'[_n-1]        if year == year[_n-1] + 1
bysort prog_id (year): gen double z_lag = `z_pooled'[_n-1] if year == year[_n-1] + 1

** Pre-trend check (section E): average instrument over 2022-2024, one value per program
bysort prog_id: egen double zbar = mean(cond(inrange(year, 2022, 2024), `z_pooled', .))

preserve                           // keep pre-period years for section E
keep if `samp'

********************************************************************************
* 								Run iv regressions						       *
********************************************************************************

***** Pooled: all three years together (one endogenous, one instrument)
** Assumes a dollar has the same effect in every year. Just-identified.
** Report: the Kleibergen-Paap rk Wald F (cluster-robust first-stage F) and the Anderson-Rubin test; both are in the ivreghdfe output.
ivreghdfe dy (`d' = `z_pooled') `ctrl', absorb(`fe') cluster(prog_id) first
gen esamp_pool = e(sample)

* Anderson-Rubin confidence interval (weak-instrument robust)
capture noisily weakiv

* First stage by hand, with cluster-robust F
reghdfe `d' `z_pooled' `ctrl' if esamp_pool, absorb(`fe') cluster(prog_id)
testparm `z_pooled'


***** Pooled effect, three instruments (one endogenous, overidentified)
** Same single effect as above, identified from each year's instrument. Hansen J (in the output) tests whether the three years point to the same effect.
ivreghdfe dy (`d' = `z_nonpooled') `ctrl', absorb(`fe') cluster(prog_id) first


***** By year: each year's funding gets its own instrument (three endogenous, three instruments)
** Lets the effect differ by year. Each first stage only uses one year of data, so check the Sanderson-Windmeijer F for EACH endogenous variable (in the first-stage output), not just the joint F.
** Funding is persistent across years, so the 2023 and 2024 effects partly pick up earlier years' money. More of a check than what we should be doing
ivreghdfe dy (`d_nonpooled' = `z_nonpooled') `ctrl', absorb(`fe') cluster(prog_id) first
lincom (d_2022 + d_2023 + d_2024) / 3    // average effect across the three years (this is similar to what Gordon does I think)
gen esamp_yr = e(sample)

* The three first stages by hand, each with a cluster-robust joint F
foreach t in 2022 2023 2024 {
	reghdfe d_`t' `z_nonpooled' `ctrl' if esamp_yr, absorb(`fe') cluster(prog_id)
	testparm `z_nonpooled'
}


***** Current and last year's funding (two endogenous, two instruments)
** Does money take a year to show up in outcomes? The sum is the cumulative effect of a dollar kept for two years. Dahl does something like this in Table 5. Maybe it makes sense in our setting?
** Only 2023-2024 have a nonzero lag, so this first stage will be weaker.
ivreghdfe dy (`d' d_lag = `z_pooled' z_lag) `ctrl', absorb(`fe') cluster(prog_id) first
lincom `d' + d_lag
gen esamp_lag = e(sample)

* The two first stages by hand
reghdfe `d'  `z_pooled' z_lag `ctrl' if esamp_lag, absorb(`fe') cluster(prog_id)
testparm `z_pooled' z_lag
reghdfe d_lag `z_pooled' z_lag `ctrl' if esamp_lag, absorb(`fe') cluster(prog_id)
testparm `z_pooled' z_lag

restore

***** Pre-trend check (placebo): before the money arrived, the instrument shouldn't predict changes in the outcome
** Changes from 2021 in 2018-2020 regressed on the program's (future) instrument. Coefficients should be near 0.
reghdfe dy c.zbar#i.year if has_program & inrange(year, 2018, 2020), absorb(`fe') cluster(prog_id)
