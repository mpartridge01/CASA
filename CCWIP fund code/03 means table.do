********************************************************************************
** Purpose: Create table of means
** Date: 10/13/2026
** Author: Emily Marsh
********************************************************************************

global onedrive "C:\Users\emi\OneDrive - UC San Diego\Research\CASA\" 

*******************************************************************************
** Table of means 
*******************************************************************************


use "$onedrive\data\clean_data\funding_ccwip.dta", clear

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



******************************************************************************
********** Creating the table ***********
******************************************************************************


local vars    "baseline_pc supp_pc tot_fund_pc mlos_total reentry2"   // variables to summarize
local outfile "$onedrive/tables/summary_stats.tex"                 // output file
local title   "Summary Statistics"                // table title
local tablabel "tab:sumstats"                     // LaTeX \label{}
local dec     2                                   // decimal places


label var baseline_pc "Baseline funding per child"
label var supp_pc "Supplemental funding per child"
label var tot_fund_pc "Total funding per child"
label var mlos_total "Median length of stay (days)"
label var reentry2 "Re-entrance by cohort (percent)"


** Table **
estpost summarize `vars'

esttab using "`outfile'", replace                                         ///
    cells("mean(fmt(`dec')) sd(fmt(`dec')) count(fmt(%9.0fc)) min(fmt(`dec')) max(fmt(`dec'))") ///
    collabels("Mean" "Std. Dev." "N" "Min" "Max")                         ///
    label nomtitle nonumber noobs                                         ///
    booktabs                                              ///
	 prehead("\begin{table}[htbp]\centering" "\begin{threeparttable}" "\caption{`Means Table'}\label{`tablabel'}" "\begin{tabular}{lrrrrr}" "\toprule") ///
	     postfoot("\bottomrule" "\end{tabular}" "\begin{tablenotes}[flushleft]\footnotesize" "\item Notes: Foster care data from California Child Welfare Indicators Project, managed by University of California at Berkeley and the California Department of Social Services. Supplemental funding data scraped from Judicial Council Reports required under the California Budget Act of 2022. Baseline funding data scraped from the Family and Juvenile Law Advisory Committee reports to the Judicial Council. The unit of observation is at the county x year level. Baseline funding is between Fiscal Year (FY) 2015-2016 through FY 2025-2026. Supplemental funding is between FY 2022-2023 and FY 2024-2025. Per child refers to per child in foster care."  "\end{tablenotes}" "\end{threeparttable}" "\end{table}")

	

* Show the same table in the Results window as a check
esttab, cells("mean(fmt(`dec')) sd(fmt(`dec')) count(fmt(%9.0fc)) min(fmt(`dec')) max(fmt(`dec'))") ///
    collabels("Mean" "Std. Dev." "N" "Min" "Max")                         ///
    label nomtitle nonumber noobs









