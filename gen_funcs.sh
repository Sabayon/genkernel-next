#!/bin/bash
# $Id$

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

setColorVars() {
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
}
setColorVars

dump_debugcache() {
    TODEBUGCACHE=0
    echo "${DEBUGCACHE}" >> ${LOGFILE}
}

# print_info(loglevel, print [, newline [, prefixline [, forcefile ] ] ])
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

    # PRINT TO SCREEN ONLY IF PASSED LOGLEVEL IS HIGHER THAN
    # OR EQUAL TO SET DEBUG LEVEL
    if [ "$1" -lt "${LOGLEVEL}" -o "$1" = "${LOGLEVEL}" ]
    then
        SCRPRINT='1'
    fi

    # RETURN IF NOT OUTPUTTING ANYWHERE
    if [ "${SCRPRINT}" != '1' -a "${FORCEFILE}" != '1' ]
    then
        return 0
    fi

    # STRUCTURE DATA TO BE OUTPUT TO SCREEN, AND OUTPUT IT
    if [ "${SCRPRINT}" = '1' ]
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
    if [ "${SCRPRINT}" = '1' -o "${FORCEFILE}" = '1' ]
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
            if [ "${TODEBUGCACHE}" = '1' ]; then
                DEBUGCACHE="${DEBUGCACHE}${STR}"
            else
                echo -ne "${STR}" >> ${LOGFILE}
            fi
        else
            if [ "${TODEBUGCACHE}" = '1' ]; then
                DEBUGCACHE="${DEBUGCACHE}${STR}"$'\n'
            else
                echo "${STR}" >> ${LOGFILE}
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
}

arch_replace() {
  var_replace "ARCH" "${ARCH}" "${1}"
}

cache_replace() {
  var_replace "CACHE" "${CACHE_DIR}" "${1}"
}

clear_log() {
    if [ -f "${LOGFILE}" ]
    then
    (echo > "${LOGFILE}") 2>/dev/null || small_die "Genkernel: Could not write to ${LOGFILE}."
    fi
}

gen_die() {
    dump_debugcache

    if [ "$#" -gt '0' ]
    then
        print_error 1 "ERROR: ${1}"
    fi
    print_error 1 ''
    print_error 1 "-- Grepping log... --"
    print_error 1 ''

    if isTrue ${USECOLOR}
    then
        GREP_COLOR='1' grep -B5 -E --colour=always "([Ww][Aa][Rr][Nn][Ii][Nn][Gg]|[Ee][Rr][Rr][Oo][Rr][ :,!]|[Ff][Aa][Ii][Ll][Ee]?[Dd]?)" ${LOGFILE} \
                | sed -s "s|^\(*\)\?|${BAD}*${NORMAL}|"
    else
        grep -B5 -E "([Ww][Aa][Rr][Nn][Ii][Nn][Gg]|[Ee][Rr][Rr][Oo][Rr][ :,!]|[Ff][Aa][Ii][Ll][Ee]?[Dd]?)" ${LOGFILE}
    fi
    print_error 1 ''
    print_error 1 "-- End log... --"
    print_error 1 ''
    print_error 1 "Please consult ${LOGFILE} for more information and any"
    print_error 1 "errors that were reported above."
    print_error 1 ''
    print_error 1 "Report any genkernel bugs to bugs.gentoo.org and"
    print_error 1 "assign your bug to genkernel@gentoo.org. Please include"
    print_error 1 "as much information as you can in your bug report; attaching"
    print_error 1 "${LOGFILE} so that your issue can be dealt with effectively."
    print_error 1 ''
    print_error 1 'Please do *not* report compilation failures as genkernel bugs!'
    print_error 1 ''

    # Cleanup temp dirs and caches if requested
    cleanup
    exit 1
}

isBootRO()
{
    return $(awk '( $2 == "'${BOOTDIR}'" && $4 ~ /(^|,)ro(,|$)/){ I=1; exit }END{print !I }' /proc/mounts);
}

setup_cache_dir()
{

[ ! -d "${CACHE_DIR}" ] && mkdir -p "${CACHE_DIR}"

if [ "${CLEAR_CACHE_DIR}" == 'yes' ]
then
    print_info 1 "Clearing cache dir contents from ${CACHE_DIR}"
    while read i
    do
        print_info 1 "   >> removing ${i}"
        rm "${i}"
    done < <(find "${CACHE_DIR}" -maxdepth 1 -type f -name '*.tar.*' -o -name '*.bz2')
fi

}

clear_tmpdir()
{
if isTrue ${CMD_INSTALL}
then
    TMPDIR_CONTENTS=`ls ${TMPDIR}`
    print_info 1 "Removing tmp dir contents"
    for i in ${TMPDIR_CONTENTS}
    do
        print_info 1 "   >> removing ${i}"
        rm ${TMPDIR}/${i}
    done
fi
}

