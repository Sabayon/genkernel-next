#!/bin/sh

. /etc/initrd.d/00-common.sh

find_nfs() {
    if [ -z "${IP}" ]; then
        # IP is not set, return straight away
        return 1
    fi

    if ! udhcpc -n -T 15 -q; then
        bad_msg "udhcpc returned error, skipping nfs setup..."
        return 1
    fi

    local options=

    [ -e /rootpath ] && NFSROOT=$(cat /rootpath)
    if [ -z "${NFSROOT}" ]; then
        # Obtain NFSIP
        # TODO: this is bogus, because dmesg is a circular buffer...
        options=$(dmesg | grep rootserver | sed -e "s/,/ /g")

        local opt= optn=

        for opt in ${options}; do
            optn=$(echo $opt | sed -e "s/=/ /g" | cut -d " " -f 1)
            if [ "${optn}" = "rootserver" ]; then
                NFSIP=$(echo $opt | sed -e "s/=/ /g" | cut -d " " -f 2)
            fi
        done

        # Obtain NFSPATH
        # TODO: this is bogus, because dmesg is a circular buffer...
        options=$(dmesg | grep rootpath | sed -e "s/,/ /g")

        for opt in ${options}; do
            optn=$(echo $opt | sed -e "s/=/ /g" | cut -d " " -f 1)
            if [ "${optn}" = "rootpath" ]; then
                NFSPATH=$(echo $opt | sed -e "s/=/ /g" | cut -d " " -f 2)
            fi
        done

        # Setup NFSROOT
        if [ -n "${NFSIP}" ] && [ -n "$NFSPATH" ]; then
            NFSROOT="${NFSIP}:${NFSPATH}"
        else
            bad_msg "The DHCP Server did not send a valid root-path."
            bad_msg "Please check your DHCP setup, or set nfsroot=<...>"
            return 1
        fi
    fi

    # expecting a valid NFSROOT here, or the code should have returned
    NFSOPTIONS=${NFSROOT#*,}
    NFSROOT=${NFSROOT%%,*}
    if [ "${NFSOPTIONS}" = "${NFSROOT}" ]; then
        NFSOPTIONS="${DEFAULT_NFSOPTIONS}"
    else
        NFSOPTIONS="${DEFAULT_NFSOPTIONS},${NFSOPTIONS}"
    fi

    local path=
        # override path if on livecd
    if is_livecd; then
        path="${CDROOT_PATH}"
        good_msg "Attempting to mount NFS CD image on ${NFSROOT}."
    else
        path="${NEW_ROOT}"
        good_msg "Attempting to mount NFS root on ${NFSROOT}."
    fi

    good_msg "NFS options: ${NFSOPTIONS}"
    mount -t nfs -o ${NFSOPTIONS} "${NFSROOT}" "${path}"
    if [ "${?}" = "0" ]; then
        REAL_ROOT="/dev/nfs"
        return 0
    else
        bad_msg "NFS Mounting failed. Is the path corrent ?"
        return 1
    fi
}
