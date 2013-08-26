#!/bin/sh

. /etc/initrd.d/00-common.sh

is_udev() {
    [ -x "${UDEVD}" ] && [ -z "${USE_MDEV}" ] && return 0
    return 1
}

is_mdev() {
    if [ ! -x "${UDEVD}" ] || [ -n "${USE_MDEV}" ]; then
        return 0
    fi
    return 1
}

devmgr_init() {
    if is_udev; then
        good_msg "Activating udev"
        echo "${UDEVD}" > /proc/sys/kernel/hotplug
        echo "" > /sys/kernel/uevent_helper
        "${UDEVD}" --daemon --resolve-names=never && \
            udevadm trigger --action=add && \
            udevadm settle || bad_msg "udevd failed to run"
    elif is_mdev; then
        good_msg "Activating mdev"
        # Serialize hotplug events
        touch /dev/mdev.seq
        echo "${MDEVD}" > /proc/sys/kernel/hotplug
        # Ensure that device nodes are properly configured
        "${MDEVD}" -s || bad_msg "mdev -s failed"
    else
        bad_msg "Cannot find either udev or mdev"
    fi
}

# Terminate the device manager, this happens right before pivot_root
devmgr_terminate() {
    if is_udev; then
        udevadm settle
        udevadm control --exit || bad_msg "Unable to terminate udevd"
    fi
    # mdev doesn't require anything, it seems
}
