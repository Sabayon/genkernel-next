#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-devmgr.sh

mount_sysfs() {
    mount -t sysfs sysfs /sys -o noexec,nosuid,nodev \
        >/dev/null 2>&1 && return 0
    bad_msg "Failed to mount /sys!"
}

# If devtmpfs is mounted, try move it to the new root
# If that fails, try to unmount all possible mounts of devtmpfs as
# stuff breaks otherwise
move_mounts_to_chroot() {
    for fs in /run /dev /sys /proc; do
        if grep -qs "$fs" /proc/mounts; then
            local chroot_dir="${CHROOT}${fs}"
            mkdir -p "${chroot_dir}"
            if ! mount --move $fs "${chroot_dir}"
            then
                umount $fs || \
                bad_msg "Failed to move and umount $fs!"
            fi
        fi
    done
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

media_find() {
    # $1 = mount dir name / media name
    # $2 = recognition file
    # $3 = variable to have the device path
    # $4 = actual mount dir path (full path)
    # args remaining are possible devices

    local media="${1}" recon="${2}" vrbl="${3}" mntdir="${4}"
    shift 4

    good_msg "Looking for the ${media}"

    if [ "$#" -gt "0" ]; then

        [ ! -d "${mntdir}" ] && \
            mkdir -p "${mntdir}" 2>/dev/null >/dev/null

        local mntcddir="${mntdir}"
        if [ -n "${ISOBOOT}" ]; then
            mntcddir="${mntdir%${media}}iso"
            if [ ! -f "${mntcddir}" ]; then
                mkdir "${mntcddir}"
            fi
        fi

        for x in ${*}; do

            # Check for a block device to mount
            if [ ! -b "${x}" ]; then
                continue
            fi

            #
            # If disk and it has at least one partition, skip.
            # We use /sys/block/${bsn}/${bsn}[0-9]* to make sure that we
            # don't skip device mapper devices. Even the craziest scenario
            # deserves a fair chance.
            #
            local bsn=$(basename "${x}")
            local bpath="/sys/block/${bsn}"
            local parts=$(find "${bpath}/" \
                -regex "${bpath}/${bsn}[0-9]" -type d 2>/dev/null)
            [ -n "${parts}" ] && continue

            good_msg "Attempting to mount media: ${x}"
            mount -r -t "${CDROOT_TYPE}" "${x}" "${mntcddir}" >/dev/null 2>&1 \
                || continue

            if [ -n "${ISOBOOT}" ] && [ -f "${mntcddir}/${ISOBOOT}" ]; then
                mount -o loop "${mntcddir}/${ISOBOOT}" "${mntdir}" && \
                    good_msg "iso mounted on ${mntdir}"
            fi

            # Check for the media
            if [ -f "${mntdir}/${recon}" ]; then
                # Set REAL_ROOT, CRYPT_ROOT_KEYDEV or whatever ${vrbl} is
                eval ${vrbl}'='"${x}"
                good_msg "Media found on ${x}"
                break
            else
                umount "${mntcddir}"
            fi
        done
    fi

    eval local result='$'${vrbl}

    [ -n "${result}" ] || bad_msg "Media not found"
}

setup_md_device() {
    if ! is_mdev; then
        # mdev requires manual device node creation, while udev doesn't
        # make sure that all the udev events are complete
        is_udev && udevadm settle
        return 0
    fi

    local device=

    [ -n "${1}" ] && device="${1}"
    [ -z "${1}" ] && device="${REAL_ROOT}"
    [ -z "${device}" ] && return 0

    local md_dev=$(echo ${device} | sed -e \
        's#\(luks:\)\?\(/dev/md\)[[:digit:]]\+#\2#')
    if [ "${md_dev}" = "/dev/md" ]; then
        good_msg 'Detected root as a md device. Setting up the device node...'

        local md_number=$(echo ${device} | sed -e \
            's#\(luks:\)\?/dev/md\([[:digit:]]\+\)#\2#')
        if [ ! -e "/dev/md${md_number}" ]; then
            mknod "/dev/md${md_number}" b 9 "${md_number}" >/dev/null 2>&1
            [ $? -ne 0 ] && bad_msg "Creation of /dev/md${md_number} failed..."
        fi
        mdstart ${MDPART} "/dev/md${md_number}"
    fi
}

start_md_volumes() {
    good_msg "Starting md devices"
    mdadm --assemble --scan
    # do not bad_msg, user could have this enabled even though
    # no RAID is currently available.
}

start_volumes() {
    # Here, we check for /dev/device-mapper, and if it exists, we setup a
    # a symlink, which should hopefully fix bug #142775 and bug #147015
    if [ -e /dev/device-mapper ] && [ ! -e /dev/mapper/control ]; then
        mkdir -p /dev/mapper
        ln -sf /dev/device-mapper /dev/mapper/control
    fi

    if [ "${USE_MDADM}" = "1" ]; then
        start_md_volumes
    fi

    if [ "${USE_MULTIPATH_NORMAL}" = "1" ]; then
        good_msg "Scanning for multipath devices"
        multipath -v 0
        # TODO(lxnay): horrible sleep!
        sleep 2
        good_msg "Activating multipath devices"
        dmsetup ls --target multipath --exec "/sbin/kpartx -a -v"
    fi

    if [ "${USE_DMRAID_NORMAL}" = "1" ]; then
        good_msg "Activating device-mapper raid devices"
        dmraid -ay ${DMRAID_OPTS} || \
            bad_msg "dmraid failed to run, skipping raid assembly!"
    fi

    if [ "${USE_LVM_NORMAL}" = "1" ]; then

        for dev in ${RAID_DEVICES}; do
            setup_md_device "${dev}"
        done

        # This is needed for /sbin/lvm to accept the following logic
        local cmds="#! /sbin/lvm"

        # If there is a cahe, update it. Unbreak at least dmcrypt
        [ -d /etc/lvm/cache ] && cmds="${cmds} \nvgscan"

        # To activate volumegroups on all devices in the cache
        cmds="${cmds} \nvgchange -ay --sysinit"
        if is_mdev; then
            # To create symlinks so users can use
            # real_root=/dev/vg/root
            # This needs to run after vgchange, using
            # vgchange --mknodes is too early.
            cmds="${cmds} \nvgmknodes --ignorelockingfailure"
        fi

        # And finally execute it all (/proc/... needed if lvm
        # is compiled without readline)
        good_msg "Activating Logical Volume Groups"
        printf "%b\n" "${cmds}" | lvm /proc/self/fd/0 || \
            bad_msg "lvm failed to run, cannot activate logical volumes!"

    fi

    is_udev && udevadm settle
}
