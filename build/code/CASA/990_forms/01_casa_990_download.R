#==============================================================================#
#                         casa_990_01_download.R                               #
#==============================================================================#

# Notes:
# 1. For each CASA nonprofit (EIN), reads its ProPublica Nonprofit Explorer
#    page and collects every e-filed XML return and every PDF return listed.
# 2. Downloads every XML return. The XML has every line of the 990, so it is
#    the source for the dataset (casa_990_02_parse.R). ProPublica blocks
#    scripted XML downloads, so the XML comes from public mirrors of the IRS
#    e-file data (GivingTuesday 990 data lake, then the old IRS AWS bucket),
#    matched on ProPublica's object_id.
# 3. PDFs: ProPublica's PDF links are viewer pages behind the same security
#    check, so the script does not try to download them (try_pdfs <- FALSE).
#    The index keeps each PDF's link (pdf_href) so returns with no XML can be
#    opened in a browser and entered by hand.
# 3b. Recent returns not yet in the archive: open the XML link on the
#    ProPublica page in a browser and save the file (any name, as long as it
#    contains the object_id, e.g. 202631359349312608_public.xml) into
#    rawdata/CASA/990_forms/manual_xml/. On the next run the script reads it
#    and files a copy in the right FY_ folder.
# 4. Files are saved to:
#      rawdata/CASA/990_forms/FY_<start>_<end>/<EIN>_<YYYYMM>_<form>_<objectid>.xml
#      rawdata/CASA/990_forms/FY_<start>_<end>/<EIN>_<YYYYMM>_<form>.pdf
#    YYYYMM = month the organization's fiscal year ended. A filing goes in the
#    California state FY (July-June) in which its fiscal year ENDS.
# 5. Exception to the usual rule: this script creates 990_forms/ and the
#    FY_ folders itself, because which FY folders are needed depends on what
#    gets downloaded. rawdata/CASA/ must already exist.
# 6. Also writes to rawdata/CASA/990_forms/:
#      casa_990_programs.csv       44 programs -> 43 EINs, with tier
#      casa_990_filings_index.csv  one row per filing found on ProPublica
# 7. Safe to rerun: files already on disk are skipped.
# 8. Only keeps filings from state FY min_fy_start onward (set below).
# 9. Packages (tidyverse, httr2, xml2) are loaded in SetGlobals.R.

#==============================================================================#

# Clear environment
rm(list = ls())

# Find and run build/code/SetGlobals.R (here() locates the CASA repo root)
source(here::here("build", "code", "SetGlobals.R"))

#==============================================================================#

try_pdfs          <- FALSE # PDF downloads are blocked by ProPublica; see note 3
download_all_pdfs <- FALSE # only used if try_pdfs is TRUE

# First CA state fiscal year to keep (2014 = FY 2014-15, i.e. org fiscal years
# ending July 2014 or later). Earlier filings are skipped.
min_fy_start <- 2014

outdir <- file.path(rawdata, "CASA", "990_forms")
if (!dir.exists(outdir)) dir.create(outdir)

#==============================================================================#
#                              Program list                                    #
#==============================================================================#

# tier (preliminary; review against Part III of the returns):
#   A = organization is the CASA program
#   B = CASA is the main program but the org runs other programs too
#   C = multi-service parent organization; CASA is one of many programs
#   D = 990 is a "Friends of" fundraising group; program itself is county-run

