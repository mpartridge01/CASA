#==============================================================================#
#                           casa_990_03_check.R                                #
#==============================================================================#

# Notes:
# 1. Run after casa_990_02_parse.R. Reads the panel and checks it; changes no
#    data. Same checks for XML and hand-entered PDF rows.
# 2. Writes to cleandata/CASA/990_forms/:
#      casa_990_coverage.csv      program x FY grid: where each year's data came from
#      casa_990_check_report.csv  one row per problem found
# 3. Coverage status for each program x FY:
#      xml / pdf_manual   data in the panel
#      MISSING            a return is listed on ProPublica but is not in the panel
#      gap                no return listed, but there are returns before and after
#      before_first       before the org's first listed return (not formed / not filing yet)
#      not_yet            after the org's latest listed return (not filed or not published yet)
# 4. Checks (diff = left side minus right side; flagged when |diff| > tol):
#    Within each return (severity "error"):
#      contrib_sum     VIII 1a-1f = 1h
#      rev_sum         Part I lines 8-11 = total revenue (990); EZ lines 1-8 = line 9
#      rev_p1_vs_viii  Part I line 12 = VIII line 12
#      events_net      VIII 8a - 8b = 8c
#      exp_sum         IX lines 1-24 = line 25 (990); EZ lines 10-16 = line 17
#      exp_cols        IX 25: program + management + fundraising = total
#      exp_p1_vs_ix    Part I line 18 = IX line 25
#      prog_vs_ix      Part III total program expenses = IX 25 col B
#      bal_boy/bal_eoy assets - liabilities = net assets
#      missing_core    total revenue, total expenses, or EOY net assets blank
#    Across years, same EIN, consecutive returns (severity "warn"; a
#    restatement or a change in fiscal year can cause these legitimately):
#      py_rev / py_exp prior-year column on this return = last year's return
#      boy_assets      BOY total assets = last year's EOY total assets
#      boy_net_assets  BOY net assets = last year's EOY net assets
#      yoy_jump        total revenue or expenses changed by more than 50%
#    Structure:
#      parse_fail      XML could not be read (error)
#      dup_fy          more than one return in the same state FY (warn)
#      short_year      tax period not 12 months after the previous one (warn)
#      missing_return  return listed on ProPublica but no data (error)
#      pdf_not_found   PDF row whose PDF file is not in its FY folder (warn)
# 5. Packages (tidyverse) are loaded in SetGlobals.R.

#==============================================================================#

# Clear environment
rm(list = ls())

# Find and run build/code/SetGlobals.R (here() locates the CASA repo root)
source(here::here("build", "code", "SetGlobals.R"))

#==============================================================================#

indir <- file.path(rawdata, "CASA", "990_forms")
tol   <- 1 # dollars (rounding)

panel    <- read_csv(file.path(cleandata, "/CASA/990_forms/casa_990_panel.csv"),
                     col_types = cols(ein = "c", tax_prd = "c", object_id = "c", form = "c",
                                      fy = "c", source = "c", casa_line = "c", notes = "c",
                                      .default = col_guess()),
                     guess_max = 10000)
programs <- read_csv(file.path(indir, "casa_990_programs.csv"), col_types = cols(.default = "c"))
index    <- read_csv(file.path(indir, "casa_990_filings_index.csv"), col_types = cols(.default = "c")) |>
  filter(form %in% c("990", "990EZ")) |>
  distinct(ein, tax_prd, form, .keep_all = TRUE)

fy_start_of <- function(yyyymm) {
  yr <- as.integer(substr(yyyymm, 1, 4))
  mo <- as.integer(substr(yyyymm, 5, 6))
  ifelse(mo >= 7, yr, yr - 1)
}
sum0 <- function(...) rowSums(cbind(...), na.rm = TRUE)
n0   <- function(x) coalesce(x, 0)

# Same column types in every piece (an empty piece can otherwise come out as logical)
fix_types <- function(d) mutate(d, across(any_of(c("detail", "source", "check", "severity")), as.character),
                                across(any_of("diff"), as.numeric))
bind_fixed <- function(...) bind_rows(map(list(...), fix_types))

prog_names <- programs |> group_by(ein) |> summarise(programs = paste(program, collapse = " | "))

#==============================================================================#
#                         Checks within each return                            #
#==============================================================================#

part9_tot <- names(panel) |>
  str_subset("^exp_.*_tot$") |>
  setdiff(c("exp_total_tot", "exp_personnel_tot"))

