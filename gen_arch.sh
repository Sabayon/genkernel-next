#!/bin/bash

get_official_arch() {
	if [ "${CMD_ARCHOVERRIDE}" != '' ]
	then
		ARCH=${CMD_ARCHOVERRIDE}
	else
		if [ "${ARCH_OVERRIDE}" != '' ]
		then
			ARCH=${ARCH_OVERRIDE}
		else
			ARCH=`uname -m`
			case "${ARCH}" in
				i?86)
					ARCH="x86"
				;;
				mips|mips64)
					ARCH="mips"
				;;
				*)
				;;
			esac
		fi
	fi

	if [ "${CMD_UTILS_ARCH}" != '' ]
	then
		UTILS_ARCH=${CMD_UTILS_ARCH}
	else
		if [ "${UTILS_ARCH}" != '' ]
		then
			UTILS_ARCH=${UTILS_ARCH}
		fi
	fi
	
	ARCH_CONFIG="${GK_SHARE}/${ARCH}/config.sh"
	[ -f "${ARCH_CONFIG}" ] || gen_die "${ARCH} not yet supported by genkernel. Please add the arch-specific config file, ${ARCH_CONFIG}"
}