programs <- tribble(
  ~counties,                       ~program,                                         ~nonprofit,                                                       ~ein,        ~tier,
  "Alameda",                       "CASA of Alameda County",                         "Friends of Alameda County CASA Inc.",                            "943309728", "D",
  "Amador, Calaveras",             "CASA of Amador & Calaveras Counties",            "Nexus Youth & Family Services",                                  "812309847", "C",
  "Butte, Glenn, Shasta, Tehama",  "CASA of Butte, Glenn, Shasta & Tehama Counties", "Northern Valley Catholic Social Service Inc.",                   "200984601", "C",
  "Contra Costa",                  "Child Advocates of Contra Costa County",         "Child Advocates of Contra Costa County",                         "942897531", "A",
  "Del Norte",                     "CASA of Del Norte",                              "Court Appointed Special Advocate of Del Norte County",           "680484676", "A",
  "El Dorado",                     "Child Advocates of El Dorado County",            "CASA El Dorado",                                                 "680299245", "A",
  "Fresno, Madera",                "CASA of Fresno & Madera Counties",               "Court Appointed Special Advocates of Fresno and Madera Counties", "770401361", "A",
  "Humboldt",                      "CASA of Humboldt",                               "Court Appointed Special Advocate of Humboldt",                   "680243040", "A",
  "Imperial",                      "CASA of Imperial County",                        "Court Appointed Special Advocates of Imperial County Inc.",      "330632963", "A",
  "Inyo, Mono",                    "CASA of the Eastern Sierra",                     "Wild Iris Family Counseling & Crisis Center",                    "770039382", "C",
  "Kern",                          "CASA of Kern County",                            "Court Appointed Special Advocates of Kern County",               "770344298", "A",
  "Kings",                         "CASA of Kings County",                           "CASA of Kings County Inc.",                                      "462896299", "A",
  "Lake, Mendocino",               "CASA of Mendocino & Lake Counties",              "Court Appointed Special Advocates of Mendocino County",          "680322512", "A",
  "Lassen",                        "CASA of Lassen Family Services",                 "Lassen Family Services Inc.",                                    "942691072", "C",
  "Los Angeles",                   "CASA of Los Angeles",                            "CASA of Los Angeles",                                            "953890446", "A",
  "Marin",                         "Marin CASA",                                     "Marin Court Appointed Special Advocates",                        "815047208", "A",
  "Mariposa",                      "CASA of Mariposa County",                        "Alliance for Community Transformations",                         "770272319", "C",
  "Merced",                        "CASA of Merced County",                          "Court Appointed Special Advocates of Merced County",             "272084694", "A",
  "Modoc",                         "Modoc CASA Program",                             "Training, Employment & Community Help Inc. (T.E.A.C.H.)",        "942578204", "C",
  "Monterey",                      "CASA of Monterey County",                        "Court Appointed Special Advocates of Monterey County Inc.",      "770398079", "A",
  "Napa",                          "CASA, A Voice for Children",                     "CASA - A Voice for Children",                                    "203594007", "A",
  "Nevada",                        "Child Advocates of Nevada County",               "Child Advocates of Nevada County",                               "680317841", "B",
  "Orange",                        "CASA of Orange County",                          "Court Appointed Special Advocate of Orange County",              "330069334", "A",
  "Placer, Sutter, Yuba",          "CASA of Placer, Yuba & Sutter",                  "Child Advocates of Placer County",                               "770620948", "B",
  "Plumas",                        "Plumas CASA",                                    "Plumas Crisis Intervention & Resource Center",                   "680062136", "C",
  "Riverside",                     "Voices for Children (Riverside County)",         "Voices for Children",                                            "953786047", "A",
  "Sacramento",                    "Sacramento CASA",                                "Court Appointed Special Advocates of Sacramento County",         "680257139", "A",
  "San Benito",                    "CASA of San Benito County",                      "Court Appointed Special Advocates of San Benito County Inc.",    "452881517", "A",
  "San Bernardino",                "CASA of San Bernardino County",                  "Child Advocates of San Bernardino County",                       "330362613", "A",
  "San Diego",                     "Voices for Children (San Diego County)",         "Voices for Children",                                            "953786047", "A",
  "San Francisco",                 "San Francisco CASA",                             "San Francisco CASA",                                             "943039028", "A",
  "San Joaquin",                   "CASA of San Joaquin County",                     "San Joaquin County Child Abuse Prevention Council",              "942497046", "C",
  "San Luis Obispo",               "CASA of San Luis Obispo County",                 "Court Appointed Special Advocates of San Luis Obispo County Inc.", "770316227", "A",
  "San Mateo",                     "CASA of San Mateo County",                       "CASA of San Mateo County",                                       "043849393", "A",
  "Santa Barbara",                 "CASA of Santa Barbara County",                   "Court Appointed Special Advocates of Santa Barbara County",      "330662734", "A",
  "Santa Clara",                   "Child Advocates of Silicon Valley",              "Child Advocates of Silicon Valley Inc.",                         "770250773", "A",
  "Santa Cruz",                    "CASA of Santa Cruz County",                      "Court Appointed Special Advocates of Santa Cruz County",         "770305354", "A",
  "Siskiyou",                      "CASA of Siskiyou County",                        "Youth Empowerment Siskiyou",                                     "200714947", "B",
  "Solano",                        "CASA of Solano County",                          "CASA of Solano County",                                          "202551209", "A",
  "Sonoma",                        "CASA of Sonoma County",                          "Court Appointed Special Advocates of Sonoma County",             "680404770", "A",
  "Stanislaus",                    "CASA of Stanislaus County",                      "Court Appointed Special Advocates of Stanislaus County",         "912168629", "A",
  "Tulare",                        "CASA of Tulare County",                          "CASA of Tulare County",                                          "770105876", "A",
  "Ventura",                       "CASA of Ventura County",                         "CASA of Ventura County Inc.",                                    "451649286", "A",
  "Yolo",                          "Yolo County CASA",                               "Yolo County Court Appointed Special Advocate Program",           "680362495", "A"
)

write_csv(programs, file.path(outdir, "casa_990_programs.csv"))

eins <- unique(programs$ein)

#==============================================================================#
#                                Helpers                                       #
#==============================================================================#

