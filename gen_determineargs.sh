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
}

determine_real_args() {
	print_info 4 "Resolving config file, command line, and arch default settings."

	#                          Config File          Command Line             Arch Default
	#                          -----------          ------------             ------------
	set_config_with_override 2 DEBUGFILE            CMD_DEBUGFILE
	set_config_with_override 2 KERNEL_DIR           CMD_KERNEL_DIR           "${DEFAULT_KERNEL_SOURCE}"
	set_config_with_override 1 NO_KERNEL_SOURCES    CMD_NO_KERNEL_SOURCES
	set_config_with_override 2 KERNCACHE            CMD_KERNCACHE
	set_config_with_override 2 KNAME                CMD_KERNNAME             "genkernel"

	set_config_with_override 2 MAKEOPTS             CMD_MAKEOPTS             "$DEFAULT_MAKEOPTS"
	set_config_with_override 2 KERNEL_MAKE          CMD_KERNEL_MAKE          "$DEFAULT_KERNEL_MAKE"
	set_config_with_override 2 UTILS_MAKE           CMD_UTILS_MAKE           "$DEFAULT_UTILS_MAKE"
	set_config_with_override 2 KERNEL_CC            CMD_KERNEL_CC            "$DEFAULT_KERNEL_CC"
	set_config_with_override 2 KERNEL_LD            CMD_KERNEL_LD            "$DEFAULT_KERNEL_LD"
	set_config_with_override 2 KERNEL_AS            CMD_KERNEL_AS            "$DEFAULT_KERNEL_AS"
	set_config_with_override 2 UTILS_CC             CMD_UTILS_CC             "$DEFAULT_UTILS_CC"
	set_config_with_override 2 UTILS_LD             CMD_UTILS_LD             "$DEFAULT_UTILS_LD"
	set_config_with_override 2 UTILS_AS             CMD_UTILS_AS             "$DEFAULT_UTILS_AS"

	set_config_with_override 2 KERNEL_CROSS_COMPILE CMD_KERNEL_CROSS_COMPILE
	set_config_with_override 2 UTILS_CROSS_COMPILE  CMD_UTILS_CROSS_COMPILE
	set_config_with_override 2 BOOTDIR              CMD_BOOTDIR              "/boot"

	set_config_with_override 1 SPLASH               CMD_SPLASH
	set_config_with_override 1 POSTCLEAR            CMD_POSTCLEAR
	set_config_with_override 1 MRPROPER             CMD_MRPROPER
	set_config_with_override 1 MENUCONFIG           CMD_MENUCONFIG
	set_config_with_override 1 CLEAN                CMD_CLEAN

	set_config_with_override 2 MINKERNPACKAGE       CMD_MINKERNPACKAGE
	set_config_with_override 2 MODULESPACKAGE       CMD_MODULESPACKAGE
	set_config_with_override 2 KERNCACHE            CMD_KERNCACHE
	set_config_with_override 1 NOINITRDMODULES      CMD_NOINITRDMODULES
	set_config_with_override 2 INITRAMFS_OVERLAY    CMD_INITRAMFS_OVERLAY
	set_config_with_override 1 MOUNTBOOT            CMD_MOUNTBOOT
	set_config_with_override 1 BUILD_STATIC         CMD_STATIC
	set_config_with_override 1 BUILD_INITRAMFS      CMD_INITRAMFS
	set_config_with_override 1 SAVE_CONFIG          CMD_SAVE_CONFIG
 	set_config_with_override 1 SYMLINK              CMD_SYMLINK
	set_config_with_override 2 INSTALL_MOD_PATH     CMD_INSTALL_MOD_PATH
	set_config_with_override 1 OLDCONFIG            CMD_OLDCONFIG
	set_config_with_override 1 LVM                  CMD_LVM
	set_config_with_override 1 EVMS                 CMD_EVMS
	set_config_with_override 1 UNIONFS              CMD_UNIONFS
	set_config_with_override 1 DMRAID               CMD_DMRAID
	set_config_with_override 1 BUSYBOX              CMD_BUSYBOX              "yes"
	set_config_with_override 1 DEVFS                CMD_UNDEFINED_CMD        "no"
	
	set_config_with_override 1 DISKLABEL            CMD_DISKLABEL
	set_config_with_override 1 LUKS                 CMD_LUKS
	set_config_with_override 1 MDADM                CMD_MDADM

		BOOTDIR=`arch_replace "${BOOTDIR}"`
		BOOTDIR=${BOOTDIR%/}    # Remove any trailing slash

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
	

	if [ "${CMD_BOOTLOADER}" != '' ]
	then
		BOOTLOADER="${CMD_BOOTLOADER}"

		if [ "${CMD_BOOTLOADER}" != "${CMD_BOOTLOADER/:/}" ]
	then
			BOOTFS=`echo "${CMD_BOOTLOADER}" | cut -f2- -d:`
			BOOTLOADER=`echo "${CMD_BOOTLOADER}" | cut -f1 -d:`
	fi
	fi

	if [ "${NO_KERNEL_SOURCES}" != "1" ]
	then
		if [ ! -d ${KERNEL_DIR} ]
	then
			gen_die "kernel source directory \"${KERNEL_DIR}\" was not found!"
	fi
	fi

	if [ -z "${KERNCACHE}" ]
	then
		if [ "${KERNEL_DIR}" = '' -a "${NO_KERNEL_SOURCES}" != "1" ]
	then
			gen_die 'No kernel source directory!'
	fi
		if [ ! -e "${KERNEL_DIR}" -a "${NO_KERNEL_SOURCES}" != "1" ]
	then
			gen_die 'No kernel source directory!'
	fi
	else
		if [ "${KERNEL_DIR}" = '' ]
		then
			gen_die 'Kernel Cache specified but no kernel tree to verify against!'
	fi
	fi

	# Special case:  If --no-clean is specified on the command line, 
	# imply --no-mrproper.
	if [ "${CMD_CLEAN}" != '' ]
	then
		if ! isTrue ${CLEAN}
	then
			MRPROPER=0
	fi
	fi
	
	if [ -n "${MINKERNPACKAGE}" ]
	then
		mkdir -p `dirname ${MINKERNPACKAGE}`
	fi
	
	if [ -n "${MODULESPACKAGE}" ]
	then
		mkdir -p `dirname ${MODULESPACKAGE}`
	fi

	if [ -n "${KERNCACHE}" ]
	then
		mkdir -p `dirname ${KERNCACHE}`
	fi
	
	get_KV
	UNIONFS_MODULES_BINCACHE=`kv_replace "${UNIONFS_MODULES_BINCACHE}"`
}
