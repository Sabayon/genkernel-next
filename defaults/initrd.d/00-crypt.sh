#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-devmgr.sh
. /etc/initrd.d/00-splash.sh
. /etc/initrd.d/00-fsdev.sh

CRYPTSETUP_BIN="/sbin/cryptsetup"
KEY_MNT="/mnt/key"
HEADER_MNT="/mnt/header"

_bootstrap() {
    local ltype="${1}"
    local ltype2="${2}"
    local mnt="${3}"
    local devs=$(device_list)

    eval local loc='"${CRYPT_'${ltype}'_'${ltype2}'}"'

    media_find "${ltype2}" "${loc}" "CRYPT_${ltype}_${ltype2}DEV" "${mnt}" ${devs}
}

_bootstrap_real() {
    local mnt_dev="${1}"
    local mnt_path="${2}"
    local mnt_dev_type="${3}"

    local tgt_file="${4}"

    local lname="${5}"
    local ltype="${6}"

    local real_mnt_dev="${mnt_dev}"

    if [ ! -e "${mnt_path}${tgt_file}" ]; then
        real_mnt_dev=$(find_real_device "${mnt_dev}")
        good_msg "Using ${mnt_dev_type} device ${real_mnt_dev}."

        if [ ! -b "${real_mnt_dev}" ]; then
            bad_msg "Insert device ${mnt_dev} for ${lname}"
            bad_msg "You have 10 seconds..."
            local count=10
            while [ ${count} -gt 0 ]; do
                count=$((count-1))
                sleep 1

                real_mnt_dev=$(find_real_device "${mnt_dev}")
                [ ! -b "${real_mnt_dev}" ] || {
                    good_msg "Device ${real_mnt_dev} detected."
                    break;
                }
            done

            if [ ! -b "${real_mnt_dev}" ]; then
                eval CRYPT_${ltype}_${mnt_dev_type}=${tgt_file}
                _bootstrap "${ltype}" "${mnt_dev_type}" "${mnt_path}"
                eval mnt_dev='"${CRYPT_'${ltype}'_'${mnt_dev_type}'DEV}"'

                real_mnt_dev=$(find_real_device "${mnt_dev}")
                if [ ! -b "${real_mnt_dev}" ]; then
                    eval ${mnt_dev_type}dev_error=1
                    bad_msg "Device ${mnt_dev} not found."
                    continue
                fi

                # continue otherwise will mount the dev which is
                # mounted by bootstrap
                continue
            fi
        fi

        # At this point a device was recognized, now let's see
        # if the target file is there
        mkdir -p "${mnt_path}"  # ignore

        mount -n -o ro "${real_mnt_dev}" \
        "${mnt_path}" || {
            eval ${mnt_dev_type}dev_error=1
            bad_msg "Mounting of device ${real_mnt_dev} failed."
            continue;
        }

        good_msg "Removable device ${real_mnt_dev} mounted."

        if [ ! -e "${mnt_path}${tgt_file}" ]; then
            umount -n "${mnt_path}"
            eval ${mnt_dev_type}_error=1
            eval ${mnt_dev_type}dev_error=1
            bad_msg "${tgt_file} on ${real_mnt_dev} not found."
            continue
        fi
    fi

    # At this point a candidate target file exists
    # (either mounted before or not)
    good_msg "${tgt_file} on device ${real_mnt_dev} found"
}

_crypt_exec() {
    local luks_dev="${1}"
    local ply_cmd="${2}" # command for use when plymouth is active
    local tty_cmd="${3}" # command for use without plymouth
    local do_ask="${4}"  # whether we need a passphrase at all

    if [ "${CRYPT_SILENT}" = "1" -o "${do_ask}" = "0" ]; then
        eval ${tty_cmd} >/dev/null 2>/dev/null
    else
        ask_for_password --ply-tries 5 \
            --ply-cmd "${ply_cmd}" \
            --ply-prompt "Encryption password (${luks_dev}): " \
            --tty-tries 5 \
            --tty-cmd "${tty_cmd}" || return 1
        return 0
    fi
}

