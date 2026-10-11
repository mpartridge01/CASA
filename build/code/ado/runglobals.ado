*==============================================================================*
*                                runglobals.ado                                *
*==============================================================================*

/* Notes:
1. Starts at the current working directory and moves up until it finds the
   folder containing build/, then runs build/code/SetGlobals.do
2. Stata can't see a do-file's own location, so this works as long as the
   working directory is somewhere inside the repo
3. Usage: runglobals
*/

*==============================================================================*

program define runglobals
	version 17

	local d "`c(pwd)'"
	local found 0
	while `found' == 0 & !inlist("`d'", "", "/") {
		mata: st_local("found", strofreal(direxists(st_local("d") + "/build")))
		if `found' == 0 {
			mata: p = ""; f = ""; pathsplit(st_local("d"), p, f); st_local("d", p)
		}
	}

	if `found' == 0 {
		di as error "Could not find the build folder above `c(pwd)'. cd into the repo first."
		exit 601
	}

	do "`d'/build/code/SetGlobals.do"
end
