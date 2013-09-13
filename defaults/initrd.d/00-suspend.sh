#!/bin/sh

resume_init() {
    if [ -z "${REAL_RESUME}" ]; then
        return 0
    fi
    if [ "${NORESUME}" = "1" ]; then
        return 0
    fi

    local resume_dev=$(find_real_device "${REAL_RESUME}")
    if [ -n "${resume_dev}" ]; then
        REAL_RESUME="${resume_dev}"
        good_msg "Detected real_resume=${resume_dev}"
    else
        bad_msg "Cannot resolve real_resume=${REAL_RESUME}"
        bad_msg "Something bad may happen, crossing fingers"
    fi

    swsusp_resume
}

swsusp_resume() {
    # determine swap resume partition
    local device=$(ls -lL "${REAL_RESUME}" | sed 's/\  */ /g' | \
        cut -d \  -f 5-6 | sed 's/,\ */:/')
    [ -f /sys/power/resume -a -n "${device}" ] && \
        echo "${device}" > /sys/power/resume
}