within <- panel |>
  mutate(
    contrib_sum = ifelse(form == "990",
      sum0(rev_federated, rev_membership, rev_fundraising_events,
           rev_related_orgs, rev_govt_grants, rev_other_contrib) - rev_contrib_total, NA),
    rev_sum = ifelse(form == "990",
      sum0(rev_contrib_total, rev_program_service, rev_invest_p1, rev_other) - rev_total,
      sum0(rev_contrib_total, rev_program_service, rev_membership, rev_investment, rev_other) - rev_total),
    rev_p1_vs_viii = ifelse(form == "990", rev_total_p1 - rev_total, NA),
    events_net = ifelse(form == "990",
      n0(rev_events_gross) - n0(rev_events_direct_exp) - n0(rev_events_net), NA),
    exp_sum = ifelse(form == "990",
      rowSums(pick(all_of(part9_tot)), na.rm = TRUE) - exp_total_tot,
      sum0(exp_grants_ez, exp_member_ben_ez, exp_personnel_tot, exp_contractors_ez,
           exp_occupancy_tot, exp_printing_ez, exp_other_ez) - exp_total_tot),
    exp_cols = ifelse(form == "990",
      sum0(exp_total_prog, exp_total_mgmt, exp_total_fund) - exp_total_tot, NA),
    exp_p1_vs_ix = ifelse(form == "990", exp_total_p1 - exp_total_tot, NA),
    prog_vs_ix   = ifelse(form == "990", prog_exp_total - exp_total_prog, NA),
    bal_boy = assets_boy - liab_boy - net_assets_boy,
    bal_eoy = assets_eoy - liab_eoy - net_assets_eoy,
    missing_core = ifelse(is.na(rev_total) | is.na(exp_total_tot) | is.na(net_assets_eoy), 1, 0)
  )

within_checks <- c("contrib_sum", "rev_sum", "rev_p1_vs_viii", "events_net", "exp_sum",
                   "exp_cols", "exp_p1_vs_ix", "prog_vs_ix", "bal_boy", "bal_eoy")

issues_within <- within |>
  select(ein, fy, tax_prd, form, source, all_of(within_checks), missing_core) |>
  pivot_longer(c(all_of(within_checks), missing_core), names_to = "check", values_to = "diff") |>
  filter((check == "missing_core" & diff == 1) | (check != "missing_core" & abs(diff) > tol)) |>
  mutate(severity = "error",
         detail = ifelse(check == "missing_core", "total revenue, total expenses or EOY net assets is blank",
                         paste0("off by ", format(diff, big.mark = ","))))

#==============================================================================#
#                  Checks across years (consecutive returns)                   #
#==============================================================================#

months_between <- function(a, b) {
  (as.integer(substr(b, 1, 4)) - as.integer(substr(a, 1, 4))) * 12 +
    as.integer(substr(b, 5, 6)) - as.integer(substr(a, 5, 6))
}

across <- panel |>
  arrange(ein, tax_prd) |>
  group_by(ein) |>
  mutate(
    prev_tax_prd  = lag(tax_prd),
    prev_source   = lag(source),
    gap_months    = months_between(prev_tax_prd, tax_prd),
    py_rev        = py_rev_total - lag(rev_total),
    py_exp        = py_exp_total - lag(exp_total_tot),
    boy_assets    = assets_boy - lag(assets_eoy),
    boy_net_assets = net_assets_boy - lag(net_assets_eoy),
    rev_change    = rev_total / lag(rev_total) - 1,
    exp_change    = exp_total_tot / lag(exp_total_tot) - 1
  ) |>
  ungroup() |>
  filter(!is.na(prev_tax_prd))

issues_across <- bind_fixed(
  # Only compare when the previous return covers the 12 months right before
  across |>
    filter(gap_months == 12) |>
    select(ein, fy, tax_prd, form, source, prev_source, py_rev, py_exp, boy_assets, boy_net_assets) |>
    pivot_longer(c(py_rev, py_exp, boy_assets, boy_net_assets), names_to = "check", values_to = "diff") |>
    filter(!is.na(diff), abs(diff) > tol) |>
    mutate(detail = paste0("off by ", format(diff, big.mark = ","), " vs previous return (", prev_source, ")")),
  across |>
    filter(gap_months == 12, abs(rev_change) > 0.5 | abs(exp_change) > 0.5) |>
    transmute(ein, fy, tax_prd, form, source, check = "yoy_jump", diff = NA_real_,
              detail = paste0("revenue ", sprintf("%+.0f%%", 100 * rev_change),
                              ", expenses ", sprintf("%+.0f%%", 100 * exp_change))),
  across |>
    filter(gap_months != 12) |>
    transmute(ein, fy, tax_prd, form, source, check = "short_year", diff = gap_months,
              detail = paste0(gap_months, " months after previous return (", prev_tax_prd,
                              "); a missing year or a change in fiscal year-end"))
) |>
  mutate(severity = "warn")

