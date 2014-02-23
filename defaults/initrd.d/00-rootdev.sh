#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-splash.sh
. /etc/initrd.d/00-zfs.sh

_fstype_init() {
    local fstype="${1}"
    if [ "${fstype}" = "btrfs" ]; then
        # start BTRFS volume detection, if available
        [ -x /sbin/btrfs ] && /sbin/btrfs device scan
    elif [ -z "${fstype}" ]; then
        warn_msg "Unable to detect the filesystem type (empty variable)"
    fi
}

_rootdev_detect() {
    local got_good_root=0
    while [ "${got_good_root}" != "1" ]; do

        case "${REAL_ROOT}" in
            LABEL=*|UUID=*)
                local root_dev=$(find_real_device "${REAL_ROOT}")
                if [ -n "${root_dev}" ]; then
                    REAL_ROOT="${root_dev}"
                    good_msg "Detected root: ${REAL_ROOT}"
                else
                    bad_msg "Unable to resolve root: ${REAL_ROOT}"

                    got_good_root=0
                    prompt_user "REAL_ROOT" "root block device"
                    continue
                fi
                ;;

            ZFS*)
                # zfs_rootdev_init will tweak ${REAL_ROOT}
                zfs_rootdev_init
                if [ "${?}" = "0" ]; then
                    got_good_root=1
                else
                    got_good_root=0
                    prompt_user "REAL_ROOT" "root block device"
                    continue
                fi
                ;;
        esac

        if [ -z "${REAL_ROOT}" ]; then
            # No REAL_ROOT determined/specified.
            # Prompt user for root block device.
            prompt_user "REAL_ROOT" "root block device"
            got_good_root=0

        # Check for a block device, NFS or ZFS
        # Here we assume that zfs_rootdev_init has correctly
        # initialized ZFS volumes
        elif [ -b "${REAL_ROOT}" ] || is_nfs || is_zfs; then
            got_good_root=1
        else
            bad_msg "${REAL_ROOT} is an invalid root device..."
            REAL_ROOT=""
            got_good_root=0
        fi
    done

    return 0
}

_rootdev_mount() {
    local mount_opts=ro
    local mount_fstype="${ROOTFSTYPE}"
    local fstype=$(get_device_fstype "${REAL_ROOT}")

    # handle ZFS special case. Thanks to Jordan Patterson
    # for reporting this.
    if [ -z "${fstype}" ] && is_zfs; then
        # here we assume that if ${fstype} is empty
        # and ZFS is enabled, we may well force the
        # fstype value to zfs_member
        fstype=$(zfs_member_fstype)
    fi

    if is_zfs_fstype "${fstype}"; then
        [ -z "${mount_fstype}" ] && mount_fstype=zfs
        mount_opts=$(zfs_get_real_root_mount_flags)
    fi

    [ -z "${mount_fstype}" ] && mount_fstype="${fstype}"

    good_msg "Detected fstype: ${fstype}"
    good_msg "Using mount fstype: ${mount_fstype}"
    _fstype_init "${fstype}"

    local mopts="${mount_opts}"
    [ -n "${REAL_ROOTFLAGS}" ] && \
        mopts="${mopts},${REAL_ROOTFLAGS}"
    good_msg "Using mount opts: -o ${mopts}"

    mount -t "${mount_fstype}" -o "${mopts}" \
        "${REAL_ROOT}" "${NEW_ROOT}" && return 0

    bad_msg "Cannot mount ${REAL_ROOT}, trying with -t auto"
    mount -t "auto" -o "${mopts}" \
        "${REAL_ROOT}" "${NEW_ROOT}" && return 0

    bad_msg "Cannot mount ${REAL_ROOT} with -t auto, giving up"

    return 1
}

_get_mounts_list() {
    awk '
        /^[[:blank:]]*#/ { next }
        { print $1 }
        ' ${NEW_ROOT}/etc/initramfs.mounts
}

_get_mount_fstype() {
    [ -e "${NEW_ROOT}"/etc/fstab ] || return 1
    awk -v fs="$1" '
        /^[[:blank:]]*#/ { next }
        $2 == fs { print $3 }
        ' ${NEW_ROOT}/etc/fstab
}

_get_mount_options() {
    [ -e "${NEW_ROOT}"/etc/fstab ] || return 1
    awk -v fs="$1" '
        /^[[:blank:]]*#/ { next }
        $2 == fs { print $4 }
        ' ${NEW_ROOT}/etc/fstab
}

_get_mount_device() {
    [ -e "${NEW_ROOT}"/etc/fstab ] || return 1
    awk -v fs="$1" '
        /^[[:blank:]]*#/ { next }
        $2 == fs { print $1 }
        ' ${NEW_ROOT}/etc/fstab
}

# If the kernel is handed a mount option is does not recognize, it
# WILL fail to mount. util-linux handles auto/noauto, but busybox
# passes it straight to the kernel which then rejects the mount.  To
# make like a little easier, busybox mount does not care about
# leading, trailing or duplicate commas.
_strip_mount_options() {
    sed -r 's/(,|^)(no)?auto(,|$)/,/g'
}