_open_luks() {
    local luks_name="${1}"

    case ${luks_name} in
        root)
            local ltypes=ROOTS
            local ltype=ROOT
            local real_dev="${REAL_ROOT}"
            ;;
        swap)
            local ltypes=SWAPS
            local ltype=SWAP
            local real_dev="${REAL_RESUME}"
            ;;
    esac

    eval local luks_devices='"${CRYPT_'${ltypes}'}"'
 
    # Key values
    eval local luks_key='"${CRYPT_'${ltype}'_KEY}"'

    local luks_key_included=0

    if [ -n "${luks_key}" ] && [ -f "${luks_key}" ]; then
        luks_key_included=1
    fi

    eval local luks_keydev='"${CRYPT_'${ltype}'_KEYDEV}"'
   
    # Header values
    eval local luks_header='"${CRYPT_'${ltype}'_HEADER}"'

    local luks_header_included=0

    if [ -n "${luks_header}" ] && [ -f "${luks_header}" ];then
        luks_header_included=1
    fi

    eval local luks_headerdev='"${CRYPT_'${ltype}'_HEADERDEV}"'

    # TRIM values
    eval local luks_trim='"${CRYPT_'${ltype}'_TRIM}"'

    # Misc
    local mntkey="${KEY_MNT}/"
    local mntheader="${HEADER_MNT}/"

    cryptsetup_opts=""

    local exit_st=0 luks_device=
    for luks_device in ${luks_devices}; do

        good_msg "Working on device ${luks_device}..."

        while true; do

            local gpg_ply_cmd=""
            local gpg_tty_cmd=""
            local passphrase_needed="1"

            # do not force the link to /dev/mapper/root
            # but rather use the value from root=, which is
            # in ${REAL_ROOT}
            # Using find_real_device to convert UUID= or LABEL=
            # strings into actual device paths, this and basename
            # avoid to create long strings that could be truncated
            # by cryptsetup, generating a "DM-UUID for device %s was truncated"
            # error.
            local luks_dev_name=$(basename $(find_real_device "${luks_device}"))
            local luks_name_prefix=

            if echo "${real_dev}" | grep -q "^/dev/mapper/"; then
                local real_dev_bn=$(basename "${real_dev}")
                # If we use LVM + cryptsetup, we may have collisions between
                # the two inside /dev/mapper. So, make up a way to avoid them.
                luks_dev_name="${luks_name}_${luks_dev_name}-${real_dev_bn}"
            fi

            # if crypt_silent=1 and some error occurs, bail out.
            local any_error=
            [ "${dev_error}" = "1" ] && any_error=1
            [ "${key_error}" = "1" ] && any_error=1
            [ "${keydev_error}" = "1" ] && any_error=1
            [ "${header_error}" = "1" ] && any_error=1
            [ "${headerdev_error}" = "1" ] && any_error=1

            if [ "${CRYPT_SILENT}" = "1" ] && [ -n "${any_error}" ]; then
                bad_msg "Failed to setup the LUKS device"
                exit_st=1
                break
            fi

            if [ "${dev_error}" = "1" ]; then
                prompt_user "luks_device" "${luks_dev_name}"
                dev_error=0
                continue
            fi

            if [ "${key_error}" = "1" ]; then
                prompt_user "luks_key" "${luks_dev_name} key"
                key_error=0
                continue
            fi

            if [ "${keydev_error}" = "1" ]; then
                prompt_user "luks_keydev" "${luks_dev_name} key device"
                keydev_error=0
                continue
            fi

            if [ "${header_error}" = "1" ]; then
                prompt_user "luks_header" "${luks_dev_name} header"
                header_error=0
                continue
            fi

            if [ "${headerdev_error}" = "1" ]; then
                prompt_user "luks_headerdev" "${luks_dev_name} header device"
                headerdev_error=0
                continue
            fi

            local luks_dev=$(find_real_device "${luks_device}")
            [ -n "${luks_dev}" ] && \
                luks_device="${luks_dev}"  # otherwise hope...

            # Handle headers
            if [ -n "${luks_header}" ]; then
                if [ "${luks_header_included}" = "0" ]; then
                    _bootstrap_real "${luks_headerdev}" \
                        "${mntheader}" \
                        "header" \
                        "${luks_header}" \
                        "${luks_dev_name}" \
                        "${ltype}"
                else
                    mntheader=""
                    good_msg "Header file ${luks_header} found included in initramfs"
                fi

                if eval "${CRYPTSETUP_BIN} isLuks ${mntheader}${luks_header}"; then
                    good_msg "${luks_header} is a valid luks header"
                    cryptsetup_opts="${cryptsetup_opts} --header ${mntheader}${luks_header}"
                else
                    bad_msg "${luks_header} is not a valid LUKS header"
                    header_error=1
                    continue;
                fi
            else
                eval "${CRYPTSETUP_BIN} isLuks ${luks_device}" || {
                    bad_msg "${luks_device} does not contain a LUKS header"
                    dev_error=1
                    continue;
                }
            fi

            # TRIM support
            if [ "${luks_trim}" = "yes" ]; then
                good_msg "Enabling TRIM support for ${luks_dev_name}."
                cryptsetup_opts="${cryptsetup_opts} --allow-discards"
            fi

            # Handle keys
            if [ -n "${luks_key}" ]; then
                if [ "${luks_key_included}" = "0" ]; then
                    _bootstrap_real "${luks_keydev}" \
                        "${mntkey}" \
                        "key" \
                        "${luks_key}" \
                        "${luks_dev_name}" \
                        "${ltype}"
                else
                    mntkey=""
                    good_msg "Key file ${luks_key} found included in initramfs"
                fi

                if [ "$(echo ${luks_key} | grep -o '.gpg$')" = ".gpg" ] && \
                    [ -e /usr/bin/gpg ]; then

                    # TODO(lxnay): WTF is this?
                    [ -e /dev/tty ] && mv /dev/tty /dev/tty.org
                    mknod /dev/tty c 5 1

                    cryptsetup_opts="${cryptsetup_opts} -d -"
                    # if plymouth not in use, gpg reads keyfile passphrase...
                    gpg_tty_cmd="/usr/bin/gpg --logger-file /dev/null"
                    gpg_tty_cmd="${gpg_tty_cmd} --quiet --decrypt ${mntkey}${luks_key} | "
                    # but when plymouth is in use, keyfile passphrase piped in
                    gpg_ply_cmd="/usr/bin/gpg --logger-file /dev/null"
                    gpg_ply_cmd="${gpg_ply_cmd} --quiet --passphrase-fd 0 --batch --no-tty"
                    gpg_ply_cmd="${gpg_ply_cmd} --decrypt ${mntkey}${luks_key} | "
                else
                    cryptsetup_opts="${cryptsetup_opts} -d ${mntkey}${luks_key}"
                    passphrase_needed="0" # keyfile not itself encrypted
                fi
            fi

            # At this point, keyfile or not, we're ready!
            local ply_cmd="${gpg_ply_cmd}${CRYPTSETUP_BIN}"
            local tty_cmd="${gpg_tty_cmd}${CRYPTSETUP_BIN}"
            ply_cmd="${ply_cmd} ${cryptsetup_opts} luksOpen ${luks_device} ${luks_dev_name}"
            tty_cmd="${tty_cmd} ${cryptsetup_opts} luksOpen ${luks_device} ${luks_dev_name}"
            # send to a temporary shell script, so plymouth can
            # invoke the pipeline successfully
            local ply_cmd_file="$(mktemp -t "ply_cmd.XXXXXX")"
            printf '#!/bin/sh\n%s\n' "${ply_cmd}" > "${ply_cmd_file}"
            chmod 500 "${ply_cmd_file}"
            _crypt_exec "${luks_device}" "${ply_cmd_file}" "${tty_cmd}" "${passphrase_needed}"
            local ret="${?}"
            rm -f "${ply_cmd_file}"

            # TODO(lxnay): WTF is this?
            [ -e /dev/tty.org ] \
                && rm -f /dev/tty \
                && mv /dev/tty.org /dev/tty

            if [ "${ret}" = "0" ]; then
                good_msg "LUKS device ${luks_device} opened"

                # Note 1: This is fine if the crypt device is a physical device
                # like /dev/sdaX, however, if we have cryptsetup inside
                # LVM, we must tweak REAL_ROOT if there is no device node.
                # Note 2: we should not activate md arrays yet, because
                # they could be started in degraded mode and mdadm is so stupid
                # that it may end up creating multiple md devices with the
                # same UUID... Let's postpone this for the end
                (   USE_MDADM=0
                    USE_DMRAID_NORMAL=0
                    start_volumes # this creates /dev/mapper links
                )
                if echo "${real_dev}" | grep -q "^/dev/mapper/"; then
                    if [ ! -e "${real_dev}" ]; then
                        # WARN: while for ltype=SWAP this may not be a problem,
                        # for ltype=ROOT this may render the system unbootable
                        # because lvm can get angry to see a symlink where it's
                        # not supposed to be or we may fail to create the proper
                        # link (due to the if above), however, reordering the
                        # cmdline entries may solve this.
                        good_msg "Creating symlink ${luks_dev_name} -> ${real_dev}"
                        ln -s "${luks_dev_name}" "${real_dev}" || exit_st=1
                    fi
                fi

                break
            fi

            bad_msg "Failed to open LUKS device ${luks_device}"
            dev_error=1
            key_error=1
            keydev_error=1

        done

    done

    if [ "${luks_header_included}" = "0" ]; then   
        umount -l "${mntheader}" 2>/dev/null >/dev/null
        rmdir "${mntheader}" 2>/dev/null >/dev/null
    fi

    if [ "${luks_key_included}" = "0" ]; then   
        umount -l "${mntkey}" 2>/dev/null >/dev/null
        rmdir "${mntkey}" 2>/dev/null >/dev/null
    fi

    return ${exit_st}
}

