*==============================================================================*
*                                SetGlobals.do                                 *
*==============================================================================*

/* Notes:
1. Sets up global directories for all users once added to this script
2. Code lives on GitHub ($github); data lives on OneDrive ($onedrive)
*/

*==============================================================================*

****** Set options
clear all
set more off, permanently
set type double, permanently
//version 18.0

*==============================================================================*
*              Set paths based on user and operating system                    *
*==============================================================================*

* Michael's MacBook
if "`c(os)'" == "MacOSX" & "`c(username)'" == "mpart" {
	global github   "/Users/mpart/Documents/GitHub/CASA"
	global onedrive "/Users/mpart/Library/CloudStorage/OneDrive-UCSanDiego/Marsh, Emily's files - CASA"
}

* Template for additional users (fill in username from c(username) and paths)
* else if "`c(os)'" == "MacOSX" & "`c(username)'" == "username_here" {
*	global github   "path/to/GitHub/CASA"
*	global onedrive "path/to/OneDrive/CASA folder"
* }

else {
	di as error "User `c(username)' on `c(os)' not recognized. Add your paths to SetGlobals.do."
	exit 198
}

*==============================================================================*
*                                Set globals                                   *
*==============================================================================*

* Code globals
global buildcode    "$github/build/code"    // Code that imports and cleans raw data
global analysiscode "$github/analysis/code" // Code that works with cleaned data to conduct analysis

* Data globals
global rawdata   "$onedrive/raw_data"   // Raw data
global cleandata "$onedrive/clean_data" // Cleaned data

* Output globals
global analysisoutput "$github/analysis/output" // Tables and figures
