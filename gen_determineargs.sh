#!/bin/bash

get_KV() {
# don't want VER local anymore, used when finding kernelconfig to use
#	local VER
# don't want PAT local anymore, used in initrd
#	local PAT
	local SUB
	local EXV

	VER=`grep ^VERSION\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
	PAT=`grep ^PATCHLEVEL\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
	SUB=`grep ^SUBLEVEL\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
	EXV=`grep ^EXTRAVERSION\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
	KV=${VER}.${PAT}.${SUB}${EXV}
}

determine_real_args() {
	MAKE="make"
	MAKEOPTS="-j2"
	if [ "${CMD_KERNELDIR}" != "" ]
	then
		KERNEL_DIR=${CMD_KERNELDIR}
	else
		KERNEL_DIR=${DEFAULT_KERNEL_SOURCE}
	fi
	[ "${KERNEL_DIR}" = "" ] && gen_die "no kernel source directory"

	get_KV

	if [ "${CMD_CC}" != "" ]
	then
		CC="${CMD_CC}"
	fi

	if [ "${CMD_LD}" != "" ]
	then
		LD="${CMD_LD}"
	fi

	if [ "${CMD_AS}" != "" ]
	then
		AS="${CMD_AS}"
	fi

	DEFAULT_KERNEL_CONFIG=`arch_replace "${DEFAULT_KERNEL_CONFIG}"`
	BUSYBOX_CONFIG=`arch_replace "${BUSYBOX_CONFIG}"`
	BUSYBOX_BINCACHE=`arch_replace "${BUSYBOX_BINCACHE}"`
	MODULE_INIT_TOOLS_BINCACHE=`arch_replace "${MODULE_INIT_TOOLS_BINCACHE}"`
	MODUTILS_BINCACHE=`arch_replace "${MODUTILS_BINCACHE}"`
	DIETLIBC_BINCACHE=`arch_replace "${DIETLIBC_BINCACHE}"`
	DIETLIBC_BINCACHE_TEMP=`arch_replace "${DIETLIBC_BINCACHE_TEMP}"`
	if isTrue ${BOOTSPLASH}
	then
		BOOTSPLASH=1
	else
		BOOTSPLASH=0
	fi

	if isTrue ${COMPRESS_INITRD}
	then
		COMPRESS_INITRD=1
	else
		COMPRESS_INITRD=0
	fi

	if [ "${CMD_MRPROPER}" != "" ]
	then
		MRPROPER="${CMD_MRPROPER}"
	fi
	if [ "${CMD_MENUCONFIG}" != "" ]
	then
		MENUCONFIG="${CMD_MENUCONFIG}"
	fi
	if [ "${CMD_CLEAN}" != "" ]
	then
		CLEAN="${CMD_CLEAN}"
		if ! isTrue ${CLEAN}
		then
			MRPROPER=0
		fi
	fi

}
