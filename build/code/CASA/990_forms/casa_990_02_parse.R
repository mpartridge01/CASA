# Clear environment
rm(list = ls())

# Find and run build/code/SetGlobals.R (here() locates the CASA repo root)
source(here::here("build", "code", "SetGlobals.R"))

#==============================================================================#
#                           casa_990_02_parse.R                                #
#==============================================================================#

# Notes:
# 1. Reads every XML return saved by casa_990_01_download.R, adds the returns
#    hand-entered from PDFs, and builds:
#      cleandata/casa_990_panel.csv            one row per EIN x fiscal year
#      cleandata/CASA/990_forms/casa_990_other_expenses.csv   Part IX line 24a-d items (long, XML only)
#      cleandata/CASA/990_forms/casa_990_program_services.csv Part III line 4a-4d (long, XML only)
#      cleandata/CASA/990_forms/casa_990_codebook.csv         description of panel variables
# 2. Covers Form 990 and 990-EZ. 990-T and other forms are skipped. 990-EZ
#    has far less detail: no Part IX breakdown, no employee/volunteer counts,
#    no separate government-grants line.
# 3. Amended returns: keeps the latest filing for each EIN x tax period.
# 4. On a full 990, a blank line is omitted from the XML, so missing amounts
#    are set to 0. Employee/volunteer counts stay missing if not reported.
# 5. casa_* variables use Part III to find the CASA program's expenses in
#    multi-program organizations (tiers B and C). casa_line_is_other = 1 means
#    CASA was lumped into line 4d "Other" with other programs, so casa_exp is
#    NOT a CASA-only number.
# 6. Returns with no XML (paper filings) are entered by hand from the PDF in
#      rawdata/CASA/990_forms/casa_990_pdf_entry.csv
#    using the same variable names as the panel (see pdf_vars below). This
#    script never writes to that file. Rows are added with source = "pdf_manual".
#    A PDF row is dropped (with a message) if an XML for the same EIN x tax
#    period exists. PDF rows have Part IX line totals (col A) only; the
#    program/management/fundraising split is entered for line 25 only.
# 7. Also writes rawdata/CASA/990_forms/casa_990_pdf_entry_template.csv: one
#    blank row per return that still has no data, with the same columns as
#    casa_990_pdf_entry.csv. Copy rows from it into casa_990_pdf_entry.csv.
# 8. Checks on every row (XML and PDF alike) are in casa_990_03_check.R.
#    chk_flag here is a quick summary of the within-return add-up checks.
# 9. Packages (tidyverse, xml2) are loaded in SetGlobals.R.

#==============================================================================#


# Clear environment
rm(list = ls())

# Find and run build/code/SetGlobals.R (here() locates the CASA repo root)
source(here::here("build", "code", "SetGlobals.R"))

#==============================================================================#

indir <- file.path(rawdata, "CASA", "990_forms")

programs <- read_csv(file.path(indir, "casa_990_programs.csv"), col_types = cols(.default = "c"))
files    <- list.files(indir, pattern = "\\.xml$", recursive = TRUE, full.names = TRUE) |>
  str_subset("/manual_xml/", negate = TRUE) # hand-saved copies are re-filed into FY_ folders by script 01

#==============================================================================#
#                                Helpers                                       #
#==============================================================================#

txt <- function(node, path) xml_text(xml_find_first(node, path))
num <- function(node, path, absent = 0) {
  v <- txt(node, path)
  if (is.na(v)) absent else as.numeric(v)
}

fy_start_of <- function(yyyymm) {
  yr <- as.integer(substr(yyyymm, 1, 4))
  mo <- as.integer(substr(yyyymm, 5, 6))
  ifelse(mo >= 7, yr, yr - 1)
}

