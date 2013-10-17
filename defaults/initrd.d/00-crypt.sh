#!/bin/sh

. /etc/initrd.d/00-common.sh
. /etc/initrd.d/00-devmgr.sh
. /etc/initrd.d/00-splash.sh
. /etc/initrd.d/00-fsdev.sh

_bootstrap_key() {
    # $1 = ROOT/SWAP
    local keydevs=$(device_list)
    eval local keyloc='"${CRYPT_'${1}'_KEY}"'

    media_find "key" "${keyloc}" "CRYPT_${1}_KEYDEV" "/mnt/key" ${keydevs}
}

_crypt_exec() {
    # TODO(lxnay): this fugly crypt_silent should really go away
    if [ "${CRYPT_SILENT}" = "1" ]; then
        eval ${1} >/dev/null 2>/dev/null
    else
        ask_for_password --ply-tries 5 \
            --ply-cmd "${1}" \
            --ply-prompt "Encryption password (${LUKS_DEVICE}): " \
            --tty-tries 5 \
            --tty-cmd "${1}" || return 1
        return 0
    fi
}

_open_luks() {
    case ${1} in
        root)
            local ltype=ROOT
            ;;
        swap)
            local ltype=SWAP
            ;;
    esac

    local LUKS_NAME="${1}"
    # do not force the link to /dev/mapper/root
    # but rather use the value from root=, which is
    # in ${REAL_ROOT}
    if [ "${LUKS_NAME}" = "root" ]; then
        if echo "${REAL_ROOT}" | grep -q "^/dev/mapper/"; then
            LUKS_NAME="$(basename ${REAL_ROOT})"
        fi
    fi
    eval local LUKS_DEVICE='"${CRYPT_'${ltype}'}"'
    eval local LUKS_KEY='"${CRYPT_'${ltype}'_KEY}"'
    eval local LUKS_KEYDEV='"${CRYPT_'${ltype}'_KEYDEV}"'
    eval local LUKS_TRIM='"${CRYPT_'${ltype}'_TRIM}"'

    local dev_error=0 key_error=0 keydev_error=0
    local mntkey="/mnt/key/" cryptsetup_opts=""

    if [ ! -e /sbin/cryptsetup ]; then
        bad_msg "The ramdisk does not support LUKS"
        return 1
    fi

    local exit_st=

    while true; do
        local gpg_cmd=""
        exit_st=1

        # if crypt_silent=1 and some error occurs, bail out.
        local any_error=
        [ "${dev_error}" = "1" ] && any_error=1
        [ "${key_error}" = "1" ] && any_error=1
        [ "${keydev_error}" = "1" ] && any_error=1
        if [ "${CRYPT_SILENT}" = "1" ] && [ -n "${any_error}" ]; then
            bad_msg "Failed to setup the LUKS device"
            exit_st=1
            break
        fi

        if [ "${dev_error}" = "1" ]; then
            prompt_user "LUKS_DEVICE" "${LUKS_NAME}"
            dev_error=0
            continue
        fi

        if [ "${key_error}" = "1" ]; then
            prompt_user "LUKS_KEY" "${LUKS_NAME} key"
            key_error=0
            continue
        fi

        if [ "${keydev_error}" = "1" ]; then
            prompt_user "LUKS_KEYDEV" "${LUKS_NAME} key device"
            keydev_error=0
            continue
        fi

        local luks_dev=$(find_real_device "${LUKS_DEVICE}")
        [ -n "${luks_dev}" ] && LUKS_DEVICE="${luks_dev}"  # otherwise hope...

        setup_md_device "${LUKS_DEVICE}"
        cryptsetup isLuks "${LUKS_DEVICE}" || {
            bad_msg "${LUKS_DEVICE} does not contain a LUKS header"
            dev_error=1
            continue;
        }

        # Handle keys
        if [ "${LUKS_TRIM}" = "yes" ]; then
            good_msg "Enabling TRIM support for ${LUKS_NAME}."
            cryptsetup_opts="${cryptsetup_opts} --allow-discards"
        fi

        if [ -n "${LUKS_KEY}" ]; then
            local real_luks_keydev="${LUKS_KEYDEV}"

            if [ ! -e "${mntkey}${LUKS_KEY}" ]; then
                real_luks_keydev=$(find_real_device "${LUKS_KEYDEV}")
                good_msg "Using key device ${real_luks_keydev}."

                if [ ! -b "${real_luks_keydev}" ]; then
                    bad_msg "Insert device ${LUKS_KEYDEV} for ${LUKS_NAME}"
                    bad_msg "You have 10 seconds..."
                    local count=10
                    while [ ${count} -gt 0 ]; do
                        count=$((count-1))
                        sleep 1

                        real_luks_keydev=$(find_real_device "${LUKS_KEYDEV}")
                        [ ! -b "${real_luks_keydev}" ] || {
                            good_msg "Device ${real_luks_keydev} detected."
                            break;
                        }
                    done

                    if [ ! -b "${real_luks_keydev}" ]; then
                        eval CRYPT_${ltype}_KEY=${LUKS_KEY}
                        _bootstrap_key ${ltype}
                        eval LUKS_KEYDEV='"${CRYPT_'${ltype}'_KEYDEV}"'

                        real_luks_keydev=$(find_real_device "${LUKS_KEYDEV}")
                        if [ ! -b "${real_luks_keydev}" ]; then
                            keydev_error=1
                            bad_msg "Removable device ${LUKS_KEYDEV} not found."
                            continue
                        fi

                        # continue otherwise will mount keydev which is
                        # mounted by bootstrap
                        continue
                    fi
                fi

                # At this point a device was recognized, now let's see
                # if the key is there
                mkdir -p "${mntkey}"  # ignore

                mount -n -o ro "${real_luks_keydev}" \
                    "${mntkey}" || {
                    keydev_error=1
                    bad_msg "Mounting of device ${real_luks_keydev} failed."
                    continue;
                }

                good_msg "Removable device ${real_luks_keydev} mounted."

                if [ ! -e "${mntkey}${LUKS_KEY}" ]; then
                    umount -n "${mntkey}"
                    key_error=1
                    keydev_error=1
                    bad_msg "{LUKS_KEY} on ${real_luks_keydev} not found."
                    continue
                fi
            fi

            # At this point a candidate key exists
            # (either mounted before or not)
            good_msg "${LUKS_KEY} on device ${real_luks_keydev} found"
            if [ "$(echo ${LUKS_KEY} | grep -o '.gpg$')" = ".gpg" ] && \
                [ -e /usr/bin/gpg ]; then

                # TODO(lxnay): WTF is this?
                [ -e /dev/tty ] && mv /dev/tty /dev/tty.org
                mknod /dev/tty c 5 1

                cryptsetup_opts="${cryptsetup_opts} -d -"
                gpg_cmd="/usr/bin/gpg --logger-file /dev/null"
                gpg_cmd="${gpg_cmd} --quiet --decrypt ${mntkey}${LUKS_KEY} | "
            else
                cryptsetup_opts="${cryptsetup_opts} -d ${mntkey}${LUKS_KEY}"
            fi
        fi

        # At this point, keyfile or not, we're ready!
        local cmd="${gpg_cmd}/sbin/cryptsetup"
        cmd="${cmd} ${cryptsetup_opts} luksOpen ${LUKS_DEVICE} ${LUKS_NAME}"
        _crypt_exec "${cmd}"
        local ret="${?}"

        # TODO(lxnay): WTF is this?
        [ -e /dev/tty.org ] \
            && rm -f /dev/tty \
            && mv /dev/tty.org /dev/tty

        if [ "${ret}" = "0" ]; then
            good_msg "LUKS device ${LUKS_DEVICE} opened"
            exit_st=0
            break
        fi

        bad_msg "Failed to open LUKS device ${LUKS_DEVICE}"
        dev_error=1
        key_error=1
        keydev_error=1
    done

    umount -l "${mntkey}" 2>/dev/null >/dev/null
    rmdir -p "${mntkey}" 2>/dev/null >/dev/null

    return ${exit_st}
}

