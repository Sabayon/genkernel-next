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
			if [ -f ${KERNEL_DIR}/include/linux/version.h ]
			then
				UTS_RELEASE=`grep UTS_RELEASE ${KERNEL_DIR}/include/linux/version.h | sed -e 's/#define UTS_RELEASE "\(.*\)"/\1/'`
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

	CACHE_DIR=`arch_replace "${CACHE_DIR}"`
	CACHE_CPIO_DIR="${CACHE_DIR}/cpio"
	BUSYBOX_BINCACHE=`cache_replace "${BUSYBOX_BINCACHE}"`
	MODULE_INIT_TOOLS_BINCACHE=`cache_replace "${MODULE_INIT_TOOLS_BINCACHE}"`
	MODUTILS_BINCACHE=`cache_replace "${MODUTILS_BINCACHE}"`
	DIETLIBC_BINCACHE=`cache_replace "${DIETLIBC_BINCACHE}"`
	DIETLIBC_BINCACHE_TEMP=`cache_replace "${DIETLIBC_BINCACHE_TEMP}"`
	DEVFSD_BINCACHE=`cache_replace "${DEVFSD_BINCACHE}"`
	DEVFSD_CONF_BINCACHE=`cache_replace "${DEVFSD_CONF_BINCACHE}"`
	UDEV_BINCACHE=`cache_replace "${UDEV_BINCACHE}"`
	KLIBC_BINCACHE=`cache_replace "${KLIBC_BINCACHE}"`
	DEVICE_MAPPER_BINCACHE=`cache_replace "${DEVICE_MAPPER_BINCACHE}"`
	LVM2_BINCACHE=`cache_replace "${LVM2_BINCACHE}"`
	DMRAID_BINCACHE=`cache_replace "${DMRAID_BINCACHE}"`
	UNIONFS_BINCACHE=`cache_replace "${UNIONFS_BINCACHE}"`
	UNIONFS_MODULES_BINCACHE=`cache_replace "${UNIONFS_MODULES_BINCACHE}"`
	BLKID_BINCACHE=`cache_replace "${BLKID_BINCACHE}"`
  
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
	KLIBC_BINCACHE=`arch_replace "${KLIBC_BINCACHE}"`
	DEVICE_MAPPER_BINCACHE=`arch_replace "${DEVICE_MAPPER_BINCACHE}"`
	LVM2_BINCACHE=`arch_replace "${LVM2_BINCACHE}"`
	DMRAID_BINCACHE=`arch_replace "${DMRAID_BINCACHE}"`
	UNIONFS_BINCACHE=`arch_replace "${UNIONFS_BINCACHE}"`
	UNIONFS_MODULES_BINCACHE=`arch_replace "${UNIONFS_MODULES_BINCACHE}"`
	BLKID_BINCACHE=`arch_replace "${BLKID_BINCACHE}"`
	
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

	if [ "${CMD_GENSPLASH}" != '' ]
	then
		GENSPLASH=${CMD_GENSPLASH}
	fi

	if isTrue ${GENSPLASH}
	then
		GENSPLASH=1
	else
		GENSPLASH=0
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
  
	if isTrue "${CMD_SYMLINK}"
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

	if isTrue "${CMD_OLDCONFIG}"
	then
		OLDCONFIG=1
	else
		OLDCONFIG=0
	fi

	if isTrue "${CMD_NO_UDEV}"
	then
		UDEV=0
		if isTrue "${CMD_NO_DEVFS}"
		then
		    DEVFS=0
		else
		    DEVFS=1
		fi
	else
		UDEV=1
		DEVFS=0
	fi
	
	if isTrue "${CMD_NO_DEVFS}"
	then
		DEVFS=0
	fi
	
	if isTrue "${CMD_DEVFS}"
	then
		DEVFS=1
		UDEV=0
	fi

	if isTrue "${CMD_LVM2}"
	then
		LVM2=1
	else
		LVM2=0
	fi
	
	if isTrue "${CMD_EVMS2}"
	then
		EVMS2=1
	else
		EVMS2=0
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
	
	get_KV
	UNIONFS_MODULES_BINCACHE=`kv_replace "${UNIONFS_MODULES_BINCACHE}"`
}
