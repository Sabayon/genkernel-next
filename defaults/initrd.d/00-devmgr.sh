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
        "${UDEVD}" --daemon --resolve-names=never && \
            udevadm trigger --action=add && \
            udevadm settle || bad_msg "udevd failed to run"
    elif is_mdev; then
        good_msg "Activating mdev"
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

_fs_type_in_use() {
    local fs_type=${1}
    cut -d " " -f 3 < /proc/mounts | fgrep -q "${fs_type}"
}

mount_devfs() {
    # Use devtmpfs if enabled in kernel,
    # else tmpfs. Always run mdev just in case
    local devfs=tmpfs
    if grep -qs devtmpfs /proc/filesystems ; then
        devfs=devtmpfs
    fi

    # Options copied from /etc/init.d/udev-mount
    # should probably be kept in sync
    if ! _fs_type_in_use devtmpfs; then
        mount -t "${devfs}" -o "exec,nosuid,mode=0755,size=10M" \
            udev /dev || bad_msg "Failed to mount /dev as ${devfs}"
    fi

    # http://git.busybox.net/busybox/plain/docs/mdev.txt
    if ! _fs_type_in_use devpts; then
        mkdir -m 0755 /dev/pts
        mount -t devpts -o gid=5,mode=0620 devpts /dev/pts \
            || bad_msg "Failed to mount /dev/pts"
    fi

    mkdir -p -m 1777 /dev/shm
    mount -t tmpfs -o mode=1777,nosuid,nodev,strictatime tmpfs \
        /dev/shm || bad_msg "Failed to mount /dev/shm"
}

device_list() {
    # Locate the cdrom device with our media on it.
    # CDROM devices
    local devices="/dev/cdroms/* /dev/ide/cd/* /dev/sr*"
    # USB Keychain/Storage
    devices="${devices} /dev/sd*"
    # IDE devices
    devices="${devices} /dev/hd*"
    # virtio devices
    devices="${devices} /dev/vd*"
    # USB using the USB Block Driver
    devices="${devices} /dev/ubd* /dev/ubd/*"
    # iSeries devices
    devices="${devices} /dev/iseries/vcd*"
    # builtin mmc/sd card reader devices
    devices="${devices} /dev/mmcblk* /dev/mmcblk*/*"

    # fallback scanning, this might scan something twice, but it's better than
    # failing to boot.
    local parts=$(awk '/([0-9]+[[:space:]]+)/{print "/dev/" $4}' \
        /proc/partitions)
    [ -e /proc/partitions ] && devices="${devices} ${parts}"

    echo ${devices}
}
