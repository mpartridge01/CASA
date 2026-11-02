#==============================================================================#
#                                SetGlobals.R                                  #
#==============================================================================#

# Notes:
# 1. R version of SetGlobals.do. Sets up global directories for all users once
#    added to this script.
# 2. Code lives on GitHub (github); data lives on OneDrive (onedrive)
# 3. Run at the top of every R script with:
#      rm(list = ls())
#      source(here::here("build", "code", "SetGlobals.R"))
#    here::here() finds the CASA repo root (the folder with .git), so this
#    works as long as R is started inside the repo (e.g. open CASA.Rproj).

#==============================================================================#

options(scipen = 999, stringsAsFactors = FALSE)

#==============================================================================#
#              Set paths based on user and operating system                    #
#==============================================================================#

os   <- Sys.info()[["sysname"]] # "Darwin" = Mac, "Windows" = Windows
user <- Sys.info()[["user"]]

# display operating system to help set globals
message("Operating system: ", os, "  |  Username: ", user)

# Michael's MacBook
if (os == "Darwin" && user == "mpart") {
  github   <- "/Users/mpart/Documents/GitHub/CASA"
  onedrive <- "/Users/mpart/Library/CloudStorage/OneDrive-UCSanDiego/Marsh, Emily's files - CASA"

# Emily's PC
} else if (os == "Windows" && user == "emi") {
  github   <- "C:/Users/emi/Documents/GitHub/CASA"
  onedrive <- "C:/Users/emi/OneDrive - UC San Diego/Research/CASA/data"

# Template for additional users (fill in username from Sys.info()[["user"]])
# } else if (os == "Darwin" && user == "username_here") {
#   github   <- "path/to/GitHub/CASA"
#   onedrive <- "path/to/OneDrive/CASA folder"

# Send back an error so it is clear that global directories are not being set
} else {
  stop("User ", user, " on ", os, " not recognized. Add your paths to SetGlobals.R.")
}

#==============================================================================#
#                                Set globals                                   #
#==============================================================================#

# Code globals
buildcode    <- file.path(github, "build", "code")    # Code that imports and cleans raw data
analysiscode <- file.path(github, "analysis", "code") # Code that works with cleaned data to conduct analysis

# Data globals
rawdata   <- file.path(onedrive, "data", "raw_data")   # Raw data
cleandata <- file.path(onedrive, "data", "clean_data") # Cleaned data

# Output globals
analysisoutput <- file.path(github, "analysis", "output") # Tables and figures

rm(os, user)

library(tidyverse)
library(httr2)
library(xml2)
library(dplyr)
library(purrr)
library(stringr)
library(readr)
library(tibble)

