#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-devmgr.sh


_modules_load() {
    for module in ${*}; do
        echo ${module} >> /etc/modules/extra_load
    done
    _modules_scan extra_load
}

_modules_scan() {
    local mods
    local loaded

    mods=$(cat /etc/modules/${1} 2>/dev/null)
    [ -n "${mods}" ] && [ -z "${QUIET}" ] && \
        echo -ne "${BOLD}   ::${NORMAL} Loading from ${1}: "

    for x in ${mods}; do
        local mload=$(echo ${MLIST} | sed -e "s/.*${x}.*/${x}/")
        if [ "${mload}" = "${x}" ]; then
            # Only module to no-load
            [ -z "${QUIET}" ] && \
                echo -e "${BOLD}   ::${NORMAL} Skipping ${x}..."
        elif [ "${mload}" = "${MLIST}" ]; then
            if [ -n "${DEBUG}" ]; then
                echo -ne "${BOLD}   ::${NORMAL} "
                echo -ne "Scanning for ${x}..."
            fi
            modprobe ${x} > /dev/null 2>&1
            loaded=${?}

            [ -n "${DEBUG}" -a "${loaded}" = "0" ] && \
                echo "loaded"
            [ -n "${DEBUG}" -a "${loaded}" != "0" ] && \
                echo "not loaded"

            [ -z "${DEBUG}" -a "${loaded}" = "0" ] && \
                [ -z "${QUIET}" ] && \
                echo -en "${x} "
        else
            [ -z "${QUIET}" ] && \
                echo -e "${BOLD}   ::${NORMAL} Skipping ${x}..."
        fi
    done
    [ -n "${mods}" ] && [ -z "${QUIET}" ] && echo
}

modules_init() {
    if [ -z "${DO_modules}" ]; then
        good_msg 'Skipping module load; disabled via commandline'
    elif [ -d "/lib/modules/${KV}" ]; then
        good_msg 'Loading modules'
        # Load appropriate kernel modules
        if [ "${NODETECT}" != "1" ]; then
            for modules in ${MY_HWOPTS}; do
                _modules_scan ${modules}
            done
        fi
        # Always eval doload=...
        _modules_load ${MDOLIST}
    else
        good_msg 'Skipping module load; no modules in the ramdisk!'
    fi

    # Give udev time to execute all the rules. This may be beneficial
    # for usb-storage devices.
    is_udev && udevadm settle
}

cmdline_hwopts() {
    # Scan CMDLINE for any "doscsi" or "noscsi"-type arguments
    for x in ${HWOPTS}; do
        for y in ${CMDLINE}; do
            if [ "${y}" = "do${x}" ]; then
                MY_HWOPTS="${MY_HWOPTS} $x"
            elif [ "${y}" = "no${x}" ]; then
                MY_HWOPTS="$(echo ${MY_HWOPTS} | sed -e \"s/${x}//g\" -)"
            fi
        done
    done

    local tmp_hwopts
    for x in ${MY_HWOPTS}; do
        local found=0
        for y in ${tmp_hwopts}; do
            if [ "${y}" = "${x}" ]; then
                continue 2
            fi
        done
        tmp_hwopts="${tmp_hwopts} ${x}"
        eval DO_$(echo ${x} | sed 's/-//')=1
    done

    MY_HWOPTS="${tmp_hwopts}"
}
