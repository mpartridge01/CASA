*********************************************************************************
** Purpose: IV regressions and tables
** Author: Michael
** Date: November 16, 2026
*********************************************************************************

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

* Packages used: ssc install ftools ; ssc install reghdfe ; ssc install ivreg2 ; ssc install ranktest ; ssc install ivreghdfe

********************************************************************************
* 				Import data and define locals for iv regressions			   *
********************************************************************************

* import data (made in 08_predictions.do)
use "$onedrive/data/clean_data/instr_reg.dta", clear

local base 2021                    // pre-period year

** Outcomes (in levels; differenced from 2021 below), with names for the table headers
local outcomes "mlos_total place_stability permanence_12m"
local t_mlos_total       "Median Length of Stay"
local t_place_stability  "Placement Stability"
local t_permanence_12m   "Permanency within 12 Months"
local h1_mlos_total      "Median length"
local h2_mlos_total      "of stay"
local h1_place_stability "Placement"
local h2_place_stability "stability"
local h1_permanence_12m  "Permanency"
local h2_permanence_12m  "within 12 months"

** Dependent variable labels for the table headers
local dv_mlos_total      "Change in median length of stay"
local dv_place_stability "Change in placement stability"
local dv_permanence_12m  "Change in permanency"

** Per child: state funding per child in care, with children in care fixed at the base year so the outcome can't move the denominator. Instrument scaled the same way. Set to 0 to use dollars. THIS IS A SUGGESTION FROM CLAUDE THAT I HAVE TURNED OFF RIGHT NOW.
local per_child 1

** Fixed effects and controls
** Everything is a change from 2021, so the program fixed effect is already differenced out (like Dahl & Lochner's d02 variables). Only year effects are needed.
local fe   "year"                  // add "year#c.b_ln_pop" to compare programs of the same size (b_ln_pop = 2021 ln population, made in 08)
local ctrl ""                      // Which controls do we add?
local samp "has_program & inrange(year, 2022, 2024)" // Supplemental years only: the instrument (change in funding from the formula change) is defined 2022-2024

** Standard errors: heteroskedasticity-robust and clustered by program (the panel unit), so errors can be correlated across a program's years.

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

** Outcomes: change since 2021, to match the treatment and instrument
foreach v of local outcomes {
	bysort prog_id: egen double y0_`v' = max(cond(year == `base', `v', .))
	gen double dy_`v' = `v' - y0_`v'
}

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

********************************************************************************
* 							Helper programs for the tables					   *
********************************************************************************

