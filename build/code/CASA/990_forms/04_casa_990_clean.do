*==============================================================================*
*                          casa_990_04_import.do                               *
*==============================================================================*

* Notes:
* 1. Imports the CASA Form 990 panel built by casa_990_02_parse.R, sets variable
*    types, labels every variable, builds summary revenue, expense and CASA
*    spending variables, keeps those, and saves a .dta.
*      In:  $cleandata/CASA/990_forms/casa_990_panel.csv
*      Out: $cleandata/CASA/990_forms/casa_990_panel.dta
* 2. One row per filing nonprofit (EIN) x California state fiscal year.
*    See clean_data/CASA/990_forms/README.md and casa_990_codebook.csv.
* 3. Everything is read as text first and then converted, so that EINs keep
*    their leading zeros (e.g. San Mateo = 043849393) and the 18-digit
*    object_id is not rounded.
* 4. Dollar amounts are nominal, as reported on the return.


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

import delimited "$cleandata/CASA/990_forms/casa_990_panel.csv", ///
    clear varnames(1) stringcols(_all) bindquote(strict) maxquotedrows(unlimited) ///
    encoding("utf-8")

* Convert everything except the text variables to numbers
ds programs counties tier ein org_name fy tax_prd form source object_id schema_version tax_prd_begin tax_prd_end casa_line notes, not
destring `r(varlist)', replace

* Dates
foreach v in tax_prd_begin tax_prd_end {
    gen `v'_d = date(`v', "YMD")
    format `v'_d %td
    order `v'_d, after(`v')
    drop `v'
    rename `v'_d `v'
}

* Checks: tax period dates present and consistent with tax_prd
assert !missing(tax_prd_begin, tax_prd_end)
assert string(year(tax_prd_end)) + string(month(tax_prd_end), "%02.0f") == tax_prd
assert tax_prd_end > tax_prd_begin

* Checks: identifiers
assert strlen(ein) == 9
assert strlen(tax_prd) == 6
isid ein tax_prd
isid ein fy_start

*==============================================================================*
*                             Variable labels                                  *
*==============================================================================*

