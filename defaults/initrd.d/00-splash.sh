#!/bin/sh

splash() {
    return 0
}

[ -e "${INITRD_SPLASH}" ] && . "${INITRD_SPLASH}"

is_fbsplash() {
    if [ -e "${INITRD_SPLASH}" ] && [ "${FBSPLASH}" = '1' ]
    then
        return 0
    fi
    return 1
}

is_plymouth() {
    if [ "${PLYMOUTH}" = '1' ] && [ "${QUIET}" = '1' ] \
        && [ -e "${PLYMOUTHD_BIN}" ]
    then
        return 0
    fi
    return 1
}

is_plymouth_started() {
    [ -n "${PLYMOUTH_FAILURE}" ] && return 1
    is_plymouth && "${PLYMOUTH_BIN}" --ping 2>/dev/null && return 0
    return 1
}

splashcmd() {
    # plymouth support
    local cmd="${1}"
    shift

    case "${cmd}" in
        init)
        is_fbsplash && splash init
        is_plymouth && plymouth_init
        ;;

        verbose)
        is_fbsplash && splash verbose
        plymouth_hide
        ;;

        quiet)
        # no fbsplash support
        plymouth_show
        ;;

        set_msg)
        is_fbsplash && splash set_msg "${1}"
        plymouth_message "${1}"
        ;;

        hasroot)
        # no fbsplash support
        plymouth_newroot "${1}"
        ;;
    esac
}

plymouth_init() {
    good_msg "Enabling Plymouth"
    mkdir -p /run/plymouth || return 1

    # Make sure that udev is done loading tty and drm
    if is_udev
    then
        udevadm trigger --action=add --attr-match=class=0x030000 \
            >/dev/null 2>&1
        udevadm trigger --action=add --subsystem-match=graphics \
            --subsystem-match=drm --subsystem-match=tty \
            >/dev/null 2>&1
        udevadm settle
    fi

    local consoledev=
    local other=
    read consoledev other < /sys/class/tty/console/active
    consoledev=${consoledev:-tty0}
    "${PLYMOUTHD_BIN}" --attach-to-session --pid-file /run/plymouth/pid \
        || {
        bad_msg "Plymouth load error";
        PLYMOUTH_FAILURE=1
        return 1;
    }
    plymouth_show
    good_msg "Plymouth enabled"
}

plymouth_hide() {
    is_plymouth_started && "${PLYMOUTH_BIN}" --hide-splash
}

plymouth_show() {
    is_plymouth_started && "${PLYMOUTH_BIN}" --show-splash
}

plymouth_message() {
    is_plymouth_started && "${PLYMOUTH_BIN}" --update="${1}"
}

plymouth_newroot() {
    is_plymouth_started && "${PLYMOUTH_BIN}" --newroot="${1}"
}

splash_init() {
    if is_udev; then
        # if udev, we can load the splash earlier
        # In the plymouth case, udev will load KMS automatically
        splashcmd init
    fi
}