"""
Report definitions for the CCWIP scraper, transcribed from requests captured
in DevTools. Selections are kept in the order the site sent them.

To add a report: capture its SasConnect request, copy the JSON list from
--data-raw, and add an entry below. Only change values via "overrides" so it
stays obvious what differs from the captured request.

Overrides applied here (see notes on each report):
  BEGIN_YR  start the series so the first period is JUL2014-JUN2015 (fiscal
            reports) or 2014 (calendar reports)
  TYPE      "P" (percent) -> "T" (counts). This is a guess based on the Exits
            and Population requests, which use "T" and return counts. The
            probe prints the table's unit so you can confirm.
"""

BASE = "https://ccwip.berkeley.edu/childwelfare/reports/"


def S(sp, sel, sdp=None, sdvsel=None):
    return {"sp": sp, "sel": sel, "sdp": sdp, "sdvsel": sdvsel}


REPORTS = {
    # Median length of stay, first entries. Calendar-year periods; the site
    # returns all years (2004 onward) in one response.
    "MLOS": {
        "referer": BASE + "MLOS/MTSG/r/fcp/l",
        "overrides": {},
        "selections": [
            S("AVCNTY", "1"), S("AVROW", "AGE"), S("MLOS_VAR", "2"),
            S("AGEGRP", "1"), S("_program", "MLOS_MTSG"),
            S("AVCOL", "PERIOD_DT"), S("AVQTR", "X"), S("AVYEAR", "X"),
            S("COURT_VAL", "X"), S("PERIOD_DT_VAL", "X"), S("PIT_PLC_VAL", "X"),
            S("PIT_SCPR_VAL", "X"), S("REMREAS_VAL", "X"), S("TIME_VAL", "X"),
            S("AGECLS_VAL", "X"), S("ETHNIC_VAL", "X"), S("GENDER_VAL", "X"),
            S("geoDispType", "r"),
        ],
    },

    # 4-P4 re-entry to foster care (exits to reunification/guardianship that
    # re-entered within 12 months). Fiscal-year (Jul-Jun) periods.
    "reentry": {
        "referer": BASE + "P4/MTSG/r/Fed/l",
        "overrides": {"BEGIN_YR": "2015", "TYPE": "T"},
        "selections": [
            S("ISQTR", "3"), S("BEGIN_YR", "2015"), S("AGENCY_VAL", "1"),
            S("AVCNTY", "0000"), S("TYPE", "P"), S("ENTRY_VAL", "1,2"),
            S("termin_val", "0"), S("TYPE2", "1"),
            S("_program", "cfsr4p4_webEX"), S("AVCOL", "PERIOD_DT"),
            S("AVQTR", "X"), S("AVYEAR", "X"), S("FLAG_8_VAL", "1,2"),
            S("PERIOD_DT_VAL", "X"), S("AGECLS_VAL", "X"), S("ETHNIC_VAL", "X"),
            S("GENDER_VAL", "X"), S("P_PLC_VAL", "X"), S("P_SCPR_VAL", "X"),
            S("geoDispType", "r"),
        ],
    },

    # Recurrence of ALLEGATIONS within 12 months. This is not foster care
    # re-entry; it is included because it was in the captured set.
    "recurrence": {
        "referer": BASE + "RecurAlleg/MTSG/r/ab636/l",
        "overrides": {"BEGIN_YR": "2015", "TYPE": "T"},
        "selections": [
            S("ISQTR", "3"), S("BEGIN_YR", "2015"), S("AVCNTY", "0000"),
            S("TYPE", "P"), S("TIME", "12"), S("FIRST_REF_VAL", "X"),
            S("_program", "RECURRENCE_webEX"), S("AGECL_VAL", "X"),
            S("AVCOL", "PERIOD_DT"), S("AVQTR", "X"), S("AVYEAR", "X"),
            S("CCOS", "X"), S("FIRST_CLU_VAL", "X"), S("PERIOD_DT_VAL", "X"),
            S("AGECLS_VAL", "X"), S("ALG_DSPC_VAL", "X"), S("ALG_TPC_VAL", "X"),
            S("ETHNIC_VAL", "X"), S("GENDER_VAL", "X"), S("REPORTER_VAL", "X"),
            S("geoDispType", "r"),
        ],
    },

    # Entry cohorts: outcomes within 12 months of entry (EXIT_TIME_VAL = 12).
    # BEGIN_YR here is the START year of the first period (captured 1998 gave
    # JUL1998-JUN1999), unlike reentry/exits/closures/recurrence where it is the
    # END year. So 2014 gives JUL2014-JUN2015.
    "entry_cohort": {
        "referer": BASE + "EntryCohorts/MTSG/r/ab636/l",
        "overrides": {"BEGIN_YR": "2014", "TYPE": "T"},
        "selections": [
            S("ISQTR", "3"), S("AGENCY_VAL", "1"), S("AVCNTY", "0000"),
            S("TYPE", "P"), S("EXIT_TIME_VAL", "12"), S("FLAG_8_VAL", "1"),
            S("ENTRY_VAL", "1,2"), S("ICWA_VAL", "X"),
            S("_program", "entry_cohort_webEX"), S("AVCOL", "PERIOD_DT"),
            S("AVQTR", "X"), S("AVYEAR", "X"), S("BEGIN_YR", "1998"),
            S("CCOS", "X"), S("EXIT_TYPE_VAL", "X"), S("L_PLC_VAL", "X"),
            S("L_SCPR_VAL", "X"), S("P1FLAG", "0"), S("PERIOD_DT_VAL", "X"),
            S("PLACE_VAL", "X"), S("TRIBAL_STC_VAL", "X"), S("AGECLS_VAL", "X"),
            S("ETHNIC_VAL", "X"), S("F_PLC_VAL", "X"), S("F_SCPR_VAL", "X"),
            S("GENDER_VAL", "X"), S("MO12_PLC_VAL", "X"),
            S("MO12_SCPR_VAL", "X"), S("REMREAS_VAL", "X"),
            S("geoDispType", "r"),
        ],
    },

    # Exits from care (counts, TYPE already "T"). Captured BEGIN_YR was 2016.
    "exits": {
        "referer": BASE + "Exits/MTSG/r/ab636/l",
        "overrides": {"BEGIN_YR": "2015"},
        "selections": [
            S("ISQTR", "3"), S("BEGIN_YR", "2016"), S("AGENCY_VAL", "1"),
            S("AVCNTY", "0"), S("TYPE", "T"), S("FLAG_8_VAL", "1"),
            S("EXIT_VAL", "1,2", "UNDUP_VAL", "X"), S("ICWA_VAL", "X"),
            S("_program", "exits_webEX"), S("AVCOL", "PERIOD_DT"),
            S("AVQTR", "X"), S("AVYEAR", "X"), S("CENS_ETHNIC_VAL", "X"),
            S("CENS_RC_VAL", "X"), S("HISP_CDX_VAL", "X"),
            S("PERIOD_DT_VAL", "X"), S("TRIBAL_STC_VAL", "X"),
            S("AGECLS_VAL", "X"), S("ETHNIC_VAL", "X"), S("EXIT_TYPE_VAL", "X"),
            S("GENDER_VAL", "X"), S("P_PLC_VAL", "X"), S("P_SCPR_VAL", "X"),
            S("geoDispType", "r"),
        ],
    },

    # Case closures (counts). Captured BEGIN_YR was 2016.
    "case_closures": {
        "referer": BASE + "CaseClosures/MTSG/r/ab636/l",
        "overrides": {"BEGIN_YR": "2015"},
        "selections": [
            S("ISQTR", "3"), S("BEGIN_YR", "2016"), S("AGENCY_VAL", "1"),
            S("AVCNTY", "0"), S("TYPE", "T"), S("FLAG_8_VAL", "1"),
            S("EXIT_VAL", "X", "UNDUP_VAL", "1"),
            S("_program", "case_exits_webEX"), S("AVCOL", "PERIOD_DT"),
            S("AVQTR", "X"), S("AVYEAR", "X"), S("CENS_ETHNIC_VAL", "X"),
            S("CENS_RC_VAL", "X"), S("HISP_CDX_VAL", "X"),
            S("PERIOD_DT_VAL", "X"), S("SCMASK", "0"), S("AGECLS_VAL", "X"),
            S("CLOSE_REAS_VAL", "X"), S("ETHNIC_VAL", "X"),
            S("GENDER_VAL", "X"), S("SRV_CMP_VAL", "X"),
            S("geoDispType", "r"),
        ],
    },

    # Entries into care by age group (rates report). Captured BEGIN_YR 2016.
    # Check the probe output: if it shows rates rather than counts, TYPE needs
    # to change and I need the matching request.
    "entry_rates": {
        "referer": BASE + "EntryRates/MTSG/r/rts/l",
        "overrides": {"BEGIN_YR": "2014"},
        "selections": [
            S("BEGIN_YR", "2016"), S("AVCNTY", "0"), S("TYPE", "3"),
            S("AVCOL", "AGE_GRP"), S("LEVEL_VAL", "3"),
            S("_program", "entry_rates_MTSG"), S("AVQTR", "X"),
            S("AVYEAR", "X"), S("CCOS", "X"), S("AGECLS_VAL", "X"),
            S("ETHNIC_VAL", "X"), S("GENDER_VAL", "X"),
            S("geoDispType", "r"),
        ],
    },

    # Children in care on a point in time, by age group (rates report).
    "in_care_rates": {
        "referer": BASE + "InCareRates/MTSG/r/rts/l",
        "overrides": {"BEGIN_YR": "2014"},
        "selections": [
            S("BEGIN_YR", "2017"), S("AVCNTY", "0"), S("TYPE", "3"),
            S("AVCOL", "AGE_GRP"), S("_program", "pit_rates_MTSG"),
            S("AVQTR", "X"), S("AVYEAR", "X"), S("CCOS", "X"),
            S("LEVEL_VAL", "6"), S("AGECLS_VAL", "X"), S("ETHNIC_VAL", "X"),
            S("GENDER_VAL", "X"), S("geoDispType", "r"),
        ],
    },

    # Child population by age and period (counts, TYPE "T").
    "population": {
        "referer": BASE + "Population/MTSG/r/rts/l",
        "overrides": {"BEGIN_YR": "2014"},
        "selections": [
            S("BEGIN_YR", "2017"), S("AVCNTY", "0"), S("TYPE", "T"),
            S("AVROW", "AGE"), S("_program", "pops_webEX"),
            S("AVCOL", "PERIOD_DT"), S("AVQTR", "X"), S("AVYEAR", "X"),
            S("PERIOD_DT_VAL", "X"), S("AGECLS_VAL", "X"),
            S("ETHNIC_VAL", "X"), S("GENDER_VAL", "X"),
            S("geoDispType", "r"),
        ],
    },
}
