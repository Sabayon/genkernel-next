#!/bin/sh

. /etc/initrd.d/00-common.sh

is_zfs() {
    [ "${USE_ZFS}" = "1" ] && return 0
    return 1
}

# This helper function is to be called using _call_func_timeout.  This
# works around the inability of busybox modprobe to handle complex
# module dependencies. This also enables us to wait a reasonable
# amount of time until /dev/zfs appears.
wait_for_zfs() {
    while [ ! -c /dev/zfs ]; do modprobe zfs 2> /dev/null; done;
}

_call_func_timeout() {
    local func=$1 timeout=$2 pid watcher

    ( ${func} ) & pid=$!
    ( sleep ${timeout} && kill -HUP ${pid} ) 2>/dev/null & watcher=$!
    if wait ${pid} 2>/dev/null; then
        kill -HUP $watcher 2> /dev/null
        wait $watcher 2>/dev/null
        return 1
    fi

    return 0
}

zfs_init() {
    # Set variables based on the value of REAL_ROOT
    case "${REAL_ROOT}" in
        ZFS=*)
            ZFS_POOL=${REAL_ROOT#*=}
            ZFS_POOL=${ZFS_POOL%%/*}
            USE_ZFS=1
        ;;
        ZFS)
            USE_ZFS=1
        ;;
    esac

    # Verify that it is safe to use ZFS
    if [ "USE_ZFS" = "1" ]
    then
        for i in /sbin/zfs /sbin/zpool
        do
            if [ ! -x ${i} ]
            then
                USE_ZFS=0
                bad_msg 'Aborting use of zfs because ${i} not found!'
                break
            fi
        done
    fi
}

zfs_start_volumes() {
    # Avoid race involving asynchronous module loading
    if _call_func_timeout wait_for_zfs 5; then
        bad_msg "Cannot import ZFS pool because /dev/zfs is missing"

    elif [ -z "${ZFS_POOL}" ]; then
        good_msg "Importing ZFS pools"

        /sbin/zpool import -N -a ${ZPOOL_FORCE}
        if [ "${?}" = "0" ]; then
            good_msg "Importing ZFS pools succeeded"
        else
            bad_msg "Imported ZFS pools failed"
        fi

    else
        local pools=$(zpool list -H -o name ${ZFS_POOL} 2>&1)
        if [ "${pools}" = "${ZFS_POOL}" ]; then
            good_msg "ZFS pool ${ZFS_POOL} already imported."

            if [ -n "${CRYPT_ROOT}" ] || [ -n "${CRYPT_SWAP}" ]; then
                good_msg "LUKS detected. Reimporting ${ZFS_POOL}"
                /sbin/zpool export -f "${ZFS_POOL}"
                /sbin/zpool import -N ${ZPOOL_FORCE} "${ZFS_POOL}"
            fi
        else
            good_msg "Importing ZFS pool ${ZFS_POOL}"
            /sbin/zpool import -N ${ZPOOL_FORCE} "${ZFS_POOL}"

            if [ "${?}" = "0" ]; then
                good_msg "Import of ${ZFS_POOL} succeeded"
            else
                bad_msg "Import of ${ZFS_POOL} failed"
            fi
        fi
    fi
}