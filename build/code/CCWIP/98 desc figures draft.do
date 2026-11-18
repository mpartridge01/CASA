*********************************************************************************
** Purpose: Outcome and funding figures
** Author: Emily
** Date: November 17, 2026
*********************************************************************************
set trace on
set tracedepth 2
* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

use "$onedrive/data/clean_data/instr_reg.dta", clear

* --- Font: Times New Roman for screen and exported files ----
graph set window fontface "Times New Roman"
graph set eps    fontface "Times New Roman"
graph set ps     fontface "Times New Roman"

drop if year < 2016 | year == 2026
*----- Averaging outcome variables ------------------------------------
foreach v in mlos_total place_stability  {
local w in_care        // weight for mlos and place_stability

* Keep one row per program-year, so a program that appears in many
* rows (e.g., one per county) doesn't count more than the others
egen byte _py = tag(program_name year)

gen double _num = `v' * `w' if _py                  // median x weight for each program
gen double _den = `w' if _py & !missing(`v')        // weight, only for programs that report

bysort year: egen double _tnum = total(_num), missing
bysort year: egen double _tden = total(_den), missing

gen double `v'_mu = cond(_tden > 0, _tnum / _tden, .)
label var `v'_mu "Median LOS (avg over programs, weighted by `w')"

drop _py _num _den _tnum _tden

}

local v permanence_12m
local w entries        // weight for mlos and place_stability

* Keep one row per program-year, so a program that appears in many
* rows (e.g., one per county) doesn't count more than the others
egen byte _py = tag(program_name year)

gen double _num = `v' * `w' if _py                  // median x weight for each program
gen double _den = `w' if _py & !missing(`v')        // weight, only for programs that report

bysort year: egen double _tnum = total(_num), missing
bysort year: egen double _tden = total(_den), missing

gen double `v'_mu = cond(_tden > 0, _tnum / _tden, .)
label var `v'_mu "Median LOS (avg over programs, weighted by `w')"

drop _py _num _den _tnum _tden


* Scaling to a base (2016)
local base 2016           
foreach v in mlos_total_mu place_stability_mu permanence_12m_mu {
    summarize `v' if year == `base', meanonly
    gen double idx_`v' = 100 * `v' / r(mean)
}


** Funding averages 
bys year: egen fund_avg = mean(total_fund)
	replace fund_avg = fund_avg/1000
bys year: egen baseline_avg = mean(baseline_sum) 
	replace baseline_avg = baseline_avg / 1000
bys year: egen supp_avg = mean(ca_casa_supplemental)
	replace supp_avg = supp_avg / 1000







* --- Plot ----------------------------------------------------
twoway ///
    (line idx_mlos_total_mu year, lcolor(blue)    lwidth(medthick) lpattern(solid))     ///
    (line idx_place_stability_mu year, lcolor(cranberry)  lwidth(medthick) lpattern(dash))      ///
    (line idx_permanence_12m_mu year, lcolor(dkgreen) lwidth(medthick) lpattern(shortdash)) ///
    , ///
    title("Outcomes over Time", size(large) color(black)) ///
    xtitle("Year", size(medlarge)) ///
    ytitle("Index (`base' = 100)", size(medlarge)) ///
    xlabel(#10, labsize(medium) angle(0) nogrid) ///
    ylabel(, labsize(medium) angle(horizontal) format(%9.0gc) ///
           grid glcolor(gs14) glwidth(thin)) ///
    legend(order(1 "Average Median Length of Stay" 2 "Average Placement Stability" 3 "Average Permanence within 12m") ///
           rows(3) position(6) size(medium) region(lcolor(none))) ///
    graphregion(color(white)) plotregion(color(white)) ///
    xsize(8) ysize(5) ///
    name(fig_timeseries, replace)
	
	** Notes: Each series is expressed relative to its 2019 value.
	graph export "$onedrive/graphs/outcomes_overtime.png", width(2400) replace


twoway ///
    (line fund_avg year, lcolor(blue)    lwidth(medthick) lpattern(solid))     ///
    (line baseline_avg year, lcolor(cranberry)  lwidth(medthick) lpattern(dash))      ///
    (line supp_avg year, lcolor(dkgreen) lwidth(medthick) lpattern(shortdash)) ///
    , ///
    title("Funding over Time", size(large) color(black)) ///
    xtitle("Year", size(medlarge)) ///
    ytitle("USD ($), thousands", size(medlarge)) ///
    xlabel(#10, labsize(medium) angle(0) nogrid) ///
    ylabel(, labsize(medium) angle(horizontal) format(%9.0gc) ///
           grid glcolor(gs14) glwidth(thin)) ///
    legend(order(1 "Average Total Funding" 2 "Average Baseline Funding" 3 "Average Supplemental Funding") ///
           rows(3) position(6) size(medium) region(lcolor(none))) ///
    graphregion(color(white)) plotregion(color(white)) ///
    xsize(8) ysize(5) ///
    name(fig_timeseries, replace)
	
	** Notes: Each series is expressed relative to its 2019 value.
	graph export "$onedrive/graphs/funding_overtime.png", width(2400) replace


graph bar (mean) baseline_avg supp_avg, ///
    over(year, label(labsize(medium) angle(45))) ///
    stack ///
    bar(1, fcolor(navy)    lcolor(white) lwidth(vthin)) ///
    bar(2, fcolor(cranberry)  lcolor(white) lwidth(vthin)) ///
    title("Funding over Time", size(large) color(black)) ///
    b1title("Year", size(medlarge)) ///
    ytitle("USD ($), thousands", size(medlarge)) ///
    ylabel(, labsize(medium) angle(horizontal) format(%9.0gc) ///
           grid glcolor(gs14) glwidth(thin)) ///
    legend(order(1 "Average Baseline Funding" 2 "Average Supplemental Funding") ///
           rows(3) position(6) size(medium) region(lcolor(none))) ///
    graphregion(color(white)) plotregion(color(white)) ///
    xsize(8) ysize(5) ///
    name(fig_stacked, replace)

graph export "$onedrive/graphs/funding_stacked.png", width(2400) replace