label variable programs                   `"CASA program(s) run by this EIN"'
label variable counties                   `"Counties served"'
label variable tier                       `"Tier: A CASA only, B CASA+other, C multi-service, D Friends grp"'
label variable ein                        `"EIN of filing nonprofit (9-digit string)"'
label variable org_name                   `"Organization name on return"'
label variable fy                         `"CA state FY (Jul-Jun) in which org FY ends"'
label variable fy_start                   `"CA state FY, start year"'
label variable fy_end                     `"CA state FY, end year"'
label variable tax_prd                    `"Month org fiscal year ended (YYYYMM)"'
label variable form                       `"Form type: 990 or 990EZ"'
label variable source                     `"Data source: xml or pdf_manual"'
label variable amended                    `"Amended return"'
label variable n_versions                 `"No. of filings for EIN x tax period (latest kept)"'
label variable object_id                  `"IRS e-file object ID (XML only)"'
label variable schema_version             `"IRS XML schema version"'
label variable parse_fail                 `"XML could not be parsed"'
label variable chk_flag                   `"Components do not add to totals"'
label variable tax_prd_begin              `"Tax period begin date"'
label variable tax_prd_end                `"Tax period end date"'
label variable emp_count                  `"Employees (Part I line 5)"'
label variable vol_count                  `"Volunteers, estimate (Part I line 6)"'
label variable rev_invest_p1              `"Investment income (Part I line 10 = VIII 3, 4, 7d)"'
label variable rev_total_p1               `"Total revenue, current year (Part I line 12)"'
label variable exp_total_p1               `"Total expenses, current year (Part I line 18)"'
label variable py_rev_total               `"Total revenue, prior year column (Part I line 12)"'
label variable py_exp_total               `"Total expenses, prior year column (Part I line 18)"'
label variable rev_federated              `"Federated campaigns (VIII 1a)"'
label variable rev_membership             `"Membership dues (VIII 1b; EZ line 3)"'
label variable rev_fundraising_events     `"Contributions from fundraising events (VIII 1c)"'
label variable rev_related_orgs           `"Contributions from related orgs (VIII 1d)"'
label variable rev_govt_grants            `"Government grants (VIII 1e)"'
label variable rev_other_contrib          `"All other contributions (VIII 1f)"'
label variable rev_noncash                `"Noncash contributions, memo (VIII 1g)"'
label variable rev_contrib_total          `"Total contributions (VIII 1h; EZ line 1)"'
label variable rev_program_service        `"Program service revenue (VIII 2g; EZ line 2)"'
label variable rev_investment             `"Investment income (VIII 3; EZ line 4)"'
label variable rev_events_gross           `"Fundraising events gross income (VIII 8a)"'
label variable rev_events_direct_exp      `"Fundraising events direct expenses (VIII 8b)"'
label variable rev_events_net             `"Fundraising events net income (VIII 8c; EZ line 6d)"'
label variable rev_other                  `"Other revenue (Part I line 11; EZ lines 5c+6d+7c+8)"'
label variable rev_total                  `"Total revenue (VIII 12; EZ line 9)"'
label variable prog_exp_total             `"Total program service expenses (Part III line 4e; EZ Part III)"'
label variable assets_boy                 `"Total assets, beginning of year (X 16; EZ 25)"'
label variable assets_eoy                 `"Total assets, end of year (X 16; EZ 25)"'
label variable liab_boy                   `"Total liabilities, beginning of year (X 26; EZ 26)"'
label variable liab_eoy                   `"Total liabilities, end of year (X 26; EZ 26)"'
label variable net_assets_boy             `"Net assets, beginning of year (X 33; EZ 27)"'
label variable net_assets_eoy             `"Net assets, end of year (X 33; EZ 27)"'
label variable exp_grants_orgs_tot        `"Grants to domestic orgs & govts (IX 1): total"'
label variable exp_grants_orgs_prog       `"Grants to domestic orgs & govts (IX 1): program svcs"'
label variable exp_grants_orgs_mgmt       `"Grants to domestic orgs & govts (IX 1): mgmt & general"'
label variable exp_grants_orgs_fund       `"Grants to domestic orgs & govts (IX 1): fundraising"'
label variable exp_grants_indiv_tot       `"Grants to domestic individuals (IX 2): total"'
label variable exp_grants_indiv_prog      `"Grants to domestic individuals (IX 2): program svcs"'
label variable exp_grants_indiv_mgmt      `"Grants to domestic individuals (IX 2): mgmt & general"'
label variable exp_grants_indiv_fund      `"Grants to domestic individuals (IX 2): fundraising"'
capture label variable exp_grants_foreign_tot     `"Grants to foreign orgs & individuals (IX 3): total"'
capture label variable exp_grants_foreign_prog    `"Grants to foreign orgs & individuals (IX 3): program svcs"'
capture label variable exp_grants_foreign_mgmt    `"Grants to foreign orgs & individuals (IX 3): mgmt & general"'
capture label variable exp_grants_foreign_fund    `"Grants to foreign orgs & individuals (IX 3): fundraising"'
label variable exp_member_benefits_tot    `"Benefits paid to members (IX 4): total"'
label variable exp_member_benefits_prog   `"Benefits paid to members (IX 4): program svcs"'
label variable exp_member_benefits_mgmt   `"Benefits paid to members (IX 4): mgmt & general"'
label variable exp_member_benefits_fund   `"Benefits paid to members (IX 4): fundraising"'
label variable exp_officer_comp_tot       `"Comp. of officers, directors, key employees (IX 5): total"'
label variable exp_officer_comp_prog      `"Comp. of officers, directors, key employees (IX 5): program svcs"'
label variable exp_officer_comp_mgmt      `"Comp. of officers, directors, key employees (IX 5): mgmt & general"'
label variable exp_officer_comp_fund      `"Comp. of officers, directors, key employees (IX 5): fundraising"'
label variable exp_disq_comp_tot          `"Comp. of disqualified persons (IX 6): total"'
label variable exp_disq_comp_prog         `"Comp. of disqualified persons (IX 6): program svcs"'
label variable exp_disq_comp_mgmt         `"Comp. of disqualified persons (IX 6): mgmt & general"'
label variable exp_disq_comp_fund         `"Comp. of disqualified persons (IX 6): fundraising"'
label variable exp_salaries_tot           `"Other salaries and wages (IX 7): total"'
label variable exp_salaries_prog          `"Other salaries and wages (IX 7): program svcs"'
label variable exp_salaries_mgmt          `"Other salaries and wages (IX 7): mgmt & general"'
label variable exp_salaries_fund          `"Other salaries and wages (IX 7): fundraising"'
label variable exp_pension_tot            `"Pension plan contributions (IX 8): total"'
label variable exp_pension_prog           `"Pension plan contributions (IX 8): program svcs"'
label variable exp_pension_mgmt           `"Pension plan contributions (IX 8): mgmt & general"'
label variable exp_pension_fund           `"Pension plan contributions (IX 8): fundraising"'
label variable exp_benefits_tot           `"Other employee benefits (IX 9): total"'
label variable exp_benefits_prog          `"Other employee benefits (IX 9): program svcs"'
label variable exp_benefits_mgmt          `"Other employee benefits (IX 9): mgmt & general"'
label variable exp_benefits_fund          `"Other employee benefits (IX 9): fundraising"'
label variable exp_payroll_tax_tot        `"Payroll taxes (IX 10): total"'
label variable exp_payroll_tax_prog       `"Payroll taxes (IX 10): program svcs"'
label variable exp_payroll_tax_mgmt       `"Payroll taxes (IX 10): mgmt & general"'
label variable exp_payroll_tax_fund       `"Payroll taxes (IX 10): fundraising"'
label variable exp_fees_mgmt_tot          `"Fees: management (IX 11a): total"'
label variable exp_fees_mgmt_prog         `"Fees: management (IX 11a): program svcs"'
label variable exp_fees_mgmt_mgmt         `"Fees: management (IX 11a): mgmt & general"'
label variable exp_fees_mgmt_fund         `"Fees: management (IX 11a): fundraising"'
label variable exp_fees_legal_tot         `"Fees: legal (IX 11b): total"'
label variable exp_fees_legal_prog        `"Fees: legal (IX 11b): program svcs"'
label variable exp_fees_legal_mgmt        `"Fees: legal (IX 11b): mgmt & general"'
label variable exp_fees_legal_fund        `"Fees: legal (IX 11b): fundraising"'
label variable exp_fees_acct_tot          `"Fees: accounting (IX 11c): total"'
label variable exp_fees_acct_prog         `"Fees: accounting (IX 11c): program svcs"'
label variable exp_fees_acct_mgmt         `"Fees: accounting (IX 11c): mgmt & general"'
label variable exp_fees_acct_fund         `"Fees: accounting (IX 11c): fundraising"'
label variable exp_fees_lobby_tot         `"Fees: lobbying (IX 11d): total"'
label variable exp_fees_lobby_prog        `"Fees: lobbying (IX 11d): program svcs"'
label variable exp_fees_lobby_mgmt        `"Fees: lobbying (IX 11d): mgmt & general"'
label variable exp_fees_lobby_fund        `"Fees: lobbying (IX 11d): fundraising"'
label variable exp_fees_prof_fr_tot       `"Fees: professional fundraising (IX 11e): total"'
label variable exp_fees_prof_fr_prog      `"Fees: professional fundraising (IX 11e): program svcs"'
label variable exp_fees_prof_fr_mgmt      `"Fees: professional fundraising (IX 11e): mgmt & general"'
label variable exp_fees_prof_fr_fund      `"Fees: professional fundraising (IX 11e): fundraising"'
label variable exp_fees_invest_tot        `"Fees: investment management (IX 11f): total"'
label variable exp_fees_invest_prog       `"Fees: investment management (IX 11f): program svcs"'
label variable exp_fees_invest_mgmt       `"Fees: investment management (IX 11f): mgmt & general"'
label variable exp_fees_invest_fund       `"Fees: investment management (IX 11f): fundraising"'
label variable exp_fees_other_tot         `"Fees: other (IX 11g): total"'
label variable exp_fees_other_prog        `"Fees: other (IX 11g): program svcs"'
label variable exp_fees_other_mgmt        `"Fees: other (IX 11g): mgmt & general"'
label variable exp_fees_other_fund        `"Fees: other (IX 11g): fundraising"'
label variable exp_advertising_tot        `"Advertising and promotion (IX 12): total"'
label variable exp_advertising_prog       `"Advertising and promotion (IX 12): program svcs"'
label variable exp_advertising_mgmt       `"Advertising and promotion (IX 12): mgmt & general"'
label variable exp_advertising_fund       `"Advertising and promotion (IX 12): fundraising"'
label variable exp_office_tot             `"Office expenses (IX 13): total"'
label variable exp_office_prog            `"Office expenses (IX 13): program svcs"'
label variable exp_office_mgmt            `"Office expenses (IX 13): mgmt & general"'
label variable exp_office_fund            `"Office expenses (IX 13): fundraising"'
label variable exp_it_tot                 `"Information technology (IX 14): total"'
label variable exp_it_prog                `"Information technology (IX 14): program svcs"'
label variable exp_it_mgmt                `"Information technology (IX 14): mgmt & general"'
label variable exp_it_fund                `"Information technology (IX 14): fundraising"'
label variable exp_royalties_tot          `"Royalties (IX 15): total"'
label variable exp_royalties_prog         `"Royalties (IX 15): program svcs"'
label variable exp_royalties_mgmt         `"Royalties (IX 15): mgmt & general"'
label variable exp_royalties_fund         `"Royalties (IX 15): fundraising"'
label variable exp_occupancy_tot          `"Occupancy (IX 16; EZ 14): total"'
label variable exp_occupancy_prog         `"Occupancy (IX 16): program svcs"'
label variable exp_occupancy_mgmt         `"Occupancy (IX 16): mgmt & general"'
label variable exp_occupancy_fund         `"Occupancy (IX 16): fundraising"'
label variable exp_travel_tot             `"Travel (IX 17): total"'
label variable exp_travel_prog            `"Travel (IX 17): program svcs"'
label variable exp_travel_mgmt            `"Travel (IX 17): mgmt & general"'
label variable exp_travel_fund            `"Travel (IX 17): fundraising"'
label variable exp_travel_officials_tot   `"Travel/entertainment of public officials (IX 18): total"'
label variable exp_travel_officials_prog  `"Travel/entertainment of public officials (IX 18): program svcs"'
label variable exp_travel_officials_mgmt  `"Travel/entertainment of public officials (IX 18): mgmt & general"'
label variable exp_travel_officials_fund  `"Travel/entertainment of public officials (IX 18): fundraising"'
label variable exp_conferences_tot        `"Conferences and meetings (IX 19): total"'
label variable exp_conferences_prog       `"Conferences and meetings (IX 19): program svcs"'
label variable exp_conferences_mgmt       `"Conferences and meetings (IX 19): mgmt & general"'
label variable exp_conferences_fund       `"Conferences and meetings (IX 19): fundraising"'
label variable exp_interest_tot           `"Interest (IX 20): total"'
label variable exp_interest_prog          `"Interest (IX 20): program svcs"'
label variable exp_interest_mgmt          `"Interest (IX 20): mgmt & general"'
label variable exp_interest_fund          `"Interest (IX 20): fundraising"'
label variable exp_affiliates_tot         `"Payments to affiliates (IX 21): total"'
label variable exp_affiliates_prog        `"Payments to affiliates (IX 21): program svcs"'
label variable exp_affiliates_mgmt        `"Payments to affiliates (IX 21): mgmt & general"'
label variable exp_affiliates_fund        `"Payments to affiliates (IX 21): fundraising"'
label variable exp_depreciation_tot       `"Depreciation and amortization (IX 22): total"'
label variable exp_depreciation_prog      `"Depreciation and amortization (IX 22): program svcs"'
label variable exp_depreciation_mgmt      `"Depreciation and amortization (IX 22): mgmt & general"'
label variable exp_depreciation_fund      `"Depreciation and amortization (IX 22): fundraising"'
label variable exp_insurance_tot          `"Insurance (IX 23): total"'
label variable exp_insurance_prog         `"Insurance (IX 23): program svcs"'
label variable exp_insurance_mgmt         `"Insurance (IX 23): mgmt & general"'
label variable exp_insurance_fund         `"Insurance (IX 23): fundraising"'
label variable exp_all_other_tot          `"All other expenses (IX 24e): total"'
label variable exp_all_other_prog         `"All other expenses (IX 24e): program svcs"'
label variable exp_all_other_mgmt         `"All other expenses (IX 24e): mgmt & general"'
label variable exp_all_other_fund         `"All other expenses (IX 24e): fundraising"'
label variable exp_other_itemized_tot     `"Itemized other expenses (IX 24a-d): total"'
label variable exp_other_itemized_prog    `"Itemized other expenses (IX 24a-d): program svcs"'
label variable exp_other_itemized_mgmt    `"Itemized other expenses (IX 24a-d): mgmt & general"'
label variable exp_other_itemized_fund    `"Itemized other expenses (IX 24a-d): fundraising"'
label variable exp_total_tot              `"Total expenses (IX 25 col A; EZ 17)"'
label variable exp_total_prog             `"Total expenses: program svcs (IX 25 col B)"'
label variable exp_total_mgmt             `"Total expenses: mgmt & general (IX 25 col C)"'
label variable exp_total_fund             `"Total expenses: fundraising (IX 25 col D)"'
label variable exp_grants_ez              `"Grants paid (EZ line 10)"'
label variable exp_member_ben_ez          `"Benefits paid to members (EZ line 11)"'
label variable exp_personnel_tot          `"Personnel: IX lines 5-10 (EZ line 12)"'
label variable exp_contractors_ez         `"Professional fees, independent contractors (EZ line 13)"'
label variable exp_printing_ez            `"Printing, publications, postage (EZ line 15)"'
label variable exp_other_ez               `"Other expenses (EZ line 16)"'
label variable casa_line                  `"Part III line describing CASA"'
label variable casa_exp                   `"Expenses on Part III line describing CASA"'
label variable casa_line_is_other         `"CASA line is Part III line 4d (Other program services)"'
label variable casa_line_only             `"CASA line covers only CASA (0 = CASA + other programs)"'
label variable casa_exp_only              `"CASA-only program expenses (casa_exp if casa_line_only == 1)"'
label variable notes                      `"Notes from hand entry (PDF rows)"'
label variable chk_contrib_diff           `"Check: VIII 1a-1f minus 1h"'
label variable chk_exp_diff               `"Check: IX components minus IX 25"'