** Coefficient with stars (** 5%, * 10%, as in Dahl & Lochner) and standard error in parentheses
capture program drop cellfmt
program define cellfmt, rclass
	args b se df
	if missing(`se') | `se' == 0 {
		return local b "."
		return local se ""
		exit
	}
	local p = cond(missing(`df'), 2 * normal(-abs(`b' / `se')), 2 * ttail(`df', abs(`b' / `se')))
	local st = cond(`p' < 0.05, "\textsuperscript{**}", cond(`p' < 0.10, "\textsuperscript{*}", ""))
	local bs  = strtrim(string(`b',  "%9.3f"))
	local ses = strtrim(string(`se', "%9.3f"))
	return local b  "`bs'`st'"
	return local se "(`ses')"
end

** One table row: label, then the stored result for each column (results are kept in globals R_<key><column>)
capture program drop texrow
program define texrow
	args handle label key ncol
	local r "`label'"
	forvalues j = 1/`ncol' {
		local r "`r' & ${R_`key'`j'}"
	}
	file write `handle' "`r' \\" _n
end

** Header for tables whose columns are outcomes: outcome names on two lines, then column numbers. stub = text for the first cell of the outcome-name row (e.g. "Sample:")
capture program drop texhead
program define texhead
	args handle stub
	local r1 "`stub'"
	local r2 ""
	local r3 ""
	forvalues j = 1/$NOUT {
		local r1 "`r1' & ${H1_`j'}"
		local r2 "`r2' & ${H2_`j'}"
		local r3 "`r3' & (`j')"
	}
	file write `handle' "`r1' \\" _n "`r2' \\" _n "`r3' \\" _n "\midrule" _n
end

local j = 0
foreach v of local outcomes {
	local ++j
	global H1_`j' "`h1_`v''"
	global H2_`j' "`h2_`v''"
}
global NOUT = `j'

********************************************************************************
* 								Run iv regressions						       *
********************************************************************************

local j = 0
foreach v of local outcomes {
	local ++j
	display as text _n "==================== `v' ===================="
	capture drop esamp_pool esamp_iv3 esamp_yr esamp_lag

	***** Pooled: all three years together (one endogenous, one instrument)
	** Assumes a dollar has the same effect in every year. Just-identified.
	** Report: the Kleibergen-Paap rk Wald F (cluster-robust first-stage F) and the Anderson-Rubin test; both are in the ivreghdfe output.
	ivreghdfe dy_`v' (`d' = `z_pooled') `ctrl' if `samp', absorb(`fe') cluster(prog_id) first
	gen esamp_pool = e(sample)
	cellfmt `=_b[`d']' `=_se[`d']' `=e(df_r)'
	global R_`v'_b3  "`r(b)'"
	global R_`v'_se3 "`r(se)'"
	global R_`v'_f3  = strtrim(string(e(widstat), "%9.2f"))
	global R_`v'_r23 = strtrim(string(e(r2),      "%9.3f"))
	global R_`v'_n3  = strtrim(string(e(N),       "%9.0fc"))
	global R_`v'_pfe3 "No"
	global R_`v'_yfe3 "Yes"

	* First stage by hand, with cluster-robust F (Panel A of the first-stage table)
	reghdfe `d' `z_pooled' `ctrl' if esamp_pool, absorb(`fe') cluster(prog_id)
	cellfmt `=_b[`z_pooled']' `=_se[`z_pooled']' `=e(df_r)'
	global R_fsA_b`j'  "`r(b)'"
	global R_fsA_se`j' "`r(se)'"
	global R_fsA_r2`j' = strtrim(string(e(r2), "%9.3f"))
	global R_fsA_n`j'  = strtrim(string(e(N),  "%9.0fc"))
	testparm `z_pooled'
	global R_fsA_f`j' = strtrim(string(r(F), "%9.2f"))
	global R_fsA_pfe`j' "No"
	global R_fsA_yfe`j' "Yes"

	***** OLS (no instrument), on the same sample as the pooled IV
	* (1) No fixed effects
	reg dy_`v' `d' `ctrl' if esamp_pool, cluster(prog_id)
	cellfmt `=_b[`d']' `=_se[`d']' `=e(df_r)'
	global R_`v'_b1  "`r(b)'"
	global R_`v'_se1 "`r(se)'"
	global R_`v'_f1  ""
	global R_`v'_r21 = strtrim(string(e(r2), "%9.3f"))
	global R_`v'_n1  = strtrim(string(e(N),  "%9.0fc"))
	global R_`v'_pfe1 "No"
	global R_`v'_yfe1 "No"

	* (2) Program and year fixed effects
	reghdfe dy_`v' `d' `ctrl' if esamp_pool, absorb(prog_id year) cluster(prog_id)
	cellfmt `=_b[`d']' `=_se[`d']' `=e(df_r)'
	global R_`v'_b2  "`r(b)'"
	global R_`v'_se2 "`r(se)'"
	global R_`v'_f2  ""
	global R_`v'_r22 = strtrim(string(e(r2), "%9.3f"))
	global R_`v'_n2  = strtrim(string(e(N),  "%9.0fc"))
	global R_`v'_pfe2 "Yes"
	global R_`v'_yfe2 "Yes"

	***** Pooled effect, three instruments (one endogenous, overidentified)
	** Same single effect as above, identified from each year's instrument. Hansen J (in the output) tests whether the three years point to the same effect.
	ivreghdfe dy_`v' (`d' = `z_nonpooled') `ctrl' if `samp', absorb(`fe') cluster(prog_id) first
	gen esamp_iv3 = e(sample)
	cellfmt `=_b[`d']' `=_se[`d']' `=e(df_r)'
	global R_`v'_b4  "`r(b)'"
	global R_`v'_se4 "`r(se)'"
	global R_`v'_f4  = strtrim(string(e(widstat), "%9.2f"))
	global R_`v'_r24 = strtrim(string(e(r2),      "%9.3f"))
	global R_`v'_n4  = strtrim(string(e(N),       "%9.0fc"))
	global R_`v'_pfe4 "No"
	global R_`v'_yfe4 "Yes"

	* First stage on this spec's sample (Panel B of the first-stage table)
	reghdfe `d' `z_nonpooled' `ctrl' if esamp_iv3, absorb(`fe') cluster(prog_id)
	foreach t in 2022 2023 2024 {
		cellfmt `=_b[zfund_`t']' `=_se[zfund_`t']' `=e(df_r)'
		global R_fsB_b`t'_`j'  "`r(b)'"
		global R_fsB_se`t'_`j' "`r(se)'"
	}
	global R_fsB_r2`j' = strtrim(string(e(r2), "%9.3f"))
	global R_fsB_n`j'  = strtrim(string(e(N),  "%9.0fc"))
	testparm `z_nonpooled'
	global R_fsB_f`j' = strtrim(string(r(F), "%9.2f"))
	global R_fsB_pfe`j' "No"
	global R_fsB_yfe`j' "Yes"

	***** By year: each year's funding gets its own instrument (three endogenous, three instruments)
	** Lets the effect differ by year. Each first stage only uses one year of data, so check the Sanderson-Windmeijer F for EACH endogenous variable (in the first-stage output), not just the joint F.
	** Funding is persistent across years, so the 2023 and 2024 effects partly pick up earlier years' money. More of a check than what we should be doing
	ivreghdfe dy_`v' (`d_nonpooled' = `z_nonpooled') `ctrl' if `samp', absorb(`fe') cluster(prog_id) first
	foreach t in 2022 2023 2024 {
		cellfmt `=_b[d_`t']' `=_se[d_`t']' `=e(df_r)'
		global R_yr_b`t'_`j'  "`r(b)'"
		global R_yr_se`t'_`j' "`r(se)'"
	}
	global R_yr_n`j' = strtrim(string(e(N), "%9.0fc"))
	gen esamp_yr = e(sample)
	lincom (d_2022 + d_2023 + d_2024) / 3    // average effect across the three years (this is similar to what Gordon does I think)
	cellfmt `=r(estimate)' `=r(se)' `=r(df)'
	global R_yr_avg_b`j'  "`r(b)'"
	global R_yr_avg_se`j' "`r(se)'"

	* The three first stages by hand, each with a cluster-robust joint F
	local fl ""
	foreach t in 2022 2023 2024 {
		reghdfe d_`t' `z_nonpooled' `ctrl' if esamp_yr, absorb(`fe') cluster(prog_id)
		testparm `z_nonpooled'
		local fl = "`fl'" + cond("`fl'" == "", "", ", ") + strtrim(string(r(F), "%9.2f"))
	}
	global R_yr_f`j' "`fl'"

	***** Current and last year's funding (two endogenous, two instruments)
	** Does money take a year to show up in outcomes? The sum is the cumulative effect of a dollar kept for two years. Dahl does something like this in Table 5. Maybe it makes sense in our setting?
	** Only 2023-2024 have a nonzero lag, so this first stage will be weaker.
	ivreghdfe dy_`v' (`d' d_lag = `z_pooled' z_lag) `ctrl' if `samp', absorb(`fe') cluster(prog_id) first
	cellfmt `=_b[`d']' `=_se[`d']' `=e(df_r)'
	global R_lag_b0_`j'  "`r(b)'"
	global R_lag_se0_`j' "`r(se)'"
	cellfmt `=_b[d_lag]' `=_se[d_lag]' `=e(df_r)'
	global R_lag_b1_`j'  "`r(b)'"
	global R_lag_se1_`j' "`r(se)'"
	global R_lag_n`j' = strtrim(string(e(N), "%9.0fc"))
	gen esamp_lag = e(sample)
	lincom `d' + d_lag
	cellfmt `=r(estimate)' `=r(se)' `=r(df)'
	global R_lag_sum_b`j'  "`r(b)'"
	global R_lag_sum_se`j' "`r(se)'"

	* The two first stages by hand
	reghdfe `d'  `z_pooled' z_lag `ctrl' if esamp_lag, absorb(`fe') cluster(prog_id)
	testparm `z_pooled' z_lag
	local f0 = strtrim(string(r(F), "%9.2f"))
	reghdfe d_lag `z_pooled' z_lag `ctrl' if esamp_lag, absorb(`fe') cluster(prog_id)
	testparm `z_pooled' z_lag
	local f1 = strtrim(string(r(F), "%9.2f"))
	global R_lag_f`j' "`f0', `f1'"

	***** Pre-trend check (placebo): before the money arrived, the instrument shouldn't predict changes in the outcome
	** Changes from 2021 in 2018-2020 regressed on the program's (future) instrument. Coefficients should be near 0.
	reghdfe dy_`v' c.zbar#i.year if has_program & inrange(year, 2018, 2020), absorb(`fe') cluster(prog_id)
}

********************************************************************************
* 			Tables 1a-1c: OLS and IV estimates, one table per outcome		   *
********************************************************************************

foreach v of local outcomes {
	file open tab using "$analysisoutput/tables/iv_`v'.tex", write replace
	file write tab "\begin{table}[htbp]" _n "\centering" _n
	file write tab "\label{tab:iv_`v'}" _n
	file write tab "\begin{tabular}{l*{4}{c}}" _n "\toprule" _n
	** Dependent variable as a header across all four columns
	file write tab " & \multicolumn{4}{c}{`dv_`v''} \\" _n
	file write tab "\cmidrule(lr){2-5}" _n
	file write tab " & OLS & OLS & IV & IV \\" _n
	file write tab " &  &  & One instrument & One instrument per year \\" _n
	file write tab " & (1) & (2) & (3) & (4) \\" _n "\midrule" _n

	texrow tab "Change in state funding" `v'_b 4
	texrow tab "" `v'_se 4
	texrow tab "First-stage F-statistic" `v'_f 4
	texrow tab "R\textsuperscript{2}" `v'_r2 4
	texrow tab "Program fixed effects" `v'_pfe 4
	texrow tab "Year fixed effects" `v'_yfe 4
	texrow tab "Observations" `v'_n 4

	file write tab "\bottomrule" _n "\end{tabular}" _n "\end{table}" _n
	file close tab
}

********************************************************************************
* 				Table 2: First stages of the two IV specs					   *
********************************************************************************

file open tab using "$analysisoutput/tables/iv_first_stage.tex", write replace
file write tab "\begin{table}[htbp]" _n "\centering" _n
file write tab "\label{tab:iv_first_stage}" _n
file write tab "\begin{tabular}{l*{$NOUT}{c}}" _n "\toprule" _n
** Dependent variable as a header across all columns; the columns are the samples for each outcome
file write tab " & \multicolumn{$NOUT}{c}{Change in state funding since 2021} \\" _n
file write tab "\cmidrule(lr){2-`=$NOUT+1'}" _n
texhead tab "Sample:"

file write tab "\multicolumn{`=$NOUT+1'}{l}{\textit{Panel A. One instrument}} \\" _n
texrow tab "Predicted change in funding" fsA_b $NOUT
texrow tab "" fsA_se $NOUT
texrow tab "F-statistic on instrument" fsA_f $NOUT
texrow tab "R\textsuperscript{2}" fsA_r2 $NOUT
texrow tab "Program fixed effects" fsA_pfe $NOUT
texrow tab "Year fixed effects" fsA_yfe $NOUT
texrow tab "Observations" fsA_n $NOUT
file write tab "\midrule" _n

file write tab "\multicolumn{`=$NOUT+1'}{l}{\textit{Panel B. One instrument per year}} \\" _n
foreach t in 2022 2023 2024 {
	texrow tab "Predicted change in funding \(\times\) `t'" fsB_b`t'_ $NOUT
	texrow tab "" fsB_se`t'_ $NOUT
}
texrow tab "F-statistic on instruments (joint)" fsB_f $NOUT
texrow tab "R\textsuperscript{2}" fsB_r2 $NOUT
texrow tab "Program fixed effects" fsB_pfe $NOUT
texrow tab "Year fixed effects" fsB_yfe $NOUT
texrow tab "Observations" fsB_n $NOUT

file write tab "\bottomrule" _n "\end{tabular}" _n "\end{table}" _n
file close tab

********************************************************************************
* 		Table 3: Year-specific and lagged effects (export commented out)	   *
********************************************************************************

/*
file open tab using "$analysisoutput/tables/iv_year_lag.tex", write replace
file write tab "\begin{table}[htbp]" _n "\centering" _n
file write tab "\label{tab:iv_year_lag}" _n
file write tab "\begin{tabular}{l*{$NOUT}{c}}" _n "\toprule" _n
** Dependent variable as a header across all columns; each column is a different outcome
file write tab " & \multicolumn{$NOUT}{c}{Dependent variable: change in outcome since 2021} \\" _n
file write tab "\cmidrule(lr){2-`=$NOUT+1'}" _n
texhead tab "Outcome:"

file write tab "\multicolumn{`=$NOUT+1'}{l}{\textit{Panel A. Separate effect each year}} \\" _n
foreach t in 2022 2023 2024 {
	texrow tab "Change in state funding \(\times\) `t'" yr_b`t'_ $NOUT
	texrow tab "" yr_se`t'_ $NOUT
}
texrow tab "Average of the three years" yr_avg_b $NOUT
texrow tab "" yr_avg_se $NOUT
texrow tab "First-stage F-statistics (2022, 2023, 2024)" yr_f $NOUT
texrow tab "Observations" yr_n $NOUT
file write tab "\midrule" _n

file write tab "\multicolumn{`=$NOUT+1'}{l}{\textit{Panel B. Current and last year's funding}} \\" _n
texrow tab "Change in state funding, current year" lag_b0_ $NOUT
texrow tab "" lag_se0_ $NOUT
texrow tab "Change in state funding, last year" lag_b1_ $NOUT
texrow tab "" lag_se1_ $NOUT
texrow tab "Sum of current and last year" lag_sum_b $NOUT
texrow tab "" lag_sum_se $NOUT
texrow tab "First-stage F-statistics (current, last year)" lag_f $NOUT
texrow tab "Observations" lag_n $NOUT

file write tab "\bottomrule" _n "\end{tabular}" _n "\end{table}" _n
file close tab
*/


/*

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
