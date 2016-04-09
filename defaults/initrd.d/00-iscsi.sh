#!/bin/sh

. /etc/initrd.d/00-common.sh

start_iscsi() {
    if [ ! -e /usr/sbin/iscsistart ]; then
        return 0  # disabled
    fi

    if [ ! -n "${ISCSI_NOIBFT}" ]; then
        good_msg "Activating iSCSI via iBFT"
        iscsistart -b
    fi

    if [ -z "${ISCSI_INITIATORNAME}" ]; then
        warn_msg "No iSCSI initiator found"
        return 0
    fi

    if [ -z "${ISCSI_TARGET}" ]; then
        warn_msg "No iSCSI target found"
        return 0
    fi

    if [ -z "${ISCSI_ADDRESS}" ]; then
        warn_msg "No iSCSI address found"
        return 0
    fi

    good_msg "Activating iSCSI via cmdline"

    if [ "${ISCSI_TGPT}" ]; then
        ADDITIONAL="${ADDITIONAL} -g ${ISCSI_TGPT}"
    else
        ADDITIONAL="${ADDITIONAL} -g 1"
    fi

    if [ "${ISCSI_PORT}" ]; then
        ADDITIONAL="${ADDITIONAL} -p ${ISCSI_PORT}"
    fi

    if [ "${ISCSI_USERNAME}" ]; then
        ADDITIONAL="${ADDITIONAL} -u ${ISCSI_USERNAME}"
    fi

    if [ "${ISCSI_PASSWORD}" ]; then
        ADDITIONAL="${ADDITIONAL} -w ${ISCSI_PASSWORD}"
    fi

    if [ "${ISCSI_USERNAME_IN}" ]; then
        ADDITIONAL="${ADDITIONAL} -U ${ISCSI_USERNAME_IN}"
    fi

    if [ "${ISCSI_PASSWORD_IN}" ]; then
        ADDITIONAL="${ADDITIONAL} -W ${ISCSI_PASSWORD_IN}"
    fi

    if [ "${ISCSI_DEBUG}" ]; then
        ADDITIONAL="${ADDITIONAL} -d ${ISCSI_DEBUG}"
    fi

    if [ "${ISCSI_IFACE_NAME}" ]; then
        ADDITIONAL="${ADDITIONAL} --param iface.iscsi_ifacename=${ISCSI_IFACE_NAME}"
    fi
    if [ "${ISCSI_NETDEV_NAME}" ]; then
        ADDITIONAL="${ADDITIONAL} --param iface.net_ifacename=${ISCSI_NETDEV_NAME}"
    fi

    iscsistart -i "${ISCSI_INITIATORNAME}" -t "${ISCSI_TARGET}" \
        -a "${ISCSI_ADDRESS}" ${ADDITIONAL}
}

parse_dracut_iscsi_root() {
    # Adapted from dracut
    v=${1#iscsi:}

    # extract authentication info
    case "$v" in
        *@*:*:*:*:*)
            authinfo=${v%%@*}
            v=${v#*@}
            # allow empty authinfo to allow having an @ in
            # ISCSI_TARGET like this:
            # netroot=iscsi:@192.168.1.100::3260::iqn.2009-01.com.example:testdi@sk
            if [ -n "${authinfo}" ]; then
                OLDIFS="${IFS}"
                IFS=:
                set ${authinfo}
                IFS="${OLDIFS}"
                if [ $# -gt 4 ]; then
                    bad_msg "Wrong auth info in iscsi: parameter"
                    return 1
                fi
                ISCSI_USERNAME="${1}"
                ISCSI_PASSWORD="${2}"
                if [ $# -gt 2 ]; then
                    ISCSI_USERNAME_IN="${3}"
                    ISCSI_PASSWORD_IN="${4}"
                fi
            fi
            ;;
    esac

    # extract target ip
    case "${v}" in
        [[]*[]]:*)
            ISCSI_ADDRESS=${v#[[]}
                ISCSI_ADDRESS=${ISCSI_ADDRESS%%[]]*}
            v=${v#[[]$ISCSI_ADDRESS[]]:}
            ;;
        *)
            ISCSI_ADDRESS=${v%%[:]*}
            v=${v#$ISCSI_ADDRESS:}
            ;;
    esac

    # extract target name
    case "${v}" in
        *:iqn.*)
            ISCSI_TARGET=iqn.${v##*:iqn.}
            v=${v%:iqn.*}:
            ;;
        *:eui.*)
            ISCSI_TARGET=iqn.${v##*:eui.}
            v=${v%:iqn.*}:
            ;;
        *:naa.*)
            ISCSI_TARGET=iqn.${v##*:naa.}
            v=${v%:iqn.*}:
            ;;
        *)
            bad_msg "iscsi target name should begin with 'iqn.', 'eui.', 'naa.'"
            return 1
            ;;
    esac

    # parse the rest
    OLDIFS="${IFS}"
    IFS=:
    set ${v}
    IFS="${OLDIFS}"

    iscsi_protocol="${1}"; shift # ignored

    ISCSI_PORT="${1}"; shift
    if [ $# -eq 3 ]; then
        ISCSI_IFACE_NAME="${1}"; shift
    fi
    if [ $# -eq 2 ]; then
        ISCSI_NETDEV_NAME="${1}"; shift
    fi

    iscsi_lun="${1}"; shift # ignored
    if [ $# -ne 0 ]; then
        warn "Invalid parameter in iscsi: parameter!"
        return 1
    fi
}