# Part IX lines: variable stub = XML group name
part9 <- c(
  exp_grants_orgs       = "GrantsToDomesticOrgsGrp",        # 1
  exp_grants_indiv      = "GrantsToDomesticIndividualsGrp", # 2
  exp_grants_foreign    = "ForeignGrantsGrp",               # 3
  exp_member_benefits   = "BenefitsToMembersGrp",           # 4
  exp_officer_comp      = "CompCurrentOfcrDirectorsGrp",    # 5
  exp_disq_comp         = "CompDisqualPersonsGrp",          # 6
  exp_salaries          = "OtherSalariesAndWagesGrp",       # 7
  exp_pension           = "PensionPlanContributionsGrp",    # 8
  exp_benefits          = "OtherEmployeeBenefitsGrp",       # 9
  exp_payroll_tax       = "PayrollTaxesGrp",                # 10
  exp_fees_mgmt         = "FeesForServicesManagementGrp",   # 11a
  exp_fees_legal        = "FeesForServicesLegalGrp",        # 11b
  exp_fees_acct         = "FeesForServicesAccountingGrp",   # 11c
  exp_fees_lobby        = "FeesForServicesLobbyingGrp",     # 11d
  exp_fees_prof_fr      = "FeesForServicesProfFundraising", # 11e
  exp_fees_invest       = "FeesForSrvcInvstMgmntFeesGrp",   # 11f
  exp_fees_other        = "FeesForServicesOtherGrp",        # 11g
  exp_advertising       = "AdvertisingGrp",                 # 12
  exp_office            = "OfficeExpensesGrp",              # 13
  exp_it                = "InformationTechnologyGrp",       # 14
  exp_royalties         = "RoyaltiesGrp",                   # 15
  exp_occupancy         = "OccupancyGrp",                   # 16
  exp_travel            = "TravelGrp",                      # 17
  exp_travel_officials  = "PymtTravelEntrtnmntPubOfclGrp",  # 18
  exp_conferences       = "ConferencesMeetingsGrp",         # 19
  exp_interest          = "InterestGrp",                    # 20
  exp_affiliates        = "PaymentsToAffiliatesGrp",        # 21
  exp_depreciation      = "DepreciationDepletionGrp",       # 22
  exp_insurance         = "InsuranceGrp",                   # 23
  exp_all_other         = "AllOtherExpensesGrp"             # 24e
)
cols9 <- c(tot = "TotalAmt", prog = "ProgramServicesAmt", mgmt = "ManagementAndGeneralAmt", fund = "FundraisingAmt")

#==============================================================================#
#                       Parse one Form 990 return                              #
#==============================================================================#