#==============================================================================#
#                          Structural checks                                   #
#==============================================================================#

issues_struct <- bind_fixed(
  panel |>
    filter(parse_fail == 1) |>
    transmute(ein, fy, tax_prd, form, source, check = "parse_fail", severity = "error",
              detail = "XML could not be read; enter from PDF"),
  panel |>
    add_count(ein, fy) |>
    filter(n > 1) |>
    transmute(ein, fy, tax_prd, form, source, check = "dup_fy", severity = "warn",
              detail = paste(n, "returns in this FY (short year?); decide which to keep")),
  # Returns listed on ProPublica with no data in the panel
  index |>
    anti_join(panel, by = c("ein", "tax_prd")) |>
    transmute(ein, fy, tax_prd, form, source = NA_character_, check = "missing_return",
              severity = "error",
              detail = ifelse(has_xml == "TRUE",
                              "index has an XML but it was not parsed (rerun 01 then 02)",
                              paste0("no XML; enter from PDF: ", coalesce(pdf_href, "")))),
  # PDF rows whose PDF isn't saved in the FY folder
  panel |>
    filter(source == "pdf_manual") |>
    mutate(pdf = file.path(indir, fy, paste0(ein, "_", tax_prd, "_", form, ".pdf"))) |>
    filter(!file.exists(pdf)) |>
    transmute(ein, fy, tax_prd, form, source, check = "pdf_not_found", severity = "warn",
              detail = paste("expected", basename(pdf), "in", fy))
)

#==============================================================================#
#                              Check report                                    #
#==============================================================================#


report <- bind_fixed(issues_within, issues_across, issues_struct) |>
  left_join(prog_names, by = "ein") |>
  select(severity, check, programs, ein, fy, tax_prd, form, source, diff, detail) |>
  arrange(severity, programs, tax_prd, check)

write_csv(report, file.path(cleandata, "/CASA/990_forms/casa_990_check_report.csv"), na = "")

#==============================================================================#
#                         Coverage: program x FY                               #
#==============================================================================#

all_fy <- c(panel$fy_start, fy_start_of(index$tax_prd))
fys    <- seq(min(all_fy, na.rm = TRUE), max(all_fy, na.rm = TRUE))

listed <- index |>
  mutate(fy_start = fy_start_of(tax_prd)) |>
  group_by(ein) |>
  summarise(first_listed = min(fy_start), last_listed = max(fy_start), .groups = "drop")

coverage <- programs |>
  select(program, counties, ein, tier) |>
  cross_join(tibble(fy_start = fys)) |>
  left_join(panel |> group_by(ein, fy_start) |>
              summarise(src = paste(sort(unique(source)), collapse = "+"), .groups = "drop"),
            by = c("ein", "fy_start")) |>
  left_join(index |> mutate(fy_start = fy_start_of(tax_prd)) |> distinct(ein, fy_start) |>
              mutate(in_index = TRUE),
            by = c("ein", "fy_start")) |>
  left_join(listed, by = "ein") |>
  mutate(status = case_when(
    !is.na(src)                                   ~ src,
    coalesce(in_index, FALSE)                     ~ "MISSING",
    is.na(first_listed) | fy_start < first_listed ~ "before_first",
    fy_start > last_listed                        ~ "not_yet",
    TRUE                                          ~ "gap"
  ),
  fy = paste0("FY_", fy_start, "_", fy_start + 1))

coverage_wide <- coverage |>
  select(program, counties, ein, tier, fy, status) |>
  pivot_wider(names_from = fy, values_from = status) |>
  arrange(counties)

write_csv(coverage_wide, file.path(cleandata, "/CASA/990_forms/casa_990_coverage.csv"), na = "")

#==============================================================================#
#                                Summary                                       #
#==============================================================================#

message("\n===== Coverage (program x FY) =====")
coverage |> count(status) |> print()

message("\n===== Rows in panel =====")
panel |> count(source, form) |> print()

message("\n===== Problems found =====")
if (nrow(report) == 0) {
  message("None. Every return adds up and every listed return is in the panel.")
} else {
  report |> count(severity, check) |> print(n = Inf)
  message("\nErrors (fix these; first 50 shown, all in casa_990_check_report.csv):")
  report |> filter(severity == "error") |>
    transmute(check, programs = str_trunc(programs, 35), fy, source, detail = str_trunc(detail, 70)) |>
    print(n = 50, width = Inf)
  message("\nWarnings are listed in casa_990_check_report.csv")
}
