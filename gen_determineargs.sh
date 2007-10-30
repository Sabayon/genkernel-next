#!/bin/bash

get_KV() {
	if [ "${CMD_NO_KERNEL_SOURCES}" = '1' -a -e "${CMD_KERNCACHE}" ]
	then
		/bin/tar -xj -C ${TEMP} -f ${CMD_KERNCACHE} kerncache.config 
		if [ -e ${TEMP}/kerncache.config ]
		then
			KERN_24=0
			VER=`grep ^VERSION\ \= ${TEMP}/kerncache.config | awk '{ print $3 };'`
			PAT=`grep ^PATCHLEVEL\ \= ${TEMP}/kerncache.config | awk '{ print $3 };'`
			SUB=`grep ^SUBLEVEL\ \= ${TEMP}/kerncache.config | awk '{ print $3 };'`
			EXV=`grep ^EXTRAVERSION\ \= ${TEMP}/kerncache.config | sed -e "s/EXTRAVERSION =//" -e "s/ //g"`
			if [ "${PAT}" -gt '4' -a "${VER}" -ge '2' ]
			then
				LOV=`grep ^CONFIG_LOCALVERSION\= ${TEMP}/kerncache.config | sed -e "s/CONFIG_LOCALVERSION=\"\(.*\)\"/\1/"`
				KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
			else
				KERN_24=1
				KV=${VER}.${PAT}.${SUB}${EXV}
			fi

		else
			gen_die "Could not find kerncache.config in the kernel cache! Exiting."
		fi

	else
		# Configure the kernel
		# If BUILD_KERNEL=0 then assume --no-clean, menuconfig is cleared

		VER=`grep ^VERSION\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
		PAT=`grep ^PATCHLEVEL\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
		SUB=`grep ^SUBLEVEL\ \= ${KERNEL_DIR}/Makefile | awk '{ print $3 };'`
		EXV=`grep ^EXTRAVERSION\ \= ${KERNEL_DIR}/Makefile | sed -e "s/EXTRAVERSION =//" -e "s/ //g" -e 's/\$([a-z]*)//gi'`
		if [ "${PAT}" -gt '4' -a "${VER}" -ge '2' -a -e ${KERNEL_DIR}/.config ]
		then
			KERN_24=0
			cd ${KERNEL_DIR}
			#compile_generic prepare kernel > /dev/null 2>&1
			cd - > /dev/null 2>&1
			[ -f "${KERNEL_DIR}/include/linux/version.h" ] && \
				VERSION_SOURCE="${KERNEL_DIR}/include/linux/version.h"
			[ -f "${KERNEL_DIR}/include/linux/utsrelease.h" ] && \
				VERSION_SOURCE="${KERNEL_DIR}/include/linux/utsrelease.h"
			# Handle new-style releases where version.h doesn't have UTS_RELEASE
			if [ -f ${KERNEL_DIR}/include/config/kernel.release ]
			then
				UTS_RELEASE=`cat ${KERNEL_DIR}/include/config/kernel.release`
				LOV=`echo ${UTS_RELEASE}|sed -e "s/${VER}.${PAT}.${SUB}${EXV}//"`
				KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
			elif [ -n "${VERSION_SOURCE}" ]
			then
				UTS_RELEASE=`grep UTS_RELEASE ${VERSION_SOURCE} | sed -e 's/#define UTS_RELEASE "\(.*\)"/\1/'`
				LOV=`echo ${UTS_RELEASE}|sed -e "s/${VER}.${PAT}.${SUB}${EXV}//"`
				KV=${VER}.${PAT}.${SUB}${EXV}${LOV}
			else
				LCV=`grep ^CONFIG_LOCALVERSION= ${KERNEL_DIR}/.config | sed -r -e "s/.*=\"(.*)\"/\1/"`
				KV=${VER}.${PAT}.${SUB}${EXV}${LCV}
			fi
		else
			KERN_24=1
			KV=${VER}.${PAT}.${SUB}${EXV}
		fi

	fi

	if isTrue "${CMD_DISKLABEL}"
	then
		DISKLABEL=1
	else
		DISKLABEL=0
	fi

	if isTrue "${CMD_LUKS}"
	then
		LUKS=1
	fi
}