parse_990 <- function(f9) {
  row <- list(
    # Part I / Part V: people
    emp_count = num(f9, "./TotalEmployeeCnt", NA),
    vol_count = num(f9, "./TotalVolunteersCnt", NA),

    # Part I summary columns (used by the checks)
    rev_invest_p1 = num(f9, "./CYInvestmentIncomeAmt"),          # I 10 (VIII 3, 4, 7d)
    rev_total_p1  = num(f9, "./CYTotalRevenueAmt", NA),          # I 12, current year
    exp_total_p1  = num(f9, "./CYTotalExpensesAmt", NA),         # I 18, current year
    py_rev_total  = num(f9, "./PYTotalRevenueAmt", NA),          # I 12, prior year
    py_exp_total  = num(f9, "./PYTotalExpensesAmt", NA),         # I 18, prior year

    # Part VIII: revenue
    rev_federated          = num(f9, "./FederatedCampaignsAmt"),                       # 1a
    rev_membership         = num(f9, "./MembershipDuesAmt"),                           # 1b
    rev_fundraising_events = num(f9, "./FundraisingAmt"),                              # 1c
    rev_related_orgs       = num(f9, "./RelatedOrganizationsAmt"),                     # 1d
    rev_govt_grants        = num(f9, "./GovernmentGrantsAmt"),                         # 1e
    rev_other_contrib      = num(f9, "./AllOtherContributionsAmt"),                    # 1f
    rev_noncash            = num(f9, "./NoncashContributionsAmt"),                     # 1g (memo)
    rev_contrib_total      = num(f9, "./TotalContributionsAmt"),                       # 1h
    rev_program_service    = num(f9, "./CYProgramServiceRevenueAmt"),                  # 2g
    rev_investment         = num(f9, "./InvestmentIncomeGrp/TotalRevenueColumnAmt"),   # 3
    rev_events_gross       = num(f9, "./FundraisingGrossIncomeAmt"),                   # 8a
    rev_events_direct_exp  = num(f9, "./FundraisingDirectExpensesAmt"),                # 8b
    rev_events_net         = num(f9, "./NetIncmFromFundraisingEvtGrp/TotalRevenueColumnAmt"), # 8c
    rev_other              = num(f9, "./CYOtherRevenueAmt"),                           # I 11
    rev_total              = num(f9, "./TotalRevenueGrp/TotalRevenueColumnAmt",
                                 num(f9, "./CYTotalRevenueAmt", NA)),                  # 12

    # Part III: program service expenses
    prog_exp_total = num(f9, "./TotalProgramServiceExpensesAmt", NA),

    # Part X: balance sheet
    assets_boy     = num(f9, "./TotalAssetsGrp/BOYAmt", NA),
    assets_eoy     = num(f9, "./TotalAssetsGrp/EOYAmt", NA),
    liab_boy       = num(f9, "./TotalLiabilitiesGrp/BOYAmt", NA),
    liab_eoy       = num(f9, "./TotalLiabilitiesGrp/EOYAmt", NA),
    net_assets_boy = num(f9, "./TotalNetAssetsFundBalanceGrp/BOYAmt", NA),
    net_assets_eoy = num(f9, "./TotalNetAssetsFundBalanceGrp/EOYAmt", NA)
  )

  # Part IX: each line x (total, program, management, fundraising)
  for (v in names(part9)) for (c in names(cols9)) {
    row[[paste0(v, "_", c)]] <- num(f9, paste0("./", part9[[v]], "/", cols9[[c]]))
  }

  # Part IX line 24a-d (itemized "other" expenses, org's own descriptions)
  oth <- xml_find_all(f9, "./OtherExpensesGrp")
  other_exp <- tibble(
    desc = map_chr(oth, \(n) txt(n, "./Desc")),
    tot  = map_dbl(oth, \(n) num(n, "./TotalAmt")),
    prog = map_dbl(oth, \(n) num(n, "./ProgramServicesAmt")),
    mgmt = map_dbl(oth, \(n) num(n, "./ManagementAndGeneralAmt")),
    fund = map_dbl(oth, \(n) num(n, "./FundraisingAmt"))
  )
  for (c in names(cols9)) row[[paste0("exp_other_itemized_", c)]] <- sum(other_exp[[c]])

  for (c in names(cols9)) {
    row[[paste0("exp_total_", c)]] <- num(f9, paste0("./TotalFunctionalExpensesGrp/", cols9[[c]]), NA)
  }
  if (is.na(row$exp_total_tot)) row$exp_total_tot <- num(f9, "./CYTotalExpensesAmt", NA)

  # Part III line 4a (direct children of IRS990) and 4b-4d (groups)
  prog <- tibble(
    line     = "4a",
    expense  = num(f9, "./ExpenseAmt", NA),
    grants   = num(f9, "./GrantAmt", NA),
    revenue  = num(f9, "./RevenueAmt", NA),
    desc     = paste(xml_text(xml_find_all(f9, "./Desc")), collapse = " ")
  )
  grps <- xml_find_all(f9, "./*[starts-with(name(), 'ProgSrvcAccomActy')]")
  if (length(grps) > 0) {
    prog <- bind_rows(prog, tibble(
      line    = map_chr(grps, \(g) case_when(
        str_detect(xml_name(g), "Other") ~ "4d",
        str_detect(xml_name(g), "2")     ~ "4b",
        str_detect(xml_name(g), "3")     ~ "4c",
        TRUE ~ xml_name(g))),
      expense = map_dbl(grps, \(g) num(g, "./ExpenseAmt", NA)),
      grants  = map_dbl(grps, \(g) num(g, "./GrantAmt", NA)),
      revenue = map_dbl(grps, \(g) num(g, "./RevenueAmt", NA)),
      desc    = map_chr(grps, \(g) paste(xml_text(xml_find_all(g, "./Desc")), collapse = " "))
    ))
  }
  prog <- filter(prog, !is.na(expense) | desc != "")

  row$parse_fail <- as.integer(is.na(row$rev_total) & is.na(row$exp_total_tot))
  list(row = as_tibble(row), other_exp = other_exp, prog = prog)
}

