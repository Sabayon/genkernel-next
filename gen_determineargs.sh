#!/bin/bash

get_KV() {
	local SUB
	local EXV
	
	VER=`grep ^VERSION\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
	PAT=`grep ^PATCHLEVEL\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
	SUB=`grep ^SUBLEVEL\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
	EXV=`grep ^EXTRAVERSION\ \= ${KERNEL_DIR}/Makefile | sed -e "s/EXTRAVERSION =//" -e "s/ //g"`
	KV=${VER}.${PAT}.${SUB}${EXV}
}

determine_real_args() {
	if [ "${CMD_DEBUGFILE}" != '' ]
	then
		DEBUGFILE="${CMD_DEBUGFILE}"
	fi

	if [ "${CMD_MAKEOPTS}" != '' ]
	then
		MAKEOPTS="${CMD_MAKEOPTS}"
	fi

	if [ "${CMD_KERNELDIR}" != '' ]
	then
		KERNEL_DIR=${CMD_KERNELDIR}
	else
		KERNEL_DIR=${DEFAULT_KERNEL_SOURCE}
	fi
	[ "${KERNEL_DIR}" = '' ] && gen_die 'No kernel source directory!'

	get_KV

	if [ "${CMD_KERNEL_MAKE}" != '' ]
	then
		KERNEL_MAKE="${CMD_KERNEL_MAKE}"
	fi

	if [ "${KERNEL_MAKE}" = '' ]
	then
		KERNEL_MAKE='make'
	fi

	if [ "${CMD_UTILS_MAKE}" != '' ]
	then
		UTILS_MAKE="${CMD_UTILS_MAKE}"
	fi

	if [ "${UTILS_MAKE}" = '' ]
	then
		UTILS_MAKE='make'
	fi

	if [ "${CMD_KERNEL_CC}" != '' ]
	then
		KERNEL_CC="${CMD_KERNEL_CC}"
	fi

	if [ "${CMD_KERNEL_LD}" != '' ]
	then
		KERNEL_LD="${CMD_KERNEL_LD}"
	fi

	if [ "${CMD_KERNEL_AS}" != '' ]
	then
		KERNEL_AS="${CMD_KERNEL_AS}"
	fi

	if [ "${CMD_UTILS_CC}" != '' ]
	then
		UTILS_CC="${CMD_UTILS_CC}"
	fi

	if [ "${CMD_UTILS_LD}" != '' ]
	then
		UTILS_LD="${CMD_UTILS_LD}"
	fi

	if [ "${CMD_UTILS_AS}" != '' ]
	then
		UTILS_AS="${CMD_UTILS_AS}"
	fi

	DEFAULT_KERNEL_CONFIG=`arch_replace "${DEFAULT_KERNEL_CONFIG}"`
	BUSYBOX_CONFIG=`arch_replace "${BUSYBOX_CONFIG}"`
	BUSYBOX_BINCACHE=`arch_replace "${BUSYBOX_BINCACHE}"`
	MODULE_INIT_TOOLS_BINCACHE=`arch_replace "${MODULE_INIT_TOOLS_BINCACHE}"`
	MODUTILS_BINCACHE=`arch_replace "${MODUTILS_BINCACHE}"`
	DIETLIBC_BINCACHE=`arch_replace "${DIETLIBC_BINCACHE}"`
	DIETLIBC_BINCACHE_TEMP=`arch_replace "${DIETLIBC_BINCACHE_TEMP}"`
	DEVFSD_BINCACHE=`arch_replace "${DEVFSD_BINCACHE}"`
	DEVFSD_CONF_BINCACHE=`arch_replace "${DEVFSD_CONF_BINCACHE}"`
	UDEV_BINCACHE=`arch_replace "${UDEV_BINCACHE}"`
	
	if [ "${CMD_BOOTSPLASH}" != '' ]
	then
		BOOTSPLASH=${CMD_BOOTSPLASH}
	fi

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

	if [ "${CMD_MRPROPER}" != '' ]
	then
		MRPROPER="${CMD_MRPROPER}"
	fi
	if [ "${CMD_MENUCONFIG}" != '' ]
	then
		MENUCONFIG="${CMD_MENUCONFIG}"
	fi
	if [ "${CMD_CLEAN}" != '' ]
	then
		CLEAN="${CMD_CLEAN}"
		if ! isTrue ${CLEAN}
		then
			MRPROPER=0
		fi
	fi

	if [ "${CMD_MINKERNPACKAGE}" != '' ]
	then
		MINKERNPACKAGE="${CMD_MINKERNPACKAGE}"
	fi

	if [ "${CMD_NOINITRDMODULES}" != '' ]
	then
		NOINITRDMODULES="${CMD_NOINITRDMODULES}"
	fi

	if [ "${CMD_MOUNTBOOT}" != '' ]
	then
		MOUNTBOOT="${CMD_MOUNTBOOT}"
	fi

	if isTrue ${MOUNTBOOT}
	then
		MOUNTBOOT=1
	else
		MOUNTBOOT=0
	fi

	if [ "${CMD_SAVE_CONFIG}" != '' ]
	then
		SAVE_CONFIG="${CMD_SAVE_CONFIG}"
	fi

	if isTrue "${SAVE_CONFIG}"
	then
		SAVE_CONFIG=1
	else
		SAVE_CONFIG=0
	fi
  
	if [ "${CMD_INSTALL_MOD_PATH}" != '' ]
	then
		INSTALL_MOD_PATH="${CMD_INSTALL_MOD_PATH}"
	fi

	if [ "${CMD_BOOTLOADER}" != '' ]
	then
		BOOTLOADER="${CMD_BOOTLOADER}"
	fi

	if isTrue "${CMD_OLDCONFIG}"
	then
		OLDCONFIG=1
	else
		OLDCONFIG=0
	fi
}