*==============================================================================*
*                               Value labels                                   *
*==============================================================================*

label define yesno 0 "No" 1 "Yes"
label values amended parse_fail chk_flag casa_line_is_other casa_line_only yesno

* Tier as a labeled numeric copy (tier itself stays A-D until the end)
gen byte tier_num = .
replace tier_num = 1 if tier == "A"
replace tier_num = 2 if tier == "B"
replace tier_num = 3 if tier == "C"
replace tier_num = 4 if tier == "D"
label define tier_lbl 1 "A: org is the CASA program" 2 "B: CASA + other programs" ///
                      3 "C: multi-service parent org" 4 "D: Friends-of fundraising group"
label values tier_num tier_lbl
label variable tier_num "Tier (numeric)"
order tier_num, after(tier)
assert !missing(tier_num)

*==============================================================================*
*                     Volunteers and employees                                 *
*==============================================================================*

* set volunteer count to missing if it is at 0. This does not make sense and would imply there are no CASA services when they have high revenues (happens 17 times)
replace vol_count = . if vol_count == 0

* commented out line below. There is reason to belive that you could have 0 employees or the organization is structured in such a way that employees show up somewhere outside of the nonprofit. Alameda county, for example, is structured as more of a public org with the nonprofit attached, which could explain that. 
* replace emp_count = . if emp_count == 0

