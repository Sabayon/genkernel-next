#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-fsdev.sh
. /etc/initrd.d/00-devmgr.sh

is_zfs() {
    # Note: this only works after zfs_real_root_init
    #       (thus, only after real_root_init)
    [ "${USE_ZFS}" = "1" ] && return 0
    return 1
}

# This piece of information can be used by external
# functions to return the default filesystem type
# for zfs members.
zfs_member_fstype() {
    echo "zfs_member"
}

is_zfs_fstype() {
    local fstype="${1}"
    [ "${fstype}" = "$(zfs_member_fstype)" ] && return 0
    return 1
}

zfs_real_root_init() {
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

    # Verify that zfs support has been compiled in
    if [ "${USE_ZFS}" = "1" ]; then
        for i in /sbin/zfs /sbin/zpool; do
            if [ ! -x "${i}" ]; then
                USE_ZFS=0
                bad_msg 'Aborting use of zfs because ${i} not found!'
                break
            fi
        done
    fi
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

zfs_start_volumes() {
    # is ZFS enabled?
    is_zfs || return 0

    # Avoid race involving asynchronous module loading
    if _call_func_timeout wait_for_zfs 5; then
        bad_msg "Cannot import ZFS pool because /dev/zfs is missing"

    elif [ -z "${ZFS_POOL}" ]; then
        good_msg "Importing ZFS pools"

        zpool import -N -a ${ZPOOL_FORCE}
        if [ "${?}" = "0" ]; then
            good_msg "Importing ZFS pools succeeded"
        else
            warn_msg "Imported ZFS pools failed"
        fi

    else
        local pools=$(zpool list -H -o name ${ZFS_POOL} 2>&1)
        if [ "${pools}" = "${ZFS_POOL}" ]; then
            good_msg "ZFS pool ${ZFS_POOL} already imported."

            if [ -n "${CRYPT_ROOTS}" ] || [ -n "${CRYPT_SWAPS}" ]; then
                good_msg "LUKS detected. Reimporting ${ZFS_POOL}"
                zpool export -f "${ZFS_POOL}"
                zpool import -N ${ZPOOL_FORCE} "${ZFS_POOL}"
            fi
        else
            good_msg "Importing ZFS pool ${ZFS_POOL}"
            zpool import -N ${ZPOOL_FORCE} "${ZFS_POOL}"

            if [ "${?}" = "0" ]; then
                good_msg "Import of ${ZFS_POOL} succeeded"
            else
                warn_msg "Import of ${ZFS_POOL} failed"
            fi
        fi
    fi

    is_udev && udevadm settle
}

# Initialize the zfs root filesystem device and
# tweak ${REAL_ROOT}. In addition, set ${ZFS_POOL}
# for later use.
# Return 0 if initialization is successful.
zfs_rootdev_init() {
    local root_dev="${REAL_ROOT#*=}"
    ZFS_POOL="${root_dev%%/*}"

    if [ "${root_dev}" != "ZFS" ]; then
        local ztype=$(zfs get type -o value -H "${root_dev}")
        if [ "${ztype}" = "filesystem" ]; then
            REAL_ROOT="${root_dev}"
            good_msg "Detected zfs root: ${REAL_ROOT}"
            return 0
        else
            bad_msg "${root_dev} is not a zfs filesystem"
            return 1
        fi
    fi

    local bootfs=$(zpool list -H -o bootfs)
    [ "${bootfs}" = "-" ] && return 1

    for i in ${bootfs}; do
        if zfs get type "${i}" > /dev/null; then
            REAL_ROOT="${i}"
            good_msg "Detected zfs bootfs root: ${REAL_ROOT}"
            return 0
        fi
    done
    return 1
}

zfs_get_real_root_mount_flags() {
    local flags=rw,zfsutil
    local zmtype=$(zfs get -H -o value mountpoint "${REAL_ROOT}")
    [ "${zmtype}" = "legacy" ] && flags=rw
    echo "${flags}"
}