pp <- "https://projects.propublica.org"

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

fetch <- function(url) {
  resp <- request(url) |>
    req_user_agent("UCSD CASA research project (academic, non-commercial)") |>
    req_retry(max_tries = 3, backoff = ~ 5) |>
    req_error(is_error = \(r) FALSE) |>
    req_perform()
  Sys.sleep(1.5)
  resp
}

# California state fiscal year (July-June) in which a fiscal year ending YYYYMM ends
fy_start_of <- function(yyyymm) {
  yr <- as.integer(substr(yyyymm, 1, 4))
  mo <- as.integer(substr(yyyymm, 5, 6))
  ifelse(mo >= 7, yr, yr - 1)
}
fy_folder <- function(yyyymm) {
  start <- fy_start_of(yyyymm)
  paste0("FY_", start, "_", start + 1)
}

# Pull tax period (YYYYMM) and form type out of a ProPublica PDF link
parse_pdf_link <- function(href) {
  h <- URLdecode(href)
  # newer: .../680257139_202506_990_2026032424028201
  m1 <- str_match(h, "(\\d{9})_(\\d{6})_(990EZ|990PF|990T|990)_")
  # older: .../68-0257139_990_201506
  m2 <- str_match(h, "(\\d{2}-\\d{7})_(990EZ|990PF|990T|990)_(\\d{6})")
  tibble(
    tax_prd = coalesce(m1[, 3], m2[, 4]),
    form    = coalesce(m1[, 4], m2[, 3])
  )
}

#==============================================================================#
#         Step 1: list every filing (XML and PDF) on each EIN's page           #
#==============================================================================#

list_filings <- function(ein) {
  message("Listing filings for EIN ", ein)
  resp <- fetch(paste0(pp, "/nonprofits/organizations/", ein))
  if (resp_status(resp) != 200) {
    warning("Page request failed for EIN ", ein, " (HTTP ", resp_status(resp), ")")
    return(tibble(ein = ein, type = NA_character_, href = NA_character_))
  }
  hrefs <- resp_body_string(resp) |>
    read_html() |>
    xml_find_all("//a[@href]") |>
    xml_attr("href") |>
    unique()

  bind_rows(
    tibble(ein = ein, type = "xml", href = str_subset(hrefs, "download-xml\\?object_id=")),
    tibble(ein = ein, type = "pdf", href = str_subset(hrefs, "/display_990/"))
  ) |>
    mutate(href = ifelse(str_starts(href, "http"), href, paste0(pp, href)))
}

links <- map(eins, list_filings) |> list_rbind() |> filter(!is.na(href))

#==============================================================================#
#                    Step 2: download every XML return                          #
#==============================================================================#

xml_links <- links |>
  filter(type == "xml") |>
  mutate(object_id = str_extract(href, "(?<=object_id=)\\d+")) |>
  distinct(ein, object_id, .keep_all = TRUE) |>
  # object_id starts with the year the IRS processed the return, which is
  # always after the fiscal year ends, so this drops clearly-too-old filings
  # before downloading. The exact FY check happens after reading the header.
  filter(as.integer(substr(object_id, 1, 4)) >= min_fy_start)

existing_xml <- list.files(outdir, pattern = "\\.xml$", recursive = TRUE, full.names = TRUE)

# ProPublica's own XML link blocks scripts (security check), so the XML is
# fetched by object_id from public mirrors of the IRS e-file data instead.
xml_sources <- function(object_id) c(
  paste0("https://gt990datalake-rawdata.s3.amazonaws.com/EfileData/XmlFiles/", object_id, "_public.xml"),
  paste0("https://s3.amazonaws.com/irs-form-990/", object_id, "_public.xml")
)

get_xml <- function(ein, object_id, href) {
  done <- existing_xml[str_detect(basename(existing_xml), object_id)]
  if (length(done) > 0) {
    f <- done[1]
    doc <- read_xml(f) |> xml_ns_strip()
  } else {
    doc <- NULL
    for (u in xml_sources(object_id)) {
      resp <- fetch(u)
      body <- if (resp_status(resp) == 200) resp_body_string(resp) else ""
      if (str_detect(body, "<Return")) {
        doc  <- read_xml(body) |> xml_ns_strip()
        href <- u
        break
      }
    }
    if (is.null(doc)) {
      warning("XML download failed: EIN ", ein, " object ", object_id)
      return(tibble(ein, object_id, xml_href = href, tax_prd = NA_character_,
                    form = NA_character_, xml_file = NA_character_))
    }
  }

  end_dt  <- xml_text(xml_find_first(doc, "//ReturnHeader/TaxPeriodEndDt|//ReturnHeader/TaxPeriodEndDate"))
  form    <- xml_text(xml_find_first(doc, "//ReturnHeader/ReturnTypeCd|//ReturnHeader/ReturnType"))
  tax_prd <- str_remove_all(substr(end_dt, 1, 7), "-")

  # Too early: don't save
  if (fy_start_of(tax_prd) < min_fy_start) {
    return(tibble(ein, object_id, xml_href = href, tax_prd, form, xml_file = NA_character_))
  }

  # Standard location; also files a copy of anything saved by hand in manual_xml/
  fy <- fy_folder(tax_prd)
  f  <- file.path(outdir, fy, paste0(ein, "_", tax_prd, "_", form, "_", object_id, ".xml"))
  if (!file.exists(f)) {
    if (!dir.exists(file.path(outdir, fy))) dir.create(file.path(outdir, fy))
    write_xml(doc, f)
  }
  tibble(ein, object_id, xml_href = href, tax_prd, form, xml_file = f)
}