#==============================================================================#
#                       Parse one Form 990-EZ return                           #
#==============================================================================#

parse_990ez <- function(fz) {
  row <- list(
    rev_contrib_total   = num(fz, "./ContributionsGiftsGrantsEtcAmt"),       # 1
    rev_program_service = num(fz, "./ProgramServiceRevenueAmt"),             # 2
    rev_membership      = num(fz, "./MembershipDuesAmt"),                    # 3
    rev_investment      = num(fz, "./InvestmentIncomeAmt"),                  # 4
    rev_events_net      = num(fz, "./SpecialEventsNetIncomeLossAmt"),        # 6d
    rev_other           = num(fz, "./GainOrLossFromSaleOfAssetsAmt") +       # 5c
                          num(fz, "./SpecialEventsNetIncomeLossAmt") +       # 6d
                          num(fz, "./GrossProfitLossSlsOfInvntryAmt") +      # 7c
                          num(fz, "./OtherRevenueTotalAmt"),                 # 8
    rev_total           = num(fz, "./TotalRevenueAmt", NA),                  # 9

    exp_grants_ez       = num(fz, "./GrantsAndSimilarAmountsPaidAmt"),       # 10
    exp_member_ben_ez   = num(fz, "./BenefitsPaidToOrForMbrsAmt"),           # 11
    exp_personnel_tot   = num(fz, "./SalariesOtherCompEmplBnftAmt"),         # 12
    exp_contractors_ez  = num(fz, "./FeesAndOtherPymtToIndCntrctAmt|./FeesAndOthPymtToIndCntrctAmt"), # 13
    exp_occupancy_tot   = num(fz, "./OccupancyRentUtltsAndMaintAmt"),        # 14
    exp_printing_ez     = num(fz, "./PrintingPublicationsPostageAmt"),       # 15
    exp_other_ez        = num(fz, "./OtherExpensesTotalAmt"),                # 16
    exp_total_tot       = num(fz, "./TotalExpensesAmt", NA),                 # 17

    prog_exp_total      = num(fz, "./TotalProgramServiceExpensesAmt", NA),

    assets_boy     = num(fz, "./Form990TotalAssetsGrp/BOYAmt", NA),         # 25 (A)
    assets_eoy     = num(fz, "./Form990TotalAssetsGrp/EOYAmt", NA),         # 25 (B)
    liab_boy       = num(fz, "./SumOfTotalLiabilitiesGrp/BOYAmt", NA),      # 26 (A)
    liab_eoy       = num(fz, "./SumOfTotalLiabilitiesGrp/EOYAmt", NA),      # 26 (B)
    net_assets_boy = num(fz, "./NetAssetsOrFundBalancesGrp/BOYAmt", NA),    # 27 (A)
    net_assets_eoy = num(fz, "./NetAssetsOrFundBalancesGrp/EOYAmt", NA)     # 27 (B)
  )

  grps <- xml_find_all(fz, "./ProgramSrvcAccomplishmentGrp")
  prog <- tibble(
    line    = paste0("EZ", seq_along(grps)),
    expense = map_dbl(grps, \(g) num(g, "./ProgramServiceExpensesAmt", NA)),
    grants  = map_dbl(grps, \(g) num(g, "./GrantsAndAllocationsAmt", NA)),
    revenue = rep(NA_real_, length(grps)),
    desc    = map_chr(grps, \(g) txt(g, "./DescriptionProgramSrvcAccomTxt"))
  )

  row$parse_fail <- as.integer(is.na(row$rev_total) & is.na(row$exp_total_tot))
  list(row = as_tibble(row), other_exp = tibble(), prog = prog)
}

#==============================================================================#
#                         Parse every XML file                                 #
#==============================================================================#

