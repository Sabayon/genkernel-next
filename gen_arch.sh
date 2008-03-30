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

	# sparc64 klibc is b0rked, so we force to 32
	if [ "${ARCH}" = 'sparc64' ]
	then
		UTILS_ARCH='sparc'
	fi
	
	ARCH_CONFIG="${GK_SHARE}/${ARCH}/config.sh"
	[ -f "${ARCH_CONFIG}" ] || gen_die "${ARCH} not yet supported by genkernel. Please add the arch-specific config file, ${ARCH_CONFIG}"
}

set_kernel_arch() {
	KERNEL_ARCH=${ARCH}
	case ${ARCH} in
		ppc|ppc64)
			if [ "${VER}" -eq "2" -a "${PAT}" -ge "6" ]
			then
				if [ "${PAT}" -eq "6" -a "${SUB}" -ge "16" ] || [ "${PAT}" -gt "6" ]
				then
					KERNEL_ARCH=powerpc
				fi
			fi
			;;
		x86)
			if [ "${VER}" -eq "2" -a "${PAT}" -ge "6" ] || [ "${VER}" -gt "2" ]
			then
				if [ "${PAT}" -eq "6" -a "${SUB}" -ge "24" ] || [ "${PAT}" -gt "6" ]
				then
					KERNEL_ARCH=x86
				else
					KERNEL_ARCH=i386
				fi
			fi
			;;
		x86_64)
			if [ "${VER}" -eq "2" -a "${PAT}" -ge "6" ] || [ "${VER}" -gt "2" ]
			then
				if [ "${PAT}" -eq "6" -a "${SUB}" -ge "24" ] || [ "${PAT}" -gt "6" ]
				then
					KERNEL_ARCH=x86
				fi
			fi
			;;
	esac
	export KERNEL_ARCH
	print_info 2 "KERNEL_ARCH=${KERNEL_ARCH}"
}
