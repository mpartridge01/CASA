*********************************************************************************
** Purpose: Descriptive Statistics - formula reverse engineering.
** Author: Emily
** Date: November 9, 2026
*********************************************************************************

use  "$onedrive/data/clean_data/program_pop_fund_ccwip.dta", clear 

destring year, replace 

tw scatter mlos_total_prog ca_casa_supplemental ||lfit mlos_total_prog ca_casa_supplemental if year >= 2022 & year <= 2024 

tw scatter  ca_casa_supplemental mlos_total_prog ||lfit  ca_casa_supplemental mlos_total_prog if year == 2022

tw scatter  ca_casa_supplemental mlos_total_prog ||lfit  ca_casa_supplemental mlos_total_prog if year == 2023

tw scatter  ca_casa_supplemental mlos_total_prog ||lfit  ca_casa_supplemental mlos_total_prog if year == 2024

tw scatter  jc_base  mlos_total_prog ||lfit jc_base mlos_total_prog if year == 2019


gen log_pop = ln(Pop) 
tw scatter mlos_total_prog log_pop ||lfit  mlos_total_prog log_pop

gen log_supp = ln(ca_casa_supplemental)
tw scatter log_pop log_supp || lfit log_pop log_supp

tw scatter log_pop log_supp || lfit log_pop log_supp if year == 2022
tw scatter log_pop log_supp || lfit log_pop log_supp if year == 2023
tw scatter log_pop log_supp || lfit log_pop log_supp if year == 2024

gen log_base = ln(jc_base) 
tw scatter log_pop log_base || lfit log_pop log_base 