parse_file <- function(f) {
  doc  <- read_xml(f) |> xml_ns_strip()
  hdr  <- xml_find_first(doc, "//ReturnHeader")
  form <- txt(hdr, "./ReturnTypeCd|./ReturnType")
  if (!form %in% c("990", "990EZ")) return(NULL)

  id <- tibble(
    ein            = txt(hdr, "./Filer/EIN"),
    org_name       = txt(hdr, "./Filer/BusinessName/BusinessNameLine1Txt|./Filer/BusinessName/BusinessNameLine1|./Filer/Name/BusinessNameLine1"),
    form           = form,
    tax_prd_begin  = txt(hdr, "./TaxPeriodBeginDt|./TaxPeriodBeginDate"),
    tax_prd_end    = txt(hdr, "./TaxPeriodEndDt|./TaxPeriodEndDate"),
    object_id      = str_extract(basename(f), "\\d{15,}(?=\\.xml$)"),
    schema_version = xml_attr(xml_root(doc), "returnVersion"),
    amended        = as.integer(!is.na(txt(doc, "//AmendedReturnInd")))
  )

  out <- if (form == "990") parse_990(xml_find_first(doc, "//IRS990"))
         else parse_990ez(xml_find_first(doc, "//IRS990EZ"))

  list(
    row       = bind_cols(id, out$row),
    other_exp = if (nrow(out$other_exp) > 0) bind_cols(select(id, ein, tax_prd_end, object_id), out$other_exp),
    prog      = if (nrow(out$prog) > 0) bind_cols(select(id, ein, tax_prd_end, object_id), out$prog)
  )
}

parsed <- map(files, \(f) tryCatch(parse_file(f), error = \(e) {
  warning("Could not parse ", f, ": ", conditionMessage(e)); NULL
})) |> compact()

panel     <- map(parsed, "row") |> list_rbind()
other_exp <- map(parsed, "other_exp") |> compact() |> list_rbind()
prog      <- map(parsed, "prog") |> compact() |> list_rbind()

#==============================================================================#
#                Keep latest filing per EIN x tax period                       #
#==============================================================================#

panel <- panel |>
  mutate(tax_prd = str_remove_all(substr(tax_prd_end, 1, 7), "-")) |>
  group_by(ein, tax_prd) |>
  mutate(n_versions = n()) |>
  arrange(desc(object_id), .by_group = TRUE) |>
  slice(1) |>
  ungroup() |>
  mutate(source = "xml")

other_exp <- semi_join(other_exp, panel, by = c("ein", "object_id"))
prog      <- semi_join(prog, panel, by = c("ein", "object_id"))

#==============================================================================#
#                CASA program line from Part III (tiers B and C)               #
#==============================================================================#

casa_regex <- regex("\\bCASA\\b|court[- ]appointed|special advocate", ignore_case = TRUE)

prog <- prog |> mutate(mentions_casa = as.integer(str_detect(coalesce(desc, ""), casa_regex)))

casa_lines <- prog |>
  filter(mentions_casa == 1) |>
  group_by(ein, object_id) |>
  arrange(line, .by_group = TRUE) |>
  summarise(
    casa_line          = first(line),
    casa_exp           = first(expense),
    casa_line_is_other = as.integer(first(line) == "4d"),
    .groups = "drop"
  )

panel <- left_join(panel, casa_lines, by = c("ein", "object_id"))

#==============================================================================#
#                  Returns hand-entered from PDFs (no XML)                     #
#==============================================================================#