determine_real_args() {
	if [ "${CMD_LOGFILE}" != '' ]
	then
		LOGFILE="${CMD_LOGFILE}"
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
	
	if [ "${CMD_NO_KERNEL_SOURCES}" != "1" ]
	then
		if [ ! -d ${KERNEL_DIR} ]
		then
			gen_die "kernel source directory \"${KERNEL_DIR}\" was not found!"
		fi
	fi

	if [ "${CMD_KERNCACHE}" != "" ]
	then	
		if [ "${KERNEL_DIR}" = '' -a "${CMD_NO_KERNEL_SOURCES}" != "1" ]
		then
			gen_die 'No kernel source directory!'
		fi
		if [ ! -e "${KERNEL_DIR}" -a "${CMD_NO_KERNEL_SOURCES}" != "1" ]
		then
			gen_die 'No kernel source directory!'
		fi
	else	
		if [ "${KERNEL_DIR}" = '' ]
		then
			gen_die 'Kernel Cache specified but no kernel tree to verify against!'
		fi
	fi
	
	if [ "${CMD_KERNNAME}" != "" ]
	then
		KNAME=${CMD_KERNNAME}
	else
		KNAME="genkernel"
	fi
	
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
	
	if [ "${CMD_KERNEL_CROSS_COMPILE}" != '' ]
	then
		KERNEL_CROSS_COMPILE="${CMD_KERNEL_CROSS_COMPILE}"
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
	
	if [ "${CMD_UTILS_CROSS_COMPILE}" != '' ]
	then
		UTILS_CROSS_COMPILE="${CMD_UTILS_CROSS_COMPILE}"
	fi

	if [ "${BOOTDIR}" != '' ]
	then
		BOOTDIR=`arch_replace "${BOOTDIR}"`
		BOOTDIR=${BOOTDIR%/}    # Remove any trailing slash
	else
		BOOTDIR="/boot"
	fi

	CACHE_DIR=`arch_replace "${CACHE_DIR}"`
	BUSYBOX_BINCACHE=`cache_replace "${BUSYBOX_BINCACHE}"`
	DEVFSD_BINCACHE=`cache_replace "${DEVFSD_BINCACHE}"`
	DEVFSD_CONF_BINCACHE=`cache_replace "${DEVFSD_CONF_BINCACHE}"`
	DEVICE_MAPPER_BINCACHE=`cache_replace "${DEVICE_MAPPER_BINCACHE}"`
	LVM_BINCACHE=`cache_replace "${LVM_BINCACHE}"`
	DMRAID_BINCACHE=`cache_replace "${DMRAID_BINCACHE}"`
	UNIONFS_BINCACHE=`cache_replace "${UNIONFS_BINCACHE}"`
	UNIONFS_MODULES_BINCACHE=`cache_replace "${UNIONFS_MODULES_BINCACHE}"`
	BLKID_BINCACHE=`cache_replace "${BLKID_BINCACHE}"`
  
	DEFAULT_KERNEL_CONFIG=`arch_replace "${DEFAULT_KERNEL_CONFIG}"`
	BUSYBOX_CONFIG=`arch_replace "${BUSYBOX_CONFIG}"`
	BUSYBOX_BINCACHE=`arch_replace "${BUSYBOX_BINCACHE}"`
	DEVICE_MAPPER_BINCACHE=`arch_replace "${DEVICE_MAPPER_BINCACHE}"`
	LVM_BINCACHE=`arch_replace "${LVM_BINCACHE}"`
	DMRAID_BINCACHE=`arch_replace "${DMRAID_BINCACHE}"`
	UNIONFS_BINCACHE=`arch_replace "${UNIONFS_BINCACHE}"`
	UNIONFS_MODULES_BINCACHE=`arch_replace "${UNIONFS_MODULES_BINCACHE}"`
	BLKID_BINCACHE=`arch_replace "${BLKID_BINCACHE}"`
	
	if [ "${CMD_SPLASH}" != '' ]
	then
		SPLASH=${CMD_SPLASH}
	fi

	if isTrue ${SPLASH}
	then
		SPLASH=1
	else
		SPLASH=0
	fi

	if isTrue ${COMPRESS_INITRD}
	then
		COMPRESS_INITRD=1
	else
		COMPRESS_INITRD=0
	fi

	if isTrue ${CMD_POSTCLEAR}
	then
		POSTCLEAR=1
	else
		POSTCLEAR=0
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
		mkdir -p `dirname ${MINKERNPACKAGE}`
	fi
	
	if [ "${CMD_MODULESPACKAGE}" != '' ]
	then
		MODULESPACKAGE="${CMD_MODULESPACKAGE}"
		mkdir -p `dirname ${MODULESPACKAGE}`
	fi

	if [ "${CMD_KERNCACHE}" != '' ]
	then
		KERNCACHE="${CMD_KERNCACHE}"
		mkdir -p `dirname ${KERNCACHE}`
	fi
	
	if [ "${CMD_NOINITRDMODULES}" != '' ]
	then
		NOINITRDMODULES="${CMD_NOINITRDMODULES}"
	fi
	
	if [ "${CMD_INITRAMFS_OVERLAY}" != '' ]
	then
		INITRAMFS_OVERLAY="${CMD_INITRAMFS_OVERLAY}"
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

	if [ "${CMD_STATIC}" != '' ]
	then
		BUILD_STATIC=${CMD_STATIC}
	fi

	if isTrue ${BUILD_STATIC}
	then
		BUILD_STATIC=1
	else
		BUILD_STATIC=0
	fi

	if [ "${CMD_INITRAMFS}" != '' ]
	then
		BUILD_INITRAMFS=${CMD_INITRAMFS}
	fi

	if isTrue ${BUILD_INITRAMFS}
	then
		BUILD_INITRAMFS=1
	else
		BUILD_INITRAMFS=0
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
  
	if [ "${CMD_SYMLINK}" != '' ]
	then
		SYMLINK="${CMD_SYMLINK}"
	fi

	if isTrue "${SYMLINK}"
	then
		SYMLINK=1
	else
		SYMLINK=0
	fi
	
	if [ "${CMD_INSTALL_MOD_PATH}" != '' ]
	then
		INSTALL_MOD_PATH="${CMD_INSTALL_MOD_PATH}"
	fi

	if [ "${CMD_BOOTLOADER}" != '' ]
	then
		BOOTLOADER="${CMD_BOOTLOADER}"
                
		if [ "${CMD_BOOTLOADER}" != "${CMD_BOOTLOADER/:/}" ]
		then
			BOOTFS=`echo "${CMD_BOOTLOADER}" | cut -f2- -d:`
			BOOTLOADER=`echo "${CMD_BOOTLOADER}" | cut -f1 -d:`
		fi
	fi

	if [ "${CMD_OLDCONFIG}" != '' ]
	then
		OLDCONFIG="${CMD_OLDCONFIG}"
	fi

	if isTrue "${OLDCONFIG}"
	then
		OLDCONFIG=1
	else
		OLDCONFIG=0
	fi

	if isTrue "${CMD_LVM}"
	then
		LVM=1
	else
		LVM=0
	fi

	if isTrue "${CMD_EVMS}"
	then
		EVMS=1
	else
		EVMS=0
	fi
	
	if isTrue "${CMD_UNIONFS}"
	then
		UNIONFS=1
	else
		UNIONFS=0
	fi
	
	if isTrue "${CMD_NO_BUSYBOX}"
	then
		BUSYBOX=0
	else
		BUSYBOX=1
	fi

	if isTrue "${CMD_DMRAID}"
	then
		DMRAID=1
	else
		DMRAID=0
	fi
	
	if isTrue "${CMD_MDADM}"
	then
		MDADM=1
	else
		MDADM=0
	fi

	get_KV
	UNIONFS_MODULES_BINCACHE=`kv_replace "${UNIONFS_MODULES_BINCACHE}"`
}
