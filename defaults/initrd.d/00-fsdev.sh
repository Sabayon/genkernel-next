#!/bin/sh

. /etc/initrd.d/00-common.sh

mount_sysfs() {
    mount -t sysfs sysfs /sys -o noexec,nosuid,nodev \
        >/dev/null 2>&1 && return 0
    bad_msg "Failed to mount /sys!"
}

find_real_device() {
    local device="${1}"
    local out=
    case "${device}" in
        UUID=*|LABEL=*)
            local real_device=""
            local retval=1

            if [ "${retval}" -ne 0 ]; then
                real_device=$(findfs "${device}" 2>/dev/null)
                retval=$?
            fi

            if [ "$retval" -ne 0 ]; then
                real_device=$(busybox findfs "${device}" 2>/dev/null)
                retval=$?
            fi

            if [ "${retval}" -ne 0 ]; then
                real_device=$(blkid -o device -l -t "${device}")
                retval=$?
            fi

            if [ "${retval}" -eq 0 ] && [ -n "${real_device}" ]; then
                out="${real_device}"
            fi
        ;;
        *)
            out="${device}"
        ;;
    esac
    echo -n "${out}"
}

get_device_fstype() {
    local device=$(find_real_device "${1}")
    if [ -n "${device}" ]; then
        blkid -o value -s TYPE "${device}"
        return ${?}  # readability
    else
        bad_msg "Cannot resolve device: ${1}"
        return 1
    fi
}