# Variables entered by hand. Same names as the XML panel.
# Full 990: everything below except the *_ez lines.
# 990-EZ: rev_contrib_total, rev_program_service, rev_membership, rev_investment,
#         rev_events_net, rev_other (lines 5c+6d+7c+8), rev_total, the *_ez lines,
#         exp_personnel_tot, exp_occupancy_tot, exp_total_tot, prog_exp_total,
#         and the balance sheet.
pdf_vars <- c(
  # Part I
  "emp_count", "vol_count", "rev_invest_p1", "rev_total_p1", "exp_total_p1",
  "py_rev_total", "py_exp_total",
  # Part VIII
  "rev_federated", "rev_membership", "rev_fundraising_events", "rev_related_orgs",
  "rev_govt_grants", "rev_other_contrib", "rev_noncash", "rev_contrib_total",
  "rev_program_service", "rev_investment", "rev_events_gross", "rev_events_direct_exp",
  "rev_events_net", "rev_other", "rev_total",
  # Part IX, column A for every line, plus line 25 by column
  paste0(names(part9), "_tot"), "exp_other_itemized_tot",
  "exp_total_tot", "exp_total_prog", "exp_total_mgmt", "exp_total_fund",
  # 990-EZ expense lines (EZ only)
  "exp_grants_ez", "exp_member_ben_ez", "exp_personnel_tot", "exp_contractors_ez",
  "exp_occupancy_tot", "exp_printing_ez", "exp_other_ez",
  # Part III
  "prog_exp_total", "casa_line", "casa_exp",
  # Part X
  "assets_boy", "assets_eoy", "liab_boy", "liab_eoy", "net_assets_boy", "net_assets_eoy"
)
pdf_id_vars <- c("programs", "ein", "org_name", "fy", "tax_prd", "form", "pdf_file", "pages")
pdf_text_vars <- c("casa_line")

# Template: one blank row per 990/990-EZ return in the filings index with no
# data yet (no XML here and not already in casa_990_pdf_entry.csv)
pdf_file    <- file.path(indir, "casa_990_pdf_entry.csv")
idx_file    <- file.path(indir, "casa_990_filings_index.csv")
pdf_entered <- if (file.exists(pdf_file)) {
  read_csv(pdf_file, col_types = cols(.default = "c"))
} else {
  tibble()
}

if (file.exists(idx_file)) {
  template <- read_csv(idx_file, col_types = cols(.default = "c")) |>
    filter(form %in% c("990", "990EZ")) |>
    distinct(ein, tax_prd, form, .keep_all = TRUE) |>
    anti_join(panel |> filter(parse_fail == 0), by = c("ein", "tax_prd")) |>
    transmute(programs, ein, org_name = NA_character_, fy, tax_prd, form,
              pdf_file = paste0(fy, "/", ein, "_", tax_prd, "_", form, ".pdf"),
              pages = NA_character_)
  if (nrow(pdf_entered) > 0) template <- anti_join(template, pdf_entered, by = c("ein", "tax_prd"))
  for (v in c(pdf_vars, "notes")) template[[v]] <- NA
  template <- arrange(template, programs, tax_prd)
  write_csv(template, file.path(indir, "casa_990_pdf_entry_template.csv"), na = "")
  message(nrow(template), " returns still have no data; see casa_990_pdf_entry_template.csv")
}

if (nrow(pdf_entered) > 0) {
  pdf_rows <- pdf_entered |>
    mutate(across(any_of(setdiff(pdf_vars, pdf_text_vars)),
                  \(x) as.numeric(str_remove_all(x, "[,$ ]"))),
           ein = str_pad(ein, 9, pad = "0"),
           source = "pdf_manual", parse_fail = 0L, n_versions = 1L) |>
    select(-any_of(c("programs", "fy", "pdf_file", "pages")))

  dup_xml <- semi_join(pdf_rows, panel, by = c("ein", "tax_prd"))
  if (nrow(dup_xml) > 0) message("Ignoring ", nrow(dup_xml),
    " PDF row(s) that now have an XML: ", paste(dup_xml$ein, dup_xml$tax_prd, collapse = ", "))

  pdf_rows <- anti_join(pdf_rows, panel, by = c("ein", "tax_prd"))
  panel    <- bind_rows(panel, pdf_rows)
  message(nrow(pdf_rows), " hand-entered returns added to the panel")
}

#==============================================================================#
#                     Derived variables, quick checks                          #
#==============================================================================#

sum0 <- function(...) rowSums(cbind(...), na.rm = TRUE)

# Make sure every variable exists even if no 990 (or no 990-EZ) filings were parsed
needed <- c(paste0(rep(c(names(part9), "exp_other_itemized", "exp_total"), each = 4), "_", names(cols9)),
            setdiff(pdf_vars, pdf_text_vars), "casa_line_is_other", "notes")
