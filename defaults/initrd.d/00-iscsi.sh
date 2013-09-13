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

    iscsistart -i "${ISCSI_INITIATORNAME}" -t "${ISCSI_TARGET}" \
        -a "${ISCSI_ADDRESS}" ${ADDITIONAL}

    # let iscsid settle - otherwise mounting the iSCSI-disk
    # will fail (very rarely, though)
    # TODO(lxnay): this is horrible, find a real synchronization
    # technique.
    sleep 1
}