*==============================================================================*
*                  Summary revenue and expense variables                       *
*==============================================================================*

* Revenue, full 990: rev_gov + rev_fundraising + rev_prog_svc + rev_invest + rev_oth = rev_total
*   rev_gov:         government grants
*   rev_fundraising: private donations + net income from fundraising events
*   rev_prog_svc:    money paid for services (e.g. county or court contracts, fees)
* The 990-EZ has one contributions line (government and private together), so
* rev_gov and rev_fundraising are missing on EZ rows.
* Expenses: exp_salaries + exp_grants + exp_oth = exp_total
*           exp_prog + exp_mgmt + exp_fund = exp_total (full 990 only)

* Blank lines are 0 on the form, so missing pieces are set to 0 before adding.
* A line no organization ever reports (e.g. foreign grants) may not be in the
* CSV at all; create it as 0 so the sums below still work.
foreach v in rev_events_net rev_membership rev_investment rev_invest_p1 rev_other ///
             rev_govt_grants rev_contrib_total rev_program_service ///
             exp_grants_orgs_tot exp_grants_indiv_tot exp_grants_foreign_tot exp_grants_ez {
    capture confirm variable `v'
    if _rc gen `v' = 0
    replace `v' = 0 if missing(`v')
}

* Drop variables from an earlier partial run of this section (only matters
* when rerunning a highlighted part of the file)
capture drop rev_gov rev_fundraising rev_prog_svc rev_invest rev_oth ///
             exp_total exp_salaries exp_grants exp_oth exp_prog exp_mgmt exp_fund ///
             casa_type casa_spend