for (v in setdiff(needed, names(panel))) panel[[v]] <- NA
if (!"casa_line" %in% names(panel)) panel$casa_line <- NA_character_
part9_tot <- c(paste0(names(part9), "_tot"), "exp_other_itemized_tot")

panel <- panel |>
  mutate(
    casa_line_is_other = coalesce(casa_line_is_other, as.integer(casa_line == "4d")),
    fy_start = fy_start_of(tax_prd),
    fy_end   = fy_start + 1,
    fy       = paste0("FY_", fy_start, "_", fy_end),

    # Personnel = Part IX lines 5-10 (990); line 12 (990-EZ)
    exp_personnel_tot = ifelse(form == "990",
      sum0(exp_officer_comp_tot, exp_disq_comp_tot, exp_salaries_tot,
           exp_pension_tot, exp_benefits_tot, exp_payroll_tax_tot),
      exp_personnel_tot),

    # Quick add-up checks (full set in casa_990_03_check.R)
    chk_contrib_diff = ifelse(form == "990",
      sum0(rev_federated, rev_membership, rev_fundraising_events,
           rev_related_orgs, rev_govt_grants, rev_other_contrib) - rev_contrib_total,
      NA),
    chk_exp_diff = ifelse(form == "990",
      rowSums(pick(all_of(part9_tot)), na.rm = TRUE) - exp_total_tot,
      sum0(exp_grants_ez, exp_member_ben_ez, exp_personnel_tot, exp_contractors_ez, exp_occupancy_tot,
           exp_printing_ez, exp_other_ez) - exp_total_tot),
    chk_flag = as.integer(abs(coalesce(chk_contrib_diff, 0)) > 1 | abs(coalesce(chk_exp_diff, 0)) > 1)
  ) |>
  left_join(
    programs |> group_by(ein) |>
      summarise(programs = paste(program, collapse = " | "),
                counties = paste(counties, collapse = "; "),
                tier = first(tier)),
    by = "ein"
  ) |>
  relocate(programs, counties, tier, ein, org_name, fy, fy_start, fy_end, tax_prd,
           form, source, amended, n_versions, object_id, schema_version, parse_fail, chk_flag) |>
  arrange(programs, tax_prd)

#==============================================================================#
#                                Codebook                                      #
#==============================================================================#

