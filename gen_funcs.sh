#!/bin/bash

isTrue() {
	case "$1" in
		[Tt][Rr][Uu][Ee])
			return 0
		;;
		[Tt])
			return 0
		;;
		[Yy][Ee][Ss])
			return 0
		;;
		[Yy])
			return 0
		;;
		1)
			return 0
		;;
	esac
	return 1
}


if isTrue ${USECOLOR}
then
#	COLS="`stty size 2> /dev/null`"
#        COLS="`getcols ${COLS}`"
#        COLS=$((${COLS} - 7))
#        ENDCOL=$'\e[A\e['${COLS}'G'    # Now, ${ENDCOL} will move us to the end of the
                                       # column;  irregardless of character width
	GOOD=$'\e[32;01m'
	WARN=$'\e[33;01m'
	BAD=$'\e[31;01m'
	NORMAL=$'\e[0m'
	HILITE=$'\e[36;01m'
	BRACKET=$'\e[34;01m'
else
	GOOD=""
	WARN=""
	BAD=""
	NORMAL=""
	HILITE=""
	BRACKET=""
fi


# print_info(debuglevel, print [, newline [, prefixline [, forcefile ] ] ])
print_info() {
	local NEWLINE=1
	local FORCEFILE=0
	local PREFIXLINE=1
	local SCRPRINT=0
	local STR=""

	# NOT ENOUGH ARGS
	if [ "$#" -lt "2" ] ; then return 1; fi

	# IF 3 OR MORE ARGS, CHECK IF WE WANT A NEWLINE AFTER PRINT
	if [ "$#" -gt "2" ]
	then
		if isTrue "$3"
		then
			NEWLINE="1";
		else
			NEWLINE="0";
		fi
	fi

	# IF 4 OR MORE ARGS, CHECK IF WE WANT TO PREFIX WITH A *
	if [ "$#" -gt "3" ]
	then
		if isTrue "$4"
		then
			PREFIXLINE="1"
		else
			PREFIXLINE="0"
		fi
	fi

	# IF 5 OR MORE ARGS, CHECK IF WE WANT TO FORCE OUTPUT TO DEBUG
	# FILE EVEN IF IT DOESN'T MEET THE MINIMUM DEBUG REQS
	if [ "$#" -gt "4" ]
	then
		if isTrue "$5"
		then
			FORCEFILE="1"
		else
			FORCEFILE="0"
		fi
	fi

	# PRINT TO SCREEN ONLY IF PASSED DEBUGLEVEL IS HIGHER THAN
	# OR EQUAL TO SET DEBUG LEVEL
	if [ "$1" -lt "${DEBUGLEVEL}" -o "$1" -eq "${DEBUGLEVEL}" ]
	then
		SCRPRINT="1"
	fi

	# RETURN IF NOT OUTPUTTING ANYWHERE
	if [ "${SCRPRINT}" != "1" -a "${FORCEFILE}" != "1" ]
	then
		return 0
	fi

	# STRUCTURE DATA TO BE OUTPUT TO SCREEN, AND OUTPUT IT
	if [ "${SCRPRINT}" -eq "1" ]
	then
		if [ "${PREFIXLINE}" = "1" ]
		then
			STR="${GOOD}*${NORMAL} ${2}"
		else
			STR="${2}"
		fi

		if [ "${NEWLINE}" = "0" ]
		then
			echo -ne "${STR}"
		else
			echo "${STR}"
		fi
	fi

	# STRUCTURE DATA TO BE OUTPUT TO FILE, AND OUTPUT IT
	if [ "${SCRPRINT}" -eq "1" -o "${FORCEFILE}" -eq "1" ]
	then
		if [ "${PREFIXLINE}" = "1" ]
		then
			STR="* ${2}"
		else
			STR="${2}"
		fi

		if [ "${NEWLINE}" = "0" ]
		then
			echo -ne "${STR}" >> ${DEBUGFILE}
		else
			echo "${STR}" >> ${DEBUGFILE}
		fi
	fi

	return 0
}

# var_replace(var_name, var_value, string)
# $1 = variable name
# $2 = variable value
# $3 = string
var_replace()
{
  echo "${3}" | sed -e "s/%%${1}%%/${2}/g" -
}

arch_replace() {
  var_replace "ARCH" "${ARCH}" "${1}"
}

clear_log() {
  rm -f ${DEBUGFILE}
  touch ${DEBUGFILE}
}

gen_die() {
	if [ "$#" -gt "0" ]
	then
		print_info 1 "gen_die(): ${1}"
	fi
	print_info 1 "Please see ${DEBUGFILE} for more info on failures"
	print_info 1 ""
	print_info 1 "DO NOT REPORT KERNEL COMPILE FAILURES AS GENKERNEL BUGS!"
	print_info 1 ""
	print_info 1 "Report real genkernel bugs to bugs.gentoo.org"
  	exit 1
}

has_loop() {
	if [ -e "/dev/loop0" -o -e "/dev/loop/0" ]
	then
		# We found devfs or standard dev loop device, assume
		# loop is compiled into the kernel or the module is loaded
		return 0
	else
		return 1
	fi
}