xml_index <- pmap(select(xml_links, ein, object_id, href), get_xml) |> list_rbind()

#==============================================================================#
#      Step 3: download PDFs for filings with no XML (or all, if chosen)        #
#==============================================================================#

pdf_index <- links |>
  filter(type == "pdf") |>
  rename(pdf_href = href) |>
  bind_cols(parse_pdf_link(links$href[links$type == "pdf"])) |>
  filter(!is.na(tax_prd)) |>
  distinct(ein, tax_prd, form, .keep_all = TRUE) |>
  select(-type)

filings <- full_join(
  xml_index |> filter(is.na(tax_prd) | fy_start_of(tax_prd) >= min_fy_start),
  pdf_index |> filter(fy_start_of(tax_prd) >= min_fy_start),
  by = c("ein", "tax_prd", "form")
) |>
  mutate(
    has_xml  = !is.na(xml_file),
    fy       = fy_folder(tax_prd),
    pdf_file = ifelse(try_pdfs & !is.na(pdf_href) & (!has_xml | download_all_pdfs),
                      file.path(outdir, fy, paste0(ein, "_", tax_prd, "_", form, ".pdf")),
                      NA_character_)
  )

# ProPublica's display_990 link is a viewer page, not the PDF. Look inside the
# page for the link to the PDF file itself and download that.
get_pdf <- function(pdf_href, pdf_file) {
  if (is.na(pdf_file)) return(FALSE)
  if (file.exists(pdf_file)) return(TRUE)

  is_pdf <- function(r) {
    if (resp_status(r) != 200) return(FALSE)
    raw <- tryCatch(resp_body_raw(r), error = \(e) raw(0))
    length(raw) > 4 && identical(raw[1:4], charToRaw("%PDF"))
  }

  resp <- fetch(pdf_href)
  if (!is_pdf(resp) && resp_status(resp) == 200) {
    page  <- read_html(resp_body_string(resp))
    cands <- c(xml_attr(xml_find_all(page, "//a[@href]"), "href"),
               xml_attr(xml_find_all(page, "//*[@src]"), "src"),
               xml_attr(xml_find_all(page, "//*[@data]"), "data")) |>
      str_subset("(?i)\\.pdf|download990pdf|pdf_url|/pdf") |>
      unique()
    cands <- ifelse(str_starts(cands, "http"), cands,
                    ifelse(str_starts(cands, "//"), paste0("https:", cands), paste0(pp, cands)))
    for (u in cands) {
      resp <- fetch(u)
      if (is_pdf(resp)) break
    }
  }

  ok <- is_pdf(resp)
  if (ok) {
    if (!dir.exists(dirname(pdf_file))) dir.create(dirname(pdf_file))
    writeBin(resp_body_raw(resp), pdf_file)
  } else {
    warning("PDF download failed (open this link in a browser instead): ", pdf_href)
  }
  ok
}

filings$pdf_downloaded <- map2_lgl(filings$pdf_href, filings$pdf_file, get_pdf)

#==============================================================================#
#                         Step 4: write filing index                           #
#==============================================================================#

filings <- filings |>
  left_join(
    programs |> group_by(ein) |>
      summarise(programs = paste(program, collapse = " | "), tier = first(tier)),
    by = "ein"
  ) |>
  select(programs, ein, tier, fy, tax_prd, form, has_xml, object_id, xml_file,
         pdf_downloaded, pdf_file, xml_href, pdf_href) |>
  arrange(programs, tax_prd, form)

write_csv(filings, file.path(outdir, "casa_990_filings_index.csv"))

# Quick look: filings per program by FY (X = XML, P = PDF only)
filings |>
  filter(form %in% c("990", "990EZ")) |>
  mutate(src = ifelse(has_xml, "X", "P")) |>
  distinct(programs, fy, src) |>
  group_by(programs, fy) |>
  summarise(src = paste(sort(unique(src)), collapse = ""), .groups = "drop") |>
  tidyr::pivot_wider(names_from = fy, values_from = src, names_sort = TRUE) |>
  print(n = Inf, width = Inf)