start_luks() {
    # TODO(lxnay): this sleep 6 thing is hurting my eyes sooooo much.
    # if key is set but key device isn't, find it
    [ -n "${CRYPT_ROOT_KEY}" ] && [ -z "${CRYPT_ROOT_KEYDEV}" ] \
        && sleep 6 && _bootstrap_key "ROOT"

    if [ -n "${CRYPT_ROOT}" ]; then
        if _open_luks "root"; then
            # force REAL_ROOT= to some value if not set
            # this is mainly for backward compatibility,
            # because grub2 always sets a valid root=
            # and user must have it as well.
            [ -z "${REAL_ROOT}" ] && REAL_ROOT="/dev/mapper/root"
        fi
        # Always rescan volumes
        start_volumes
    fi

    # TODO(lxnay): this sleep 6 thing is hurting my eyes sooooo much.
    # same for swap, but no need to sleep if root was unencrypted
    [ -n "${CRYPT_SWAP_KEY}" ] && [ -z "${CRYPT_SWAP_KEYDEV}" ] \
        && { [ -z "${CRYPT_ROOT}" ] && sleep 6; _bootstrap_key "SWAP"; }

    if [ -n "${CRYPT_SWAP}" ]; then
        _open_luks "swap"
        if [ -z "${REAL_RESUME}" ]; then
            # Resume from swap as default
            REAL_RESUME="/dev/mapper/swap"
        fi
    fi
}
