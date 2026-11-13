*==============================================================================*
*                     07_expected_baseline.do                                  *
*==============================================================================*

* Notes:
* 1. Builds the Judicial Council baseline funding a program should get from the
*    funding rule alone (no incentives), and checks it against what it got.
*      In:  $onedrive/data/clean_data/program_pop_fund_ccwip_990.dta
*      Out: $onedrive/data/clean_data/program_pop_fund_ccwip_990_jc.dta (program x year, adds the expected variables)
*           $onedrive/data/clean_data/jc_grant_lines.dta             (Judicial Council grant line x year, FY 2015-16 to 2025-26)
*           $analysisoutput/figures/jc_expected_vs_actual.png            (baseline, FY 2018-19 to 2025-26)
*           $analysisoutput/figures/jc_incentive_expected_vs_actual.png  (incentives, FY 2018-19 to 2025-26)
*           $analysisoutput/figures/jc_total_expected_vs_actual.png      (baseline + incentives, FY 2018-19 to 2025-26)
*           (versions with every year from FY 2015-16 are commented out at the end)
* 2. The rule (no incentives), per Judicial Council grant line:
*      base = 2013 tier amount (tier 1-4: 26,000 / 34,000 / 42,000 / 50,000)
*             x 1.15 from FY 2018-19 (July 2018 revision)
*             x 1.5  if the program is two counties funded together
*      $500K augmentation, FY 2018-19 to FY 2023-24 only: each line gets
*             500,000 x (its base / sum of all lines' bases that year)
*      Expected baseline = base + augmentation share.
*    From FY 2024-25 the $500K became an incentive (Growth Incentive A), so the
*    expected baseline is base only.
* 3. The tier is the 2013 tier (jc_tier_2013), set from county population, so
*    the prediction uses no funding data.
* 4. Butte/Glenn/Shasta/Tehama is one program in the panel (the CA CASA supplement
*    funds the four counties together), but the Judicial Council funds it as two
*    grant lines, Butte/Glenn and Shasta/Tehama, each a tier 2 two-county
*    program. Its expected amount is two lines' worth. For the graph it is split
*    into its two lines (the Judicial Council tables give both lines the same
*    base and augmentation, so each is half the combined amount).
* 5. Incentives (jc_incentive_*, jc_growth_incentive*) are excluded from the baseline on both sides.
* 6. Expected incentive: treat who wins an incentive as random within the pool
*    the Judicial Council ranks programs in, so each grant line's expected
*    incentive = (number of awards in its pool / number of lines in its pool)
*    x award amount, summed over the incentives that year:
*      FY 2015-16 to 2017-18: incentives A and B, 20 awards each, pool = all 45 lines
*      FY 2018-19 to 2023-24: growth incentive, 13 awards among the 23 small
*                             lines and 14 among the 22 large lines
*      FY 2024-25 on:         Growth Incentive A, 15 small and 15 large awards;
*                             Growth Incentive B, 13 small and 14 large awards
*    Small = 2020 population under 300,000 (jc_small, set in 05). The number of
*    awards and the award amount come from the funding data each year and are
*    checked against these counts. Butte/Glenn/Shasta/Tehama counts as two
*    small lines. Expected incentives add up to actual incentives every year.

*==============================================================================*
*                              Run globals script                              *
*==============================================================================*

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

*==============================================================================*
*                                  Import                                      *
*==============================================================================*

use "$onedrive/data/clean_data/program_pop_fund_ccwip_990.dta", clear
capture destring year, replace
isid program_name year

*==============================================================================*
*            1. Expected baseline funding from the rule (no incentives)        *
*==============================================================================*

* Base per grant line: 2013 tier amount x 1.15 (from FY 2018-19) x 1.5 (multi-county)
gen double jc_line_base_exp = (26000*(jc_tier_2013 == 1) + 34000*(jc_tier_2013 == 2) + ///
                               42000*(jc_tier_2013 == 3) + 50000*(jc_tier_2013 == 4)) ///
                              * cond(year >= 2018, 1.15, 1) * cond(jc_multi, 1.5, 1) if has_program

* Base for the program: lines x line base (2 lines for Butte/Glenn/Shasta/Tehama)
gen double jc_base_exp = jc_line_base_exp * jc_n_lines

* $500K augmentation (FY 2018-19 to 2023-24): split in proportion to base
bysort year: egen double _sum_base_exp = total(jc_base_exp)
gen double jc_aug_exp = cond(inrange(year, 2018, 2023), 500000 * jc_base_exp / _sum_base_exp, 0) if has_program
drop _sum_base_exp

* Expected and actual baseline funding, no incentives
gen double jc_noinc_exp = jc_base_exp + jc_aug_exp
gen double jc_noinc_act = jc_base + jc_augmentation_500k if has_program
gen double jc_noinc_diff = jc_noinc_act - jc_noinc_exp

label var jc_line_base_exp "Expected JC base per grant line (2013 tier x 1.15 from 2018 x 1.5 if multi-county)"
label var jc_base_exp      "Expected JC base (all grant lines in the program)"
label var jc_aug_exp       "Expected share of the 500K augmentation (FY 2018-19 to 2023-24)"
label var jc_noinc_exp     "Expected JC baseline funding, no incentives (base + augmentation)"
label var jc_noinc_act     "Actual JC baseline funding, no incentives (jc_base + jc_augmentation_500k)"
label var jc_noinc_diff    "Actual minus expected JC baseline funding"

* Check: the sum of expected bases equals the Judicial Council's total base each year
* ($1,795,000 in 2015-2017; $2,079,200 in 2018-2022; $2,103,350 in 2023)
tabstat jc_base_exp jc_base jc_aug_exp jc_augmentation_500k if has_program, by(year) stat(sum) format(%12.0fc)

* Check: the rule predicts actual funding to the dollar in FY 2015-16 to 2025-26
* (differences under $1 are the Judicial Council rounding the $500K shares).
* The one exception: San Luis Obispo in FY 2015-16 was funded at tier 3
* ($42,000) instead of its 2013 tier 2 ($34,000).
list program_name year jc_tier_2013 jc_tier jc_noinc_act jc_noinc_exp jc_noinc_diff ///
    if has_program & year <= 2025 & abs(jc_noinc_diff) > 1, noobs
assert abs(jc_noinc_diff) <= 1 if has_program & year <= 2025 & ///
    !(program_name == "CASA of San Luis Obispo County" & year == 2015)

*==============================================================================*
*        1b. Expected incentive (as good as random within the ranking pool)    *
*==============================================================================*

* Ranking pool: all programs in FY 2015-17; small vs large from FY 2018-19
gen byte _grp = cond(year <= 2017, 0, cond(jc_small == 1, 1, 2)) if has_program
bysort year _grp: egen double _lines = total(jc_n_lines)

gen double jc_inc_exp = 0 if has_program
gen double jc_inc_act = 0 if has_program
local k = 0
foreach v in jc_incentive_volunteer_retention jc_incentive_dependency_served jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b {
	local ++k
	* Award amount that year (every award is the same amount; Butte/Glenn/Shasta/Tehama is left out because it can hold two awards)
	bysort year: egen double _amt`k' = max(cond(jc_n_lines == 1 & has_program, `v', .))
	replace _amt`k' = 0 if missing(_amt`k')
	* Number of awards each program holds, and in its pool
	gen double _aw = cond(_amt`k' > 0, `v' / _amt`k', 0) if has_program
	bysort year _grp: egen double _naw`k' = total(_aw)
	drop _aw
	* Expected incentive: chance of an award in the pool x amount x number of lines
	replace jc_inc_exp = jc_inc_exp + (_naw`k' / _lines) * _amt`k' * jc_n_lines if has_program
	replace jc_inc_act = jc_inc_act + `v' if has_program
}

* Check: number of awards per pool matches the funding rules
*   _naw1, _naw2 = incentives A and B (2015-17); _naw3 = growth incentive (2018-23); _naw4, _naw5 = Growth Incentives A and B (2024 on)
assert _naw1 == 20 & _naw2 == 20 if has_program & year <= 2017
assert _naw3 == 13 if has_program & inrange(year, 2018, 2023) & _grp == 1
assert _naw3 == 14 if has_program & inrange(year, 2018, 2023) & _grp == 2
assert _naw4 == 15 if has_program & year >= 2024
assert _naw5 == 13 if has_program & year >= 2024 & _grp == 1
assert _naw5 == 14 if has_program & year >= 2024 & _grp == 2
drop _grp _lines _amt* _naw*

* Check: expected incentives add up to actual incentives every year
bysort year: egen double _te = total(jc_inc_exp)
bysort year: egen double _ta = total(jc_inc_act)
assert abs(_te - _ta) < 1
drop _te _ta

* Totals: baseline + incentives
gen double jc_total_exp = jc_noinc_exp + jc_inc_exp
gen double jc_total_act = jc_noinc_act + jc_inc_act

label var jc_inc_exp   "Expected JC incentives (award chance within small/large pool x amount)"
label var jc_inc_act   "Actual JC incentives (all incentive lines)"
label var jc_total_exp "Expected JC funding: baseline + expected incentives"
label var jc_total_act "Actual JC funding: baseline + incentives"

* Save the panel with the new variables
format jc_line_base_exp jc_base_exp jc_aug_exp jc_noinc_exp jc_noinc_act jc_noinc_diff jc_inc_exp jc_inc_act jc_total_exp jc_total_act %12.0fc
compress
save "$onedrive/data/clean_data/program_pop_fund_ccwip_990_jc.dta", replace

*==============================================================================*
*      2. Judicial Council grant lines (Butte/Glenn and Shasta/Tehama split)   *
*==============================================================================*

keep if has_program & year <= 2025
keep program_name year counties n_counties jc_tier_2013 jc_tier jc_multi jc_small jc_n_lines ///
     jc_base jc_augmentation_500k jc_line_base_exp jc_base_exp jc_aug_exp jc_noinc_exp jc_noinc_act jc_noinc_diff ///
     jc_inc_exp jc_inc_act jc_total_exp jc_total_act

* Split Butte/Glenn/Shasta/Tehama into its two grant lines; each gets half of the
* program's actual and expected base, augmentation and expected incentive (the two
* lines get the same base and augmentation); actual incentives are assigned below
gen jc_line = program_name
expand 2 if jc_n_lines == 2, gen(_dup)
replace jc_line = "CASA of Butte and Glenn Counties"   if jc_n_lines == 2 & _dup == 0
replace jc_line = "CASA of Shasta and Tehama Counties" if jc_n_lines == 2 & _dup == 1
foreach v in jc_base jc_augmentation_500k jc_base_exp jc_aug_exp jc_noinc_exp jc_noinc_act jc_noinc_diff jc_inc_exp {
	replace `v' = `v' / 2 if jc_n_lines == 2
}
* Actual incentives went to one line only (Judicial Council tables): Shasta/Tehama in FY 2020-21 and 2023-24, Butte/Glenn in FY 2024-25 and 2025-26, neither in other years
replace jc_inc_act = 0 if jc_n_lines == 2 & _dup == 0 & inlist(year, 2020, 2023)
replace jc_inc_act = 0 if jc_n_lines == 2 & _dup == 1 & inlist(year, 2024, 2025)
assert jc_inc_act == 0 if jc_n_lines == 2 & !inlist(year, 2020, 2023, 2024, 2025)
replace jc_total_exp = jc_noinc_exp + jc_inc_exp if jc_n_lines == 2
replace jc_total_act = jc_noinc_act + jc_inc_act if jc_n_lines == 2
replace counties   = cond(_dup == 0, "Butte, Glenn", "Shasta, Tehama") if jc_n_lines == 2
replace n_counties = 2 if jc_n_lines == 2
drop _dup jc_n_lines

label var jc_line "Judicial Council grant line"
label var jc_small "Small program (2020 population < 300,000)"

* Check: 45 grant lines every year
isid jc_line year
bysort year: gen _n_lines = _N
assert _n_lines == 45
drop _n_lines

order jc_line program_name year counties n_counties jc_tier_2013 jc_tier jc_multi
sort jc_line year
compress
save "$onedrive/data/clean_data/jc_grant_lines.dta", replace

*==============================================================================*
*          Graphs, FY 2018-19 on (current funding rules: 1.15 base increase,   *
*          small vs large incentive pools)                                     *
*==============================================================================*

keep if year >= 2018

*------------------------------------------------------------------------------*
* 3. Expected vs actual baseline (no incentives)
*------------------------------------------------------------------------------*

* Slope and fit (expect slope 1, R-squared 1)
regress jc_noinc_act jc_noinc_exp
local b  : display %5.3f _b[jc_noinc_exp]
local r2 : display %5.3f e(r2)
count
local n = r(N)

twoway (function y = x, range(0 115000) lcolor(gs10) lpattern(dash)) ///
       (scatter jc_noinc_act jc_noinc_exp if year <= 2023, msymbol(O) mcolor(maroon%60)  msize(small)) ///
       (scatter jc_noinc_act jc_noinc_exp if year >= 2024, msymbol(T) mcolor(dkgreen%60) msize(small)), ///
       xtitle("Expected baseline funding (USD)") ///
       ytitle("Actual baseline funding (USD)") ///
       xlabel(0(20000)120000, format(%9.0fc)) ylabel(0(20000)120000, format(%9.0fc) angle(0)) ///
       legend(order(2 "FY 2018-23 (base + 500K augmentation)" 3 "FY 2024-25 (base only)" 1 "45-degree line") cols(1) ring(0) position(11) size(small) region(lcolor(gs12))) ///
       note("Grant lines x fiscal year (N = `n'). Excludes incentives. Slope = `b', R-squared = `r2'.", size(vsmall)) ///
       graphregion(color(white) margin(r+8)) plotregion(color(white)) xsize(7) ysize(5)

graph export "$analysisoutput/figures/jc_expected_vs_actual.png", replace width(2000)

*------------------------------------------------------------------------------*
* 4. Expected vs actual incentives
*------------------------------------------------------------------------------*

* Each line's actual incentive is 0 or the award amount; the expected incentive
* is the average over its pool (small or large). The pool averages (diamonds)
* sit on the 45-degree line by construction; the spread of the dots around them
* is who happened to win.
bysort year jc_small: egen double _mean_inc = mean(jc_inc_act)
bysort year jc_small: gen byte _tag = (_n == 1)
set seed 20261113
gen double _inc_act_j = jc_inc_act + runiform(-400, 400)    // small vertical jitter so stacked points show

twoway (function y = x, range(0 22000) lcolor(gs10) lpattern(dash)) ///
       (scatter _inc_act_j jc_inc_exp if year <= 2023, msymbol(Oh) mcolor(maroon%50)  msize(small)) ///
       (scatter _inc_act_j jc_inc_exp if year >= 2024, msymbol(Oh) mcolor(dkgreen%50) msize(small)) ///
       (scatter _mean_inc  jc_inc_exp if _tag,         msymbol(D)  mcolor(black)       msize(medium)), ///
       xtitle("Expected incentive (USD)") ytitle("Actual incentive (USD)") ///
       xlabel(0(5000)20000, format(%9.0fc)) ylabel(0(5000)25000, format(%9.0fc) angle(0)) ///
       legend(order(2 "FY 2018-23" 3 "FY 2024-25" 4 "Incentive pool average" 1 "45-degree line") cols(1) ring(0) position(11) size(small) region(lcolor(gs12))) ///
       note("Grant lines x fiscal year. Expected = share of pool (small or large) winning x award. Points jittered.", size(vsmall)) ///
       graphregion(color(white) margin(r+8)) plotregion(color(white)) xsize(7) ysize(5)

graph export "$analysisoutput/figures/jc_incentive_expected_vs_actual.png", replace width(2000)
drop _mean_inc _tag _inc_act_j

*------------------------------------------------------------------------------*
* 5. Expected vs actual total funding (baseline + incentives)
*------------------------------------------------------------------------------*

regress jc_total_act jc_total_exp
local b  : display %5.3f _b[jc_total_exp]
local r2 : display %5.3f e(r2)
count
local n = r(N)

twoway (function y = x, range(0 130000) lcolor(gs10) lpattern(dash)) ///
       (scatter jc_total_act jc_total_exp if year <= 2023, msymbol(O) mcolor(maroon%60)  msize(small)) ///
       (scatter jc_total_act jc_total_exp if year >= 2024, msymbol(T) mcolor(dkgreen%60) msize(small)), ///
       xtitle("Expected total funding (USD)") ///
       ytitle("Actual total funding (USD)") ///
       xlabel(0(20000)140000, format(%9.0fc)) ylabel(0(20000)140000, format(%9.0fc) angle(0)) ///
       legend(order(2 "FY 2018-23" 3 "FY 2024-25" 1 "45-degree line") cols(1) ring(0) position(11) size(small) region(lcolor(gs12))) ///
       note("Grant lines x fiscal year (N = `n'). Slope = `b', R-squared = `r2'.", size(vsmall)) ///
       graphregion(color(white) margin(r+8)) plotregion(color(white)) xsize(7) ysize(5)

graph export "$analysisoutput/figures/jc_total_expected_vs_actual.png", replace width(2000)


*==============================================================================*
*      All years, FY 2015-16 on (commented out; to use, delete the            *
*      "keep if year >= 2018" line above and remove the /* and */ below)      *
*==============================================================================*

/*

* 3. Expected vs actual baseline, FY 2015-16 to 2023-24
regress jc_noinc_act jc_noinc_exp if year <= 2023
local b  : display %5.3f _b[jc_noinc_exp]
local r2 : display %5.3f e(r2)
count if year <= 2023
local n = r(N)

twoway (function y = x, range(0 115000) lcolor(gs10) lpattern(dash)) ///
       (scatter jc_noinc_act jc_noinc_exp if year <= 2017, msymbol(Oh) mcolor(navy) msize(medsmall)) ///
       (scatter jc_noinc_act jc_noinc_exp if inrange(year, 2018, 2023), msymbol(O)  mcolor(maroon%60) msize(small)), ///
       xtitle("Expected baseline funding from the tier rule (dollars)") ///
       ytitle("Actual baseline funding (dollars)") ///
       xlabel(0(20000)120000, format(%9.0fc)) ylabel(0(20000)120000, format(%9.0fc) angle(0)) ///
       legend(order(2 "FY 2015-16 to 2017-18" 3 "FY 2018-19 to 2023-24" 1 "45-degree line") rows(1) position(6)) ///
       note("Judicial Council grant lines x fiscal year (N = `n'). Baseline excludes incentives." ///
            "Slope = `b', R-squared = `r2'. Off the line: San Luis Obispo FY 2015-16 (funded at tier 3, 2013 tier 2).") ///
       graphregion(color(white)) plotregion(color(white))

graph export "$analysisoutput/figures/jc_expected_vs_actual_allyears.png", replace width(2000)

* 4. Expected vs actual incentives, FY 2015-16 to 2025-26 (one pool of all programs in 2015-17)
gen byte _grp = cond(year <= 2017, 0, cond(jc_small == 1, 1, 2))
bysort year _grp: egen double _mean_inc = mean(jc_inc_act)
bysort year _grp: gen byte _tag = (_n == 1)
set seed 20261113
gen double _inc_act_j = jc_inc_act + runiform(-400, 400)

twoway (function y = x, range(0 22000) lcolor(gs10) lpattern(dash)) ///
       (scatter _inc_act_j jc_inc_exp if year <= 2017,              msymbol(Oh) mcolor(navy%50)    msize(small)) ///
       (scatter _inc_act_j jc_inc_exp if inrange(year, 2018, 2023), msymbol(Oh) mcolor(maroon%50)  msize(small)) ///
       (scatter _inc_act_j jc_inc_exp if year >= 2024,              msymbol(Oh) mcolor(dkgreen%50) msize(small)) ///
       (scatter _mean_inc  jc_inc_exp if _tag,                      msymbol(D)  mcolor(black)      msize(medium)), ///
       xtitle("Expected incentive (dollars)") ytitle("Actual incentive (dollars)") ///
       xlabel(0(5000)20000, format(%9.0fc)) ylabel(0(5000)25000, format(%9.0fc) angle(0)) ///
       legend(order(2 "FY 2015-17" 3 "FY 2018-23" 4 "FY 2024-25" 5 "Pool average" 1 "45-degree line") rows(2) position(6)) ///
       note("Judicial Council grant lines x fiscal year. Expected = share of the pool that wins x award amount;" ///
            "pools: all programs (2015-17), small vs large programs (2018 on). Points jittered.") ///
       graphregion(color(white)) plotregion(color(white))

graph export "$analysisoutput/figures/jc_incentive_expected_vs_actual_allyears.png", replace width(2000)
drop _grp _mean_inc _tag _inc_act_j

* 5. Expected vs actual total funding, FY 2015-16 to 2025-26
regress jc_total_act jc_total_exp
local b  : display %5.3f _b[jc_total_exp]
local r2 : display %5.3f e(r2)
count
local n = r(N)

twoway (function y = x, range(0 130000) lcolor(gs10) lpattern(dash)) ///
       (scatter jc_total_act jc_total_exp if year <= 2017,              msymbol(Oh) mcolor(navy)       msize(medsmall)) ///
       (scatter jc_total_act jc_total_exp if inrange(year, 2018, 2023), msymbol(O)  mcolor(maroon%60)  msize(small)) ///
       (scatter jc_total_act jc_total_exp if year >= 2024,              msymbol(T)  mcolor(dkgreen%60) msize(small)), ///
       xtitle("Expected funding: baseline + expected incentive (dollars)") ///
       ytitle("Actual funding: baseline + incentives (dollars)") ///
       xlabel(0(20000)140000, format(%9.0fc)) ylabel(0(20000)140000, format(%9.0fc) angle(0)) ///
       legend(order(2 "FY 2015-17" 3 "FY 2018-23" 4 "FY 2024-25" 1 "45-degree line") rows(1) position(6)) ///
       note("Judicial Council grant lines x fiscal year (N = `n'). Slope = `b', R-squared = `r2'." ///
            "Distance from the line = incentive won minus expected incentive (and San Luis Obispo FY 2015-16).") ///
       graphregion(color(white)) plotregion(color(white))

graph export "$analysisoutput/figures/jc_total_expected_vs_actual_allyears.png", replace width(2000)

*/