codebook <- c(
  programs = "CASA program(s) covered by this EIN",
  counties = "Counties served",
  tier = "A=CASA only, B=CASA + other programs, C=multi-service parent, D=Friends group",
  ein = "Employer Identification Number of the filing nonprofit",
  org_name = "Name on the return",
  fy = "CA state FY (July-June) in which org's fiscal year ends",
  fy_start = "Start year of CA state FY",
  fy_end = "End year of CA state FY",
  tax_prd = "Month org's fiscal year ended (YYYYMM)",
  form = "990 or 990EZ",
  source = "xml = parsed from e-filed XML; pdf_manual = hand-entered from PDF",
  amended = "1 = amended return",
  n_versions = "Number of filings for this EIN x tax period (latest kept)",
  object_id = "IRS e-file object ID (XML only)",
  parse_fail = "XML not parsed (older schema); hand entry needed",
  chk_flag = "Components don't add to totals (review; see casa_990_03_check.R)",
  emp_count = "Employees (Part I line 5)",
  vol_count = "Volunteers, estimate (Part I line 6)",
  rev_invest_p1 = "Investment income (Part I line 10 = VIII 3, 4, 7d)",
  rev_total_p1 = "Total revenue, current year (Part I line 12)",
  exp_total_p1 = "Total expenses, current year (Part I line 18)",
  py_rev_total = "Total revenue, prior year column (Part I line 12)",
  py_exp_total = "Total expenses, prior year column (Part I line 18)",
  rev_federated = "Federated campaigns (VIII 1a)",
  rev_membership = "Membership dues (VIII 1b; EZ line 3)",
  rev_fundraising_events = "Contributions from fundraising events (VIII 1c)",
  rev_related_orgs = "Contributions from related orgs (VIII 1d)",
  rev_govt_grants = "Government grants (VIII 1e)",
  rev_other_contrib = "All other contributions (VIII 1f)",
  rev_noncash = "Noncash contributions, memo (VIII 1g)",
  rev_contrib_total = "Total contributions (VIII 1h; EZ line 1)",
  rev_program_service = "Program service revenue (VIII 2g; EZ line 2)",
  rev_investment = "Investment income (VIII 3; EZ line 4)",
  rev_events_gross = "Fundraising events gross income (VIII 8a)",
  rev_events_direct_exp = "Fundraising events direct expenses (VIII 8b)",
  rev_events_net = "Fundraising events net income (VIII 8c; EZ line 6d)",
  rev_other = "Other revenue (Part I line 11; EZ lines 5c+6d+7c+8)",
  rev_total = "Total revenue (VIII 12; EZ line 9)",
  exp_personnel_tot = "Personnel: IX lines 5-10 (EZ line 12)",
  exp_occupancy_tot = "Occupancy (IX 16; EZ line 14)",
  exp_total_tot = "Total expenses (IX 25; EZ line 17)",
  exp_total_prog = "Program service expenses (IX 25 col B)",
  exp_total_mgmt = "Management & general expenses (IX 25 col C)",
  exp_total_fund = "Fundraising expenses (IX 25 col D)",
  exp_other_itemized_tot = "Sum of itemized other expenses (IX 24a-d)",
  exp_grants_ez = "Grants paid (EZ line 10)",
  exp_member_ben_ez = "Benefits paid to members (EZ line 11)",
  exp_contractors_ez = "Professional fees, independent contractors (EZ line 13)",
  exp_printing_ez = "Printing, publications, postage (EZ line 15)",
  exp_other_ez = "Other expenses (EZ line 16)",
  prog_exp_total = "Total program service expenses (Part III line 4e; EZ Part III)",
  casa_line = "Part III line describing CASA",
  casa_exp = "Expenses on Part III line describing CASA",
  casa_line_is_other = "CASA lumped into Part III line 4d Other",
  assets_boy = "Total assets, beginning of year (X 16; EZ 25)",
  assets_eoy = "Total assets, end of year (X 16; EZ 25)",
  liab_boy = "Total liabilities, beginning of year (X 26; EZ 26)",
  liab_eoy = "Total liabilities, end of year (X 26; EZ 26)",
  net_assets_boy = "Net assets, beginning of year (X 33; EZ 27)",
  net_assets_eoy = "Net assets, end of year (X 33; EZ 27)",
  chk_contrib_diff = "Check: VIII 1a-1f minus 1h",
  chk_exp_diff = "Check: IX components minus line 25",
  notes = "Notes from hand entry (PDF rows)"
)

codebook <- tibble(variable = names(panel)) |>
  mutate(description = unname(codebook[variable]),
         description = case_when(
           !is.na(description) ~ description,
           str_ends(variable, "_tot")  ~ "Part IX line, total (col A)",
           str_ends(variable, "_prog") ~ "Part IX line, program services (col B; XML only)",
           str_ends(variable, "_mgmt") ~ "Part IX line, management & general (col C; XML only)",
           str_ends(variable, "_fund") ~ "Part IX line, fundraising (col D; XML only)",
           TRUE ~ NA_character_))

#==============================================================================#
#                                Save                                          #
#==============================================================================#

write_csv(panel,     file.path(cleandata, "/CASA/990_forms/casa_990_panel.csv"), na = "")
write_csv(other_exp, file.path(cleandata, "/CASA/990_forms/casa_990_other_expenses.csv"), na = "")
write_csv(prog,      file.path(cleandata, "/CASA/990_forms/casa_990_program_services.csv"), na = "")
write_csv(codebook,  file.path(cleandata, "/CASA/990_forms/casa_990_codebook.csv"), na = "")

# Quick look
panel |>
  count(source, tier, form, parse_fail, chk_flag) |>
  print()
