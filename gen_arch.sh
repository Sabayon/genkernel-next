#!/bin/bash

get_official_arch() {
	if [ "${CMD_ARCHOVERRIDE}" != '' ]
	then
		ARCH=${CMD_ARCHOVERRIDE}
	else
		ARCH=`uname -m`
		case "${ARCH}" in
			i?86)
				ARCH="x86"
			;;
			*)
			;;
		esac
	fi

	ARCH_CONFIG="${GK_SHARE}/${ARCH}/config.sh"
	[ -f "${ARCH_CONFIG}" ] || gen_die "${ARCH} not yet supported by genkernel. Please add the arch-specific config file, ${ARCH_CONFIG}"
}