capture label drop casa_type_lbl

* Revenue
gen rev_gov         = rev_govt_grants                                      if form == "990"
gen rev_fundraising = rev_contrib_total - rev_govt_grants + rev_events_net if form == "990"
gen rev_prog_svc    = rev_program_service
gen rev_invest      = cond(form == "990", rev_invest_p1, rev_investment)
gen rev_oth         = cond(form == "990", rev_other - rev_events_net, ///
                                          rev_other - rev_events_net + rev_membership)

* Expenses by type
gen exp_total    = exp_total_tot
gen exp_salaries = exp_personnel_tot
gen exp_grants   = cond(form == "990", ///
                        exp_grants_orgs_tot + exp_grants_indiv_tot + exp_grants_foreign_tot, ///
                        exp_grants_ez)
gen exp_oth      = exp_total - exp_salaries - exp_grants

* Expenses by function (990-EZ has no split; its program total is from Part III)
gen exp_prog = cond(form == "990", exp_total_prog, prog_exp_total)
gen exp_mgmt = exp_total_mgmt if form == "990"
gen exp_fund = exp_total_fund if form == "990"

* Checks: the pieces add to the totals (within $1)
assert abs(rev_gov + rev_fundraising + rev_prog_svc + rev_invest + rev_oth - rev_total) <= 1 if form == "990"
assert abs(rev_contrib_total + rev_events_net + rev_prog_svc + rev_invest + rev_oth - rev_total) <= 1
assert abs(exp_prog + exp_mgmt + exp_fund - exp_total) <= 1 if form == "990"
assert !missing(rev_total, rev_prog_svc, rev_invest, rev_oth, exp_total, exp_salaries, exp_grants, exp_oth)