real_root_init() {
    if [ -z "${REAL_ROOT}" ] && [ "${FAKE_ROOT}" != "/dev/ram0" ]; then
        REAL_ROOT="${FAKE_ROOT}"
    fi

    if [ -z "${REAL_ROOTFLAGS}" ]; then
        REAL_ROOTFLAGS="${FAKE_ROOTFLAGS}"
    fi
}

real_init_init() {
    local default_init="/sbin/init"
    if [ -z "${REAL_INIT}" ] && [ -z "${FAKE_INIT}" ]; then
        # if none of REAL_INIT and FAKE_INIT are set, default
        # to ${default_init}
        REAL_INIT="${default_init}"
    elif [ -z "${REAL_INIT}" ]; then
        if [ "${FAKE_INIT}" = "/linuxrc" ]; then
            # if init=/linuxrc is given, ignore linuxrc
            # this is for backward compatibility with very old setups
            REAL_INIT="${default_init}"
        else
            REAL_INIT="${FAKE_INIT}"
        fi
    fi
}

# Read /etc/initramfs.mounts from ${NEW_ROOT} and mount the
# listed filesystem mountpoints. For instance, /usr, which is
# required by udev & systemd.
ensure_initramfs_mounts() {
    local fslist=

    if [ -f "${NEW_ROOT}/etc/initramfs.mounts" ]; then
        fslist="$(_get_mounts_list)"
    else
        fslist="/usr"
    fi

    local dev= fstype= opts= mnt= cmd=
    for fs in ${fslist}; do

        mnt="${NEW_ROOT}${fs}"
        if mountpoint -q "${mnt}"; then
            good_msg "${fs} already mounted, skipping..."
            continue
        fi

        dev=$(_get_mount_device "${fs}")
        [ -z "${dev}" ] && continue
        # Resolve it like util-linux mount does
        [ -L "${dev}" ] && dev=$(realpath "${dev}")
        # In this case, it's probably part of the filesystem
        # and not a mountpoint
        [ -z "${dev}" ] && continue

        fstype=$(_get_mount_fstype "${fs}")
        if _get_mount_options "${fs}" | fgrep -q bind; then
            opts="bind"
            dev="${NEW_ROOT}${dev}"
        else
            # ro must be trailing, and the options will always
            # contain at least 'defaults'
            opts="$(_get_mount_options ${fs} | _strip_mount_options)"
            opts="${opts},ro"
        fi

        cmd="mount -t ${fstype} -o ${opts} ${dev} ${mnt}"
        good_msg "Mounting ${dev} as ${fs}: ${cmd}"
        if ! ${cmd}; then
            bad_msg "Unable to mount ${dev} for ${fs}"
        fi
    done
}

rootdev_init() {
    good_msg "Initializing root device..."

    while true; do

        if ! _rootdev_detect; then
            bad_msg "Could not mount specified ROOT, try again"
            prompt_user "REAL_ROOT" "root block device"
            continue
        fi

        if is_livecd && ! is_nfs; then
            # CD already mounted; no further checks necessary
            break
        fi
        if [ "${LOOPTYPE}" = "sgimips" ]; then
            # sgimips mounts the livecd root partition directly
            # there is no isofs filesystem to worry about
            break
        fi

        good_msg "Mounting ${REAL_ROOT} as root..."

        # Try to mount the device as ${NEW_ROOT}
        local out=1
        if is_nfs; then
            find_nfs && out=0
        else
            _rootdev_mount && out=0
        fi

        if [ "${out}" != "0" ]; then
            bad_msg "Could not mount specified ROOT, try again"
            prompt_user "REAL_ROOT" "root block device"
            continue
        fi

        # now that the root filesystem is mounted, before
        # checking the validity of ${NEW_ROOT} and ${REAL_INIT},
        # ensure that ${NEW_ROOT}/etc/initramfs.mounts entries
        # are mounted.
        ensure_initramfs_mounts

        # NFS does not need further checks here.
        is_nfs && break

        if [ ! -d "${NEW_ROOT}/dev" ]; then
            _msg="The filesystem ${REAL_ROOT},"
            _msg="${_msg} mounted at ${NEW_ROOT}"
            _msg="${_msg} does not contain /dev"
            _msg="${_msg}, init will likely fail..."
            bad_msg "${_msg}"
            prompt_user "REAL_ROOT" "root block device"
            continue
        fi
        if [ ! -x "${NEW_ROOT}${REAL_INIT}" ]; then
            _msg="The filesystem ${REAL_ROOT},"
            _msg="${_msg} mounted at ${NEW_ROOT}"
            _msg="${_msg} does not contain a valid"
            _msg="${_msg} init=${REAL_INIT}"
            bad_msg "${_msg}"
            prompt_user "REAL_ROOT" "root block device"
            continue
        fi
        break
    done
}
