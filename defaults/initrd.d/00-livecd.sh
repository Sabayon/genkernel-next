#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-devmgr.sh


_is_aufs() {
    [ "${USE_AUFS}" = "1" ] && return 0
    return 1
}

_find_loop() {
    local l=
    for loop in ${LOOPS}; do
        if [ -e "${CDROOT_PATH}${loop}" ]; then
            l="${loop}"
            # preserve the old behaviour, don't break
        fi
    done
    echo "${l}"
}

_find_looptype() {
    local lt="${LOOP##*.}"
    [ "${lt}" = "loop" ] && lt="normal"
    [ "${LOOP}" = "/zisofs" ] && lt="${LOOP#/}"
    [ -z "${lt}" ] && lt="noloop"
    echo "${lt}"
}

_setup_squashfs_aufs() {
    # Setup aufs directories and vars
    local overlay=/mnt/overlay
    local static=/mnt/livecd

    for i in "${overlay}" "${static}"; do
        [ ! -d "${i}" ] && mkdir -p "${i}"
    done
    good_msg "Loading aufs"
    modprobe aufs > /dev/null 2>&1

    mount -t squashfs -o loop,ro "${CDROOT_PATH}/${LOOPEXT}${LOOP}" \
        "${static}"
    mount -t tmpfs none "${overlay}"
    mount -t aufs -o br:${overlay}:${static} aufs "${NEW_ROOT}"

    [ ! -d "${NEW_ROOT}${overlay}" ] && mkdir -p "${NEW_ROOT}${overlay}"
    [ ! -d "${NEW_ROOT}${static}" ] && mkdir -p "${NEW_ROOT}${static}"
    echo "aufs / aufs defaults 0 0" > "${NEW_ROOT}"/etc/fstab
    for i in "${overlay}" "${static}"; do
        mount --move "${i}" "${NEW_ROOT}${i}"
    done

    # have handy /mnt/cdrom (CDROOT_PATH) as well
    local new_cdroot="${NEW_ROOT}${CDROOT_PATH}"
    [ ! -d "${new_cdroot}" ] && mkdir -p "${new_cdroot}"
    mount --bind "${CDROOT_PATH}" "${new_cdroot}"
}

_bootstrap_cd() {
    local devices=

    # The device was specified on the command line, so there's no need
    # to scan a bunch of extra devices
    [ -n "${CDROOT_DEV}" ] && devices="${CDROOT_DEV}"
    [ -z "${CDROOT_DEV}" ] && devices=$(device_list)

    media_find "cdrom" "${SUBDIR}/${CDROOT_MARKER}" \
        "REAL_ROOT" "${CDROOT_PATH}" ${devices}
}

_check_loop() {
    if [ -z "${LOOP}" ] || [ ! -e "${CDROOT_PATH}/${LOOP}" ]; then
        bad_msg "Invalid loop location: ${LOOP}"
        bad_msg "Please export LOOP with a valid location"
        bad_msg "or reboot and pass a proper loop=..."
        bad_msg "kernel command line"
        run_shell
    fi
}

_cache_cd_contents() {
    # Check loop file exists and cache to ramdisk if DO_cache is enabled
    if [ "${LOOPTYPE}" != "noloop" ] && \
        [ "${LOOPTYPE}" != "sgimips" ]; then

        _check_loop
        if [ "${DO_cache}" ]; then
            # TODO: Check the size of the image versus the size of our tmpfs
            # along with the amount of available RAM and increase tmpfs size
            # if necessary. (Not having awk sucks...)
            # z=0
            # for i in $(cat /proc/meminfo | grep -e ^MemFree -e ^Cached | \
            # cut -d: -f2 | cut -dk -f1 | sed -e "s/^\s*//") ; do
            # z=$(($z + $i)) ; done
            # echo $z
            good_msg "Copying loop file for caching..."
            # Verify that the needed directory exists
            mkdir -p "$(dirname ${NEW_ROOT}/mnt/${LOOP})"

            cp -a "${CDROOT_PATH}/${LOOP}" "${NEW_ROOT}/mnt/${LOOP}"
            if [ "${?}" != "0" ]; then
                warn_msg "Failed to cache the loop file! Lack of RAM?"
                rm -rf "${NEW_ROOT}/mnt/${LOOP}" 2>/dev/null
                rm -rf "${NEW_ROOT}"/mnt/livecd.* 2>/dev/null
                rm -rf "${NEW_ROOT}"/mnt/image.* 2>/dev/null
                rm -rf "${NEW_ROOT}"/mnt/zisofs 2>/dev/null
            fi
        fi
    fi
}