*==============================================================================*
*                           CASA spending                                      *
*==============================================================================*

* The 990 has no program-level revenue, so this is CASA spending.
* casa_type:
*   1 whole organization is CASA (tier A)             -> total expenses
*   2 CASA has its own Part III line                  -> that line
*   3 CASA shares a Part III line with other programs -> that line
*   4 CASA spending unknown (no CASA line, or tier D) -> total expenses
* casa_spend is never above total expenses.

* Stop if a tier B/C CASA line was never hand-coded (see casa_990_casa_line_review.csv)
assert !(inlist(tier, "B", "C") & !missing(casa_line) & missing(casa_line_only))

gen byte casa_type = 4
replace casa_type = 1 if tier == "A"
replace casa_type = 2 if inlist(tier, "B", "C") & casa_line_only == 1 & !missing(casa_exp)
replace casa_type = 3 if inlist(tier, "B", "C") & casa_line_only == 0 & !missing(casa_exp)

label define casa_type_lbl 1 "Whole org is CASA" 2 "CASA-only line" ///
                           3 "CASA + other programs" 4 "CASA unknown (org total)"
label values casa_type casa_type_lbl

gen casa_spend = cond(inlist(casa_type, 2, 3), casa_exp, exp_total)

* Cap at total expenses (shows how many were capped)
count if casa_spend > exp_total
replace casa_spend = exp_total if casa_spend > exp_total