#
# Function to copy various kernel boot image products to the boot directory,
# preserve a generation of old images (just like the manual kernel build's
# "make install" does), and maintain the symlinks (if enabled).
#
# Arguments:
#     $1  Symlink name.  Symlink on the boot directory. Path not included.
#     $2  Source image.  Fully qualified path name of the source image.
#     $3  Dest image.    Name of the destination image in the boot directory,
#         no path included.  This script pushd's into ${BOOTDIR} in order to
#         create relative symlinks just like the manual kernel build.
#
# - JRG
#
copy_image_with_preserve() {
    local symlinkName=$1
    local newSrceImage=$2
    local fullDestName=$3

    local currDestImage
    local prevDestImage
    local currDestImageExists=0
    local prevDestImageExists=0

    print_info 4 "Copying new ${symlinkName} image, " 0

    # Old product might be a different version.  If so, we need to read
    # the symlink to see what it's name is, if there are symlinks.
    cd ${KERNEL_OUTPUTDIR}
    if [ "${SYMLINK}" = '1' ]
    then
        print_info 4 "automatically managing symlinks and old images." 1 0
        if [ -e "${BOOTDIR}/${symlinkName}" ]
        then
            # JRG: Do I need a special case here for when the standard symlink
            # name is, in fact, not a symlink?
            currDestImage=`readlink --no-newline ${BOOTDIR}/${symlinkName}`
            print_info 5 "  Current ${symlinkName} symlink exists:"
            print_info 5 "    ${currDestImage}"
        else
            currDestImage="${fullDestName}"
            print_info 5 "  Current ${symlinkName} symlink did not exist."
            print_info 5 "    Defaulted to: ${currDestImage}"
        fi
        if [ -e "${BOOTDIR}/${currDestImage}" ]
        then
            currDestImageExists=1
            print_info 5 "  Actual image file exists."
        fi

        if [ -e "${BOOTDIR}/${symlinkName}.old" ]
        then
            # JRG: Do I need a special case here for when the standard symlink
            # name is, in fact, not a symlink?
            prevDestImage=`readlink --no-newline ${BOOTDIR}/${symlinkName}.old`
            print_info 5 "  Old ${symlinkName} symlink exists:"
            print_info 5 "    ${prevDestImage}"
        else
            prevDestImage="${fullDestName}.old"
            print_info 5 "  Old ${symlinkName} symlink did not exist."
            print_info 5 "    Defaulted to: ${prevDestImage}"
        fi
        if [ -e "${BOOTDIR}/${prevDestImage}" ]
        then
            prevDestImageExists=1
            print_info 5 "  Actual old image file exists."
        fi
    else
        print_info 4 "symlinks not being handled by genkernel." 1 0
        currDestImage="${fullDestName}"
        prevDestImage="${fullDestName}.old"
    fi

    # When symlinks are not being managed by genkernel, old symlinks might
    # still be useful.  Leave 'em alone unless managed.
    if [ "${SYMLINK}" = '1' ]
    then
        print_info 5 "  Deleting old symlinks, if any."
        rm -f "${BOOTDIR}/${symlinkName}"
        rm -f "${BOOTDIR}/${symlinkName}.old"
    fi

    # We only erase the .old image when it is the exact same version as the
    # current and new images.  Different version .old (and current) images are
    # left behind.  This is consistent with how "make install" of the manual
    # kernel build works.
    if [ "${currDestImage}" == "${fullDestName}" ]
    then
        #
        # Case for new and currrent of the same base version.
        #
        print_info 5 "  Same base version.  May have to delete old image to make room."

        if [ "${currDestImageExists}" = '1' ]
        then
            if [ -e "${BOOTDIR}/${currDestImage}.old" ]
            then
                print_info 5 "  Deleting old identical version ${symlinkName}."
                rm -f "${BOOTDIR}/${currDestImage}.old"
            fi
            print_info 5 "  Moving ${BOOTDIR}/${currDestImage}"
            print_info 5 "    to ${BOOTDIR}/${currDestImage}.old"
            mv "${BOOTDIR}/${currDestImage}" "${BOOTDIR}/${currDestImage}.old" ||
                gen_die "Could not rename the old ${symlinkName} image!"
            prevDestImage="${currDestImage}.old"
            prevDestImageExists=1
        fi
    else
        #
        # Case for new / current not of the same base version.
        #
        print_info 5 "  Different base version.  Do not delete old images."
        prevDestImage="${currDestImage}"
        currDestImage="${fullDestName}"
    fi

    print_info 5 "  Copying ${symlinkName}: ${newSrceImage}"
    print_info 5 "    to ${BOOTDIR}/${currDestImage}"
    cp "${newSrceImage}" "${BOOTDIR}/${currDestImage}" ||
        gen_die "Could not copy the ${symlinkName} image to ${BOOTDIR}!"

    if [ "${SYMLINK}" = '1' ]
    then
        print_info 5 "  Make new symlink(s) (from ${BOOTDIR}):"
        print_info 5 "    ${symlinkName} -> ${currDestImage}"
        pushd ${BOOTDIR} >/dev/null
        ln -s "${currDestImage}" "${symlinkName}" ||
            gen_die "Could not create the ${symlinkName} symlink!"
        if [ "${prevDestImageExists}" = '1' ]
        then
            print_info 5 "    ${symlinkName}.old -> ${prevDestImage}"
            ln -s "${prevDestImage}" "${symlinkName}.old" ||
                gen_die "Could not create the ${symlinkName}.old symlink!"
        fi
        popd >/dev/null
    fi
}

