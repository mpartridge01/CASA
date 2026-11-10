********************************************************************************
** Purpose: Create table of means
** Date: 10/13/2026
** Author: Emily Marsh
********************************************************************************

********************************************************************************
*                              Run globals script                              *
********************************************************************************

* Clear environment
clear all
macro drop _all

* Find and run build/code/SetGlobals.do (runglobals.ado in PERSONAL ado folder)
runglobals

********************************************************************************
** Import data 
*******************************************************************************


use "$onedrive/data/clean_data/funding_ccwip.dta", clear



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









