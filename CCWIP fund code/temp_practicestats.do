use "C:\Users\emi\OneDrive - UC San Diego\Research\CASA\data\clean_data\funding_ccwip.dta", clear

foreach fund in jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b {
	replace `fund' = 0 if mi(`fund') 
}

** Want supplement to be 0 in counties that dont have a casa program in 2022, 2023, 2024 but missing in all counties in other years. 
replace ca_casa_supplemental = 0 if mi(ca_casa_supplemental) & inlist(year, "2022", "2023", "2024")

****** Create funding per child in care ********
destring year, replace 

foreach var in in_care stability reentry2  {
	replace `var' = "" if `var' == "M"
	destring `var', replace 
}


** All baseline funding (outside of supplement) 
egen baseline_sum = rowtotal(jc_base jc_incentive_volunteer_retention jc_incentive_dependency_served jc_augmentation_500k jc_growth_incentive jc_growth_incentive_a jc_growth_incentive_b) 

** Total funding (baseline + supplement)
egen total_fund = rowtotal(baseline_sum ca_casa_supplemental) 


** Create baseline funding/child, total funding/child, supplement/child (where child is a child in foster care)
** The in-care variable is a point in time variable (instead of calculated over the course of the year) but I set the point as July (which corresponds to the beginning of the CA fiscal year). One thing to look into is when the actual disbursement happened. 
gen baseline_pc = baseline_sum/in_care 
gen tot_fund_pc = total_fund/in_care
gen supp_pc = ca_casa_supplemental/in_care 


hist baseline_pc
hist tot_fund_pc
hist supp_pc

tw scatter supp_pc baseline_pc if baseline_pc !=0 & year == 2022
tw scatter supp_pc baseline_pc if baseline_pc !=0 & year == 2023
tw scatter supp_pc baseline_pc if baseline_pc !=0 & year == 2024


twoway (scatter supp_pc baseline_pc if year == 2022,              ///
            mlabel(county)                   ///  variable holding geographic names
            mlabsize(vsmall)                       ///  label text size
            mlabposition(3)                        ///  label to the right of each point (clock position)
            mlabcolor(gs6)                         ///
            msymbol(circle) msize(small)           ///
            mcolor(navy%70)),                      ///
       xtitle("Baseline (per capita)")             ///
       ytitle("Supplemental (per capita)")         ///
       title("2022")                         ///
       legend(off)                                 ///
       graphregion(color(white))

	   graph export "C:\Users\emi\OneDrive - UC San Diego\Research\CASA\graphs/2022_pc.png", replace width(2000)

sort baseline_pc 
gr bar (asis) baseline_pc supp_pc if year == 2021, over(county, label(angle(45) labsize(vsmall))) stack
  graph export "C:\Users\emi\OneDrive - UC San Diego\Research\CASA\graphs/2021_bar_pc.png", replace width(2000)


gr bar (asis) baseline_pc supp_pc  if year == 2022, over(county, label(angle(45) labsize(vsmall))) stack
  graph export "C:\Users\emi\OneDrive - UC San Diego\Research\CASA\graphs/2022_bar_pc.png", replace width(2000)
  
  
  
 twoway (scatter in_care population_total if year == 2022,              ///
            mlabel(county)                   ///  variable holding geographic names
            mlabsize(vsmall)                       ///  label text size
            mlabposition(3)                        ///  label to the right of each point (clock position)
            mlabcolor(gs6)                         ///
            msymbol(circle) msize(small)           ///
            mcolor(navy%70))				///
			(lfit in_care population_total) ,                      ///
       xtitle("In care x population")             ///
       title("2022")                         ///
       legend(off)                                 ///
       graphregion(color(white))

sort year
tw (line baseline_sum year if county == "Orange") (line ca_casa_supplement year if county == "Orange")