label variable rev_gov         "Government grants (VIII 1e); missing on 990-EZ"
label variable rev_fundraising "Private donations + net fundraising events (VIII 1h-1e + 8c); missing on 990-EZ"
label variable rev_prog_svc    "Program service revenue: contracts, fees (VIII 2g; EZ 2)"
label variable rev_invest      "Investment income incl. securities gains (Part I 10; EZ 4)"
label variable rev_oth         "All other revenue"
label variable exp_total       "Total expenses (IX 25; EZ 17)"
label variable exp_salaries    "Personnel: salaries, comp, benefits, pension, payroll tax (IX 5-10; EZ 12)"
label variable exp_grants      "Grants paid to orgs and individuals (IX 1-3; EZ 10)"
label variable exp_oth         "All other expenses (total - personnel - grants)"
label variable exp_prog        "Program service expenses (IX 25 col B; EZ Part III)"
label variable exp_mgmt        "Management and general expenses (IX 25 col C); missing on 990-EZ"
label variable exp_fund        "Fundraising expenses (IX 25 col D); missing on 990-EZ"
label variable casa_type       "How casa_spend is measured"
label variable casa_spend      "CASA spending (see casa_type); never above exp_total"

*==============================================================================*
*                                  Keep                                        *
*==============================================================================*

keep  programs counties tier_num ein org_name fy_start fy_end tax_prd_begin tax_prd_end form ///
      emp_count vol_count ///
      rev_total rev_gov rev_fundraising rev_prog_svc rev_invest rev_oth ///
      exp_total exp_salaries exp_grants exp_oth exp_prog exp_mgmt exp_fund ///
      casa_spend casa_type
order programs counties tier_num ein org_name fy_start fy_end tax_prd_begin tax_prd_end form ///
      emp_count vol_count ///
      rev_total rev_gov rev_fundraising rev_prog_svc rev_invest rev_oth ///
      exp_total exp_salaries exp_grants exp_oth exp_prog exp_mgmt exp_fund ///
      casa_spend casa_type

rename tier_num tier

*==============================================================================*
*                          Formats, notes, save                                *
*==============================================================================*

format rev_* exp_* casa_spend %15.0fc

sort ein fy_start
compress
save "$cleandata/CASA/990_forms/casa_990_panel.dta", replace