# Unpack additional packages from NFS mount
# This is useful for adding kernel modules to /lib
# We do this now, so that additional packages can add whereever
# they want.
_livecd_mount_unpack_nfs() {
    if [ -e "${CDROOT_PATH}/add" ]; then
        for targz in $(ls "${CDROOT_PATH}"/add/*.tar.gz); do
            tarname=$(basename "${targz}")
            good_msg "Adding additional package ${tarname}"
            (
                cd "${NEW_ROOT}" && /bin/tar -xzf "${targz}"
            )
        done
    fi
}

_livecd_mount_sgimips() {
    # getdvhoff finds the starting offset (in bytes) of the squashfs
    # partition on the cdrom and returns this offset for losetup
    #
    # All currently supported SGI Systems use SCSI CD-ROMs, so
    # so we know that the CD-ROM is usually going to be /dev/sr0.
    #
    # We use the value given to losetup to set /dev/loop0 to point
    # to the liveCD root partition, and then mount /dev/loop0 as
    # the LiveCD rootfs
    good_msg "Locating the SGI LiveCD root partition"
    echo " " | \
        losetup -o $(getdvhoff "${NEW_ROOT}${REAL_ROOT}" 0) \
            "${NEW_ROOT}${CDROOT_DEV}" \
            "${NEW_ROOT}${REAL_ROOT}"
    test_success "losetup /dev/sr0 /dev/loop0"

    good_msg "Mounting the root partition"
    mount -t squashfs -o ro "${NEW_ROOT}${CDROOT_DEV}" \
        "${NEW_ROOT}/mnt/livecd"
    test_success "mount /dev/loop0 /"
}

_livecd_mount_gcloop() {
    good_msg "Mounting gcloop filesystem"
    echo " " | losetup -E 19 -e ucl-0 -p0 \
        "${NEW_ROOT}/dev/loop0" \
        "${CDROOT_PATH}/${LOOPEXT}${LOOP}"
    test_success "losetup the loop device"

    mount -t ext2 -o ro "${NEW_ROOT}/dev/loop0" "${NEW_ROOT}/mnt/livecd"
    test_success "Mount the losetup loop device"
}

_livecd_mount_normal() {
    good_msg "Mounting loop filesystem"
    mount -t ext2 -o loop,ro \
        "${CDROOT_PATH}/${LOOPEXT}${LOOP}" \
        "${NEW_ROOT}/mnt/livecd"
    test_success "Mount filesystem"
}

_livecd_mount_squashfs() {
    # if AUFS, redirect to the squashfs+aufs setup function
    if _is_aufs; then
        good_msg "Mounting squashfs & aufs filesystems"
        _setup_squashfs_aufs
        test_success "Mount filesystem"
        return  # preserve old behaviour
    fi

    good_msg "Mounting squashfs filesystem"
    local cached_squashfs_path="${NEW_ROOT}/mnt/${LOOP}"
    local squashfs_path="${CDROOT_PATH}/${LOOPEXT}${LOOP}"

    # Upgrade to cached version if possible
    if [ -n "${DO_cache}" ] && [ -f "${cached_squashfs_path}" ]; then
        squashfs_path="${cached_squashfs_path}"
    fi

    mount -t squashfs -o loop,ro "${squashfs_path}" \
        "${NEW_ROOT}/mnt/livecd" || {
        bad_msg "squashfs filesystem could not be mounted."
        do_rundebugshell
    }
}

# Manually copy livecd read-only content into the final livecd root
# filesystem directory, which has been mounted as tmpfs.
_livecd_mount_copy_content() {
    local fs_loc="${NEW_ROOT}/${FS_LOCATION}"

    good_msg "Copying read-write image contents to tmpfs"
    # Copy over stuff that should be writable
    (
        cd "${fs_loc}" && cp -a ${ROOT_TREES} "${NEW_ROOT}"
    ) || {
        bad_msg "Copy failed, dropping into a shell."
        do_rundebugshell
    }

    # Now we do the links.
    for x in ${ROOT_LINKS}; do

        if [ -L "${fs_loc}/${x}" ]; then
            ln -s "$(readlink ${fs_loc}/${x})" "${x}" 2>/dev/null
            continue
        fi

        # List all subdirectories of x
        find "${fs_loc}/${x}" -type d 2>/dev/null | \
            while read directory; do

            # Strip the prefix of the FS_LOCATION
            directory="${directory#${fs_loc}/}"

            # Skip this directory if we already linked a parent
            # directory
            if [ -z "${current_parent}" ]; then
                var=$(echo "${directory}" | \
                    grep "^${current_parent}")
                if [ -z "${var}" ]; then
                    continue
                fi
            fi

            local root_d="${NEW_ROOT}/${directory}"
            local fsloc_d="${FS_LOCATION}/${directory}"

            # Test if the directory exists already
            if [ ! -e "/${root_d}" ]; then
                # It does not exist, make a link to the livecd
                ln -s "/${FS_LOCATION}/${directory}" \
                    "${directory}" 2>/dev/null
                current_parent="${directory}"
                continue
            fi

            # It does exist, link all the individual files
            local fs_d="/${fs_loc}/${directory}"

            for file in $(ls "${fs_d}"); do
                [ -d "${fs_d}/${file}" ] && continue
                [ -e "${root_d}/${file}" ] && continue

                ln -s "/${fsloc_d}/${file}" \
                    "${directory}/${file}" 2> /dev/null
            done

        done

    done

    mkdir initramfs proc tmp sys run 2>/dev/null
    chmod 1777 tmp

    # have handy /mnt/cdrom (CDROOT_PATH) as well
    local new_cdroot="${NEW_ROOT}${CDROOT_PATH}"
    [ ! -d "${new_cdroot}" ] && mkdir -p "${new_cdroot}"
    mount --bind "${CDROOT_PATH}" "${new_cdroot}"
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

livecd_init() {
    good_msg "Making tmpfs for ${NEW_ROOT}"
    mount -n -t tmpfs -o mode=0755 tmpfs "${NEW_ROOT}"

    local dirs=

    dirs="dev mnt proc run sys tmp mnt/livecd"
    dirs="${dirs} mnt/key tmp/.initrd mnt/gentoo"
    for i in ${dirs}; do
        mkdir -p "${NEW_ROOT}/${i}"
        chmod 755 "${NEW_ROOT}/${i}"
    done
    [ ! -d "${CDROOT_PATH}" ] && mkdir -p "${CDROOT_PATH}"
    [ ! -e "${NEW_ROOT}/dev/null" ] && mknod "${NEW_ROOT}"/dev/null c 1 3
    [ ! -e "${NEW_ROOT}/dev/console" ] && \
        mknod "${NEW_ROOT}"/dev/console c 5 1

    # For SGI LiveCDs ...
    if [ "${LOOPTYPE}" = "sgimips" ]; then
        [ ! -e "${NEW_ROOT}/dev/sr0" ] && \
            mknod "${NEW_ROOT}/dev/sr0" b 11 0
        [ ! -e "${NEW_ROOT}/dev/loop0" ] && \
            mknod "${NEW_ROOT}/dev/loop0" b 7 0
    fi

    # Required for splash to work.  Not an issue with the initrd as this
    # device isn't created there and is not needed.
    if [ -e /dev/tty1 ]; then
        [ ! -e "${NEW_ROOT}/dev/tty1" ] && \
            mknod "${NEW_ROOT}/dev/tty1" c 4 1
    fi

    if ! is_nfs && [ "${LOOPTYPE}" != "sgimips" ]; then
        _bootstrap_cd
    fi

    if [ -z "${REAL_ROOT}" ]; then
        warn_msg "No bootable medium found. Waiting for new devices..."
        local cnt=0
        while [ ${cnt} -lt 3 ]; do
            sleep 3
            let cnt=${cnt}+1
        done
        sleep 1
        _bootstrap_cd
    fi

    if [ -z "${REAL_ROOT}" ]; then
        # leave stale mounts around, make possible to debug
        bad_msg "Could not find CD to boot, something else needed"
        CDROOT=0
    fi
}

livecd_mount() {
    # Let Init scripts know that we booted from CD
    export CDBOOT
    CDBOOT=1

    good_msg "Determining looptype ..."
    cd "${NEW_ROOT}"

    # Find loop and looptype
    [ -z "${LOOP}" ] && LOOP=$(_find_loop)
    [ -z "${LOOPTYPE}" ] && LOOPTYPE=$(_find_looptype)

    _cache_cd_contents

    # If encrypted, find key and mount, otherwise mount as usual
    if [ -n "${CRYPT_ROOT}" ]; then
        CRYPT_ROOT_KEY=$(head -n 1 "${CDROOT_PATH}/${CDROOT_MARKER}")
        CRYPT_ROOT="/dev/loop0"
        good_msg "You booted an encrypted livecd"

        losetup /dev/loop0 "${CDROOT_PATH}/${LOOPEXT}${LOOP}"
        test_success "Preparing loop filesystem"

        # TODO(lxnay): start_luks is still in livecd.scripts
        start_luks

        case ${LOOPTYPE} in
            normal)
                MOUNTTYPE="ext2"
                ;;
            *)
                MOUNTTYPE="${LOOPTYPE}"
                ;;
        esac
        mount -t "${MOUNTTYPE}" -o ro /dev/mapper/root \
            "${NEW_ROOT}/mnt/livecd"
        test_success "Mount filesystem"
        FS_LOCATION="mnt/livecd"

    else
        # Setup the loopback mounts, if unencrypted
        if [ "${LOOPTYPE}" = "normal" ]; then
            _livecd_mount_normal
            FS_LOCATION="mnt/livecd"
        elif [ "${LOOPTYPE}" = "squashfs" ]; then
            _livecd_mount_squashfs
            FS_LOCATION="mnt/livecd"
        elif [ "${LOOPTYPE}" = "gcloop" ]; then
            _livecd_mount_gcloop
            FS_LOCATION="mnt/livecd"
        elif [ "${LOOPTYPE}" = "zisofs" ]; then
            FS_LOCATION="${CDROOT_PATH/\/}/${LOOPEXT}${LOOP}"
        elif [ "${LOOPTYPE}" = "noloop" ]; then
            FS_LOCATION="${CDROOT_PATH/\/}"
        elif [ "${LOOPTYPE}" = "sgimips" ]; then
            _livecd_mount_sgimips
            FS_LOCATION="mnt/livecd"
        fi
    fi

    is_nfs && _livecd_mount_unpack_nfs

    # Manually copy livecd content to tmpfs if aufs is disabled
    _is_aufs || _livecd_mount_copy_content
}

cd_update() {
    local script_name="cdupdate.sh"
    local script="/${CDROOT_PATH}/${script_name}"
    if [ ! -x "${script}" ]; then
        good_msg "No ${script_name} script found, skipping..."
        return 0
    fi

    good_msg "Running ${script_name}"
    "${script}" && return 0

    bad_msg "Executing cdupdate.sh failed!"
    run_shell
}