start_luks() {

    local root_or_swap=
    if [ -n "${CRYPT_ROOTS}" ] || [ -n "${CRYPT_SWAPS}" ]; then
        root_or_swap=1
    fi

    if [ ! -e "${CRYPTSETUP_BIN}" ] && [ -n "${root_or_swap}" ]; then
        bad_msg "${CRYPTSETUP_BIN} not found inside the initramfs"
        return 1
    fi

    # Check if root header is not included in initramfs
    if [ -n "${CRYPT_ROOT_HEADER}" ] && [ ! -f "${CRYPT_ROOT_HEADER}" ]; then
        # if header is set but header device isn't, find it
        [ -z "${CRYPT_ROOT_HEADERDEV}" ] && _bootstrap "ROOT" "header" "${HEADER_MNT}"
    fi

    # Check if root key is not included in initramfs
    if [ -n "${CRYPT_ROOT_KEY}" ] && [ ! -f "${CRYPT_ROOT_KEY}" ]; then
        # if key is set but key device isn't, find it
        [ -z "${CRYPT_ROOT_KEYDEV}" ] && _bootstrap "ROOT" "key" "${KEY_MNT}"
    fi

    if [ -n "${CRYPT_ROOTS}" ]; then
        # force REAL_ROOT= to some value if not set
        # this is mainly for backward compatibility,
        # because grub2 always sets a valid root=
        # and user must have it as well.
        [ -z "${REAL_ROOT}" ] && REAL_ROOT="/dev/mapper/root"
        _open_luks "root"
    fi

    # Check if swap header is not included in initramfs
    if [ -n "${CRYPT_SWAP_HEADER}" ] && [ ! -f "${CRYPT_SWAP_HEADER}" ]; then
        # if header is set but header device isn't, find it
        [ -z "${CRYPT_SWAP_HEADERDEV}" ] && _bootstrap "SWAP" "header" "${HEADER_MNT}"
    fi

    # Check if swap key is not included in initramfs
    if [ -n "${CRYPT_SWAP_KEY}" ] && [ ! -f "${CRYPT_SWAP_KEY}" ]; then
        # if key is set but key device isn't, find it
        [ -z "${CRYPT_SWAP_KEYDEV}" ] && _bootstrap "SWAP" "key" "${KEY_MNT}"
    fi

    if [ -n "${CRYPT_SWAPS}" ]; then
        # force REAL_RESUME= to some value if not set
        [ -z "${REAL_RESUME}" ] && REAL_RESUME="/dev/mapper/swap"
        _open_luks "swap"
    fi

    if [ -n "${root_or_swap}" ]; then
        # We postponed the initialization of raid devices
        # in order to avoid to assemble possibly degraded
        # arrays.
        start_volumes
    fi
}

