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
	GOOD=$'\e[32;01m'
	WARN=$'\e[33;01m'
	BAD=$'\e[31;01m'
	NORMAL=$'\e[0m'
	BOLD=$'\e[0;01m'
	UNDER=$'\e[4m'
else
	GOOD=''
	WARN=''
	BAD=''
	NORMAL=''
	BOLD=''
	UNDER=''
fi

dump_debugcache() {
	TODEBUGCACHE=0
	echo "${DEBUGCACHE}" >> ${DEBUGFILE}
}

# print_info(debuglevel, print [, newline [, prefixline [, forcefile ] ] ])
print_info() {
	local NEWLINE=1
	local FORCEFILE=0
	local PREFIXLINE=1
	local SCRPRINT=0
	local STR=''

	# NOT ENOUGH ARGS
	if [ "$#" -lt '2' ] ; then return 1; fi

	# IF 3 OR MORE ARGS, CHECK IF WE WANT A NEWLINE AFTER PRINT
	if [ "$#" -gt '2' ]
	then
		if isTrue "$3"
		then
			NEWLINE='1';
		else
			NEWLINE='0';
		fi
	fi

	# IF 4 OR MORE ARGS, CHECK IF WE WANT TO PREFIX WITH A *
	if [ "$#" -gt '3' ]
	then
		if isTrue "$4"
		then
			PREFIXLINE='1'
		else
			PREFIXLINE='0'
		fi
	fi

	# IF 5 OR MORE ARGS, CHECK IF WE WANT TO FORCE OUTPUT TO DEBUG
	# FILE EVEN IF IT DOESN'T MEET THE MINIMUM DEBUG REQS
	if [ "$#" -gt '4' ]
	then
		if isTrue "$5"
		then
			FORCEFILE='1'
		else
			FORCEFILE='0'
		fi
	fi

	# PRINT TO SCREEN ONLY IF PASSED DEBUGLEVEL IS HIGHER THAN
	# OR EQUAL TO SET DEBUG LEVEL
	if [ "$1" -lt "${DEBUGLEVEL}" -o "$1" -eq "${DEBUGLEVEL}" ]
	then
		SCRPRINT='1'
	fi

	# RETURN IF NOT OUTPUTTING ANYWHERE
	if [ "${SCRPRINT}" != '1' -a "${FORCEFILE}" != '1' ]
	then
		return 0
	fi

	# STRUCTURE DATA TO BE OUTPUT TO SCREEN, AND OUTPUT IT
	if [ "${SCRPRINT}" -eq '1' ]
	then
		if [ "${PREFIXLINE}" = '1' ]
		then
			STR="${GOOD}*${NORMAL} ${2}"
		else
			STR="${2}"
		fi

		if [ "${NEWLINE}" = '0' ]
		then
			echo -ne "${STR}"
		else
			echo "${STR}"
		fi
	fi

	# STRUCTURE DATA TO BE OUTPUT TO FILE, AND OUTPUT IT
	if [ "${SCRPRINT}" -eq '1' -o "${FORCEFILE}" -eq '1' ]
	then
		STRR=${2//${WARN}/}
		STRR=${STRR//${BAD}/}
		STRR=${STRR//${BOLD}/}
		STRR=${STRR//${NORMAL}/}

		if [ "${PREFIXLINE}" = '1' ]
		then
			STR="* ${STRR}"
		else
			STR="${STRR}"
		fi

		if [ "${NEWLINE}" = '0' ]
		then
			if [ "${TODEBUGCACHE}" -eq 1 ]; then
				DEBUGCACHE="${DEBUGCACHE}${STR}"
			else
				echo -ne "${STR}" >> ${DEBUGFILE}
			fi	
		else
			if [ "${TODEBUGCACHE}" -eq 1 ]; then
				DEBUGCACHE="${DEBUGCACHE}${STR}"$'\n'
			else
				echo "${STR}" >> ${DEBUGFILE}
			fi
		fi
	fi

	return 0
}

print_error()
{
	GOOD=${BAD} print_info "$@"
}

print_warning()
{
	GOOD=${WARN} print_info "$@"
}

# var_replace(var_name, var_value, string)
# $1 = variable name
# $2 = variable value
# $3 = string

var_replace()
{
  # Escape '\' and '.' in $2 to make it safe to use
  # in the later sed expression
  local SAFE_VAR
  SAFE_VAR=`echo "${2}" | sed -e 's/\([\/\.]\)/\\\\\\1/g'`
  
  echo "${3}" | sed -e "s/%%${1}%%/${SAFE_VAR}/g" -
  echo "${3}" | sed -e "s/%%${1}%%/${SAFE_VAR}/g" >> /tmp/out
}

arch_replace() {
  var_replace "ARCH" "${ARCH}" "${1}"
}

cache_replace() {
  var_replace "CACHE" "${CACHE_DIR}" "${1}"
}

clear_log() {
	[ -f "${DEBUGFILE}" ] && echo > "${DEBUGFILE}"
}

gen_die() {
	dump_debugcache

	if [ "$#" -gt '0' ]
	then
		print_error 1 "ERROR: ${1}"
	fi
	echo
	print_info 1 "-- Grepping log... --"
	echo

	if isTrue ${USECOLOR}
	then
		GREP_COLOR='1' grep -B5 -E --colour=always "([Ww][Aa][Rr][Nn][Ii][Nn][Gg]|[Ee][Rr][Rr][Oo][Rr][ :,!]|[Ff][Aa][Ii][Ll][Ee]?[Dd]?)" ${DEBUGFILE}
	else
		grep -B5 -E "([Ww][Aa][Rr][Nn][Ii][Nn][Gg]|[Ee][Rr][Rr][Oo][Rr][ :,!]|[Ff][Aa][Ii][Ll][Ee]?[Dd]?)" ${DEBUGFILE}
	fi
	echo
	print_info 1 "-- End log... --"
	echo
	print_info 1 "Please consult ${DEBUGFILE} for more information and any"
	print_info 1 "errors that were reported above."
	echo
	print_info 1 "Report any genkernel bugs to bugs.gentoo.org and"
	print_info 1 "assign your bug to genkernel@gentoo.org. Please include"
	print_info 1 "as much information as you can in your bug report; attaching"
	print_info 1 "${DEBUGFILE} so that your issue can be dealt with effectively."
	print_info 1 ''
	print_info 1 'Please do *not* report compilation failures as genkernel bugs!'
	print_info 1 ''
  	exit 1
}

has_loop() {
	dmesg | egrep -q '^loop:'
	if [ -e '/dev/loop0' -o -e '/dev/loop/0' -a $? ]
	then
		# We found devfs or standard dev loop device, assume
		# loop is compiled into the kernel or the module is loaded
		return 0
	else
		return 1
	fi
}

isBootRO()
{
	for mo in `grep ' /boot ' /proc/mounts | cut -d ' ' -f 4 | sed -e 's/,/ /'`
	do
		if [ "x${mo}x" == "xrox" ]
		then
			return 0
		fi
	done
	return 1
}