#
# Helper function to allow command line arguments to override configuration
# file specified values and to apply defaults.
#
# Arguments:
#     $1  Argument type:
#           1  Switch type arguments (e.g., --color / --no-color).
#           2  Value type arguments (e.g., --debuglevel=5).
#     $2  Config file variable name.
#     $3  Command line variable name.
#     $4  Default.  If both the config file variable and the command line
#         option are not present, then the config file variable is set to
#         this default value.  Optional.
#
# The order of priority of these three sources (highest first) is:
#     Command line, which overrides
#     Config file (/etc/genkernel.conf), which overrides
#     Default.
#
# Arguments $2 and $3 are variable *names*, not *values*.  This function uses
# various forms of indirection to access the values.
#
# For switch type arguments, all forms of "True" are converted to a numeric 1
# and all forms of "False" (everything else, really) to a numeric 0.
#
# - JRG
#
set_config_with_override() {
    local VarType=$1
    local CfgVar=$2
    local OverrideVar=$3
    local Default=$4
    local Result

    #
    # Syntax check the function arguments.
    #
    case "$VarType" in
        BOOL|STRING)
            ;;
        *)
            gen_die "Illegal variable type \"$VarType\" passed to set_config_with_override()."
            ;;
    esac

    if [ -n "${!OverrideVar}" ]
    then
        Result=${!OverrideVar}
        if [ -n "${!CfgVar}" ]
        then
            print_info 5 "  $CfgVar overridden on command line to \"$Result\"."
        else
            print_info 5 "  $CfgVar set on command line to \"$Result\"."
        fi
    else
        if [ -n "${!CfgVar}" ]
        then
            Result=${!CfgVar}
            # we need to set the CMD_* according to configfile...
            eval ${OverrideVar}=\"${Result}\"
            print_info 5 "  $CfgVar set in config file to \"${Result}\"."
        else
            if [ -n "$Default" ]
            then
                Result=${Default}
                # set OverrideVar to Result, otherwise CMD_* may not be initialized...
                eval ${OverrideVar}=\"${Result}\"
                print_info 5 "  $CfgVar defaulted to \"${Result}\"."
            else
                print_info 5 "  $CfgVar not set."
            fi
        fi
    fi

    if [ "${VarType}" = BOOL ]
    then
        if isTrue "${Result}"
        then
            Result=1
        else
            Result=0
        fi
    fi

    eval ${CfgVar}=\"${Result}\"
}

check_distfiles() {
    for i in $BUSYBOX_SRCTAR $MULTIPATH_SRCTAR $ISCSI_SRCTAR $GPG_SRCTAR
    do
        if [ ! -f "${i}" ]
        then
            small_die "Could not find source tarball ${i}. Please refetch."
        fi
    done
}

find_kernel_binary() {
    local kernel_binary=$*
    local curdir=$(pwd)

    cd "${KERNEL_OUTPUTDIR}"
    for i in ${kernel_binary}
    do
        if [ -e "${i}" ]
        then
            tmp_kernel_binary=$i
            break
        fi
    done
#   if [ -z "${tmp_kernel_binary}" ]
#   then
#       gen_die "Cannot locate kernel binary!"
#   fi
    cd "${curdir}"
    echo "${tmp_kernel_binary}"
}

function kconfig_get_opt() {
	kconfig="$1"
	optname="$2"
	sed -n "${kconfig}" \
		-e "/^#\? \?${optname}[ =].*/{ s/.*${optname}[ =]//g; s/is not set\| +//g; p; q }"
}

function kconfig_set_opt() {
	kconfig="$1"
	optname="$2"
	optval="$3"
	sed -i "${kconfig}" \
		-e "s/^#\? \?${optname}[ =].*/${optname}=${optval}/g" \
	|| gen_die "Failed to set ${optname}=${optval} in $kconfig"
}
