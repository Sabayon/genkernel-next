#!/bin/bash

compile_kernel_args()
{
	local ARGS

	ARGS=''
	if [ "${KERNEL_CROSS_COMPILE}" != '' ]
	then
		ARGS="${ARGS} CROSS_COMPILE=\"${KERNEL_CROSS_COMPILE}\""
	else
		if [ "${KERNEL_CC}" != '' ]
		then
			ARGS="CC=\"${KERNEL_CC}\""
		fi
		if [ "${KERNEL_LD}" != '' ]
		then
			ARGS="${ARGS} LD=\"${KERNEL_LD}\""
		fi
		if [ "${KERNEL_AS}" != '' ]
		then
			ARGS="${ARGS} AS=\"${KERNEL_AS}\""
		fi
	fi
	echo -n "${ARGS}"
}

compile_utils_args()
{
	local ARGS

	ARGS=''
	if [ "${UTILS_ARCH}" != '' ]
	then
		ARGS="ARCH=\"${UTILS_ARCH}\""
	fi
	if [ "${UTILS_CC}" != '' ]
	then
		ARGS="CC=\"${UTILS_CC}\""
	fi
	if [ "${UTILS_LD}" != '' ]
	then
		ARGS="${ARGS} LD=\"${UTILS_LD}\""
	fi
	if [ "${UTILS_AS}" != '' ]
	then
		ARGS="${ARGS} AS=\"${UTILS_AS}\""
	fi

	echo -n "${ARGS}"
}

export_utils_args()
{
	save_args
	if [ "${UTILS_ARCH}" != '' ]
	then
		export ARCH="${UTILS_ARCH}"
	fi
	if [ "${UTILS_CC}" != '' ]
	then
		export CC="${UTILS_CC}"
	fi
	if [ "${UTILS_LD}" != '' ]
	then
		export LD="${UTILS_LD}"
	fi
	if [ "${UTILS_AS}" != '' ]
	then
		export AS="${UTILS_AS}"
	fi
}

unset_utils_args()
{
	if [ "${UTILS_ARCH}" != '' ]
	then
		unset ARCH
	fi
	if [ "${UTILS_CC}" != '' ]
	then
		unset CC
	fi
	if [ "${UTILS_LD}" != '' ]
	then
		unset LD
	fi
	if [ "${UTILS_AS}" != '' ]
	then
		unset AS
	fi
	reset_args
}

export_kernel_args()
{
	if [ "${KERNEL_CC}" != '' ]
	then
		export CC="${KERNEL_CC}"
	fi
	if [ "${KERNEL_LD}" != '' ]
	then
		export LD="${KERNEL_LD}"
	fi
	if [ "${KERNEL_AS}" != '' ]
	then
		export AS="${KERNEL_AS}"
	fi
	if [ "${KERNEL_CROSS_COMPILE}" != '' ]
	then
		export CROSS_COMPILE="${KERNEL_CROSS_COMPILE}"
	fi
}

unset_kernel_args()
{
	if [ "${KERNEL_CC}" != '' ]
	then
		unset CC
	fi
	if [ "${KERNEL_LD}" != '' ]
	then
		unset LD
	fi
	if [ "${KERNEL_AS}" != '' ]
	then
		unset AS
	fi
	if [ "${KERNEL_CROSS_COMPILE}" != '' ]
	then
		unset CROSS_COMPILE
	fi
}
save_args()
{
	if [ "${ARCH}" != '' ]
	then
		export ORIG_ARCH="${ARCH}"
	fi
	if [ "${CC}" != '' ]
	then
		export ORIG_CC="${CC}"
	fi
	if [ "${LD}" != '' ]
	then
		export ORIG_LD="${LD}"
	fi
	if [ "${AS}" != '' ]
	then
		export ORIG_AS="${AS}"
	fi
	if [ "${CROSS_COMPILE}" != '' ]
	then
		export ORIG_CROSS_COMPILE="${CROSS_COMPILE}"
	fi
}
reset_args()
{
	if [ "${ORIG_ARCH}" != '' ]
	then
		export ARCH="${ORIG_ARCH}"
		unset ORIG_ARCH
	fi
	if [ "${ORIG_CC}" != '' ]
	then
		export CC="${ORIG_CC}"
		unset ORIG_CC
	fi
	if [ "${ORIG_LD}" != '' ]
	then
		export LD="${ORIG_LD}"
		unset ORIG_LD
	fi
	if [ "${ORIG_AS}" != '' ]
	then
		export AS="${ORIG_AS}"
		unset ORIG_AS
	fi
	if [ "${ORIG_CROSS_COMPILE}" != '' ]
	then
		export CROSS_COMPILE="${ORIG_CROSS_COMPILE}"
		unset ORIG_CROSS_COMPILE
	fi
}

compile_generic() {
	local RET
	[ "$#" -lt '2' ] &&
		gen_die 'compile_generic(): improper usage!'

	if [ "${2}" = 'kernel' ] || [ "${2}" = 'runtask' ]
	then
		export_kernel_args
		MAKE=${KERNEL_MAKE}
	elif [ "${2}" = 'utils' ]
	then
		export_utils_args
		MAKE=${UTILS_MAKE}
	fi
	case "$2" in
		kernel) ARGS="`compile_kernel_args`" ;;
		utils) ARGS="`compile_utils_args`" ;;
		*) ARGS="" ;; # includes runtask
	esac
		

	# the eval usage is needed in the next set of code
	# as ARGS can contain spaces and quotes, eg:
	# ARGS='CC="ccache gcc"'
	if [ "${2}" == 'runtask' ]
	then
		print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS/-j?/j1} ${ARGS} ${1}" 1 0 1
		eval ${MAKE} -s ${MAKEOPTS/-j?/-j1} "${ARGS}" ${1}
		RET=$?
	elif [ "${DEBUGLEVEL}" -gt "1" ]
	then
		# Output to stdout and debugfile
		print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} ${ARGS} ${1}" 1 0 1
		eval ${MAKE} ${MAKEOPTS} ${ARGS} ${1} 2>&1 | tee -a ${DEBUGFILE}
		RET=${PIPESTATUS[0]}
	else
		# Output to debugfile only
		print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} ${ARGS} ${1}" 1 0 1
		eval ${MAKE} ${MAKEOPTS} ${ARGS} ${1} >> ${DEBUGFILE} 2>&1
		RET=$?
	fi
	[ "${RET}" -ne '0' ] &&
		gen_die "Failed to compile the \"${1}\" target..."

	unset MAKE
	unset ARGS
	if [ "${2}" = 'kernel' ]
	then
		unset_kernel_args
	elif [ "${2}" = 'utils' ]
	then
		unset_utils_args
	fi
}

extract_dietlibc_bincache() {
	cd "${TEMP}"
	rm -rf "${TEMP}/diet" > /dev/null
	/bin/tar -jxpf "${DIETLIBC_BINCACHE}" ||
		gen_die 'Could not extract dietlibc bincache!'
	[ ! -d "${TEMP}/diet" ] &&
		gen_die "${TEMP}/diet directory not found!"
	cd - > /dev/null
}

clean_dietlibc_bincache() {
	cd "${TEMP}"
	rm -rf "${TEMP}/diet" > /dev/null
	cd - > /dev/null
}

compile_dep() {
	# Only run ``make dep'' for 2.4 kernels
	if [ "${VER}" -eq '2' -a "${KERN_24}" -eq '1' ]
	then
		print_info 1 "kernel: >> Making dependencies..."
		cd ${KERNEL_DIR}
		compile_generic dep kernel
	fi
}

compile_modules() {
	print_info 1 "        >> Compiling ${KV} modules..."
	cd ${KERNEL_DIR}
	compile_generic modules kernel
	export UNAME_MACHINE="${ARCH}"
	# On 2.4 kernels, if MAKEOPTS > -j1 it can cause failures
	if [ "${VER}" -eq '2' -a "${KERN_24}" -eq '1' ]
	then
		MAKEOPTS_SAVE="${MAKEOPTS}"
		MAKEOPTS="${MAKEOPTS_SAVE/-j?/-j1}"
	fi
	[ "${INSTALL_MOD_PATH}" != '' ] && export INSTALL_MOD_PATH
	compile_generic "modules_install" kernel
	[ "${VER}" -eq '2' -a "${KERN_24}" -eq '1' ] && MAKEOPTS="${MAKEOPTS_SAVE}"
	export MAKEOPTS
	unset UNAME_MACHINE
}

compile_kernel() {
	[ "${KERNEL_MAKE}" = '' ] &&
		gen_die "KERNEL_MAKE undefined - I don't know how to compile a kernel for this arch!"
	cd ${KERNEL_DIR}
	print_info 1 "        >> Compiling ${KV} ${KERNEL_MAKE_DIRECTIVE/_install/ [ install ]/}..."
	compile_generic "${KERNEL_MAKE_DIRECTIVE}" kernel
	if [ "${KERNEL_MAKE_DIRECTIVE_2}" != '' ]
	then
		print_info 1 "        >> Starting supplimental compile of ${KV}: ${KERNEL_MAKE_DIRECTIVE_2}..."
		compile_generic "${KERNEL_MAKE_DIRECTIVE_2}" kernel
	fi
	if ! isTrue "${CMD_NOINSTALL}"
	then
		cp "${KERNEL_BINARY}" "/boot/kernel-${KNAME}-${ARCH}-${KV}" ||
			gen_die 'Could not copy the kernel binary to /boot!'
		cp "System.map" "/boot/System.map-${KNAME}-${ARCH}-${KV}" ||
			gen_die 'Could not copy System.map to /boot!'
		if [ "${KERNEL_BINARY_2}" != '' -a "${GENERATE_Z_IMAGE}" = '1' ]
		then
			cp "${KERNEL_BINARY_2}" "/boot/kernelz-${KV}" ||
				gen_die 'Could not copy the kernelz binary to /boot!'
		fi
	else
		cp "${KERNEL_BINARY}" "${TMPDIR}/kernel-${KNAME}-${ARCH}-${KV}" ||
			gen_die "Could not copy the kernel binary to ${TMPDIR}!"
		cp "System.map" "${TMPDIR}/System.map-${KNAME}-${ARCH}-${KV}" ||
			gen_die "Could not copy System.map to ${TMPDIR}!"
		if [ "${KERNEL_BINARY_2}" != '' -a "${GENERATE_Z_IMAGE}" = '1' ]
		then
			cp "${KERNEL_BINARY_2}" "${TMPDIR}/kernelz-${KV}" ||
				gen_die "Could not copy the kernelz binary to ${TMPDIR}!"
		fi
	fi
}

compile_unionfs_modules() {
	if [ ! -f "${UNIONFS_MODULES_BINCACHE}" ]
	then
		[ -f "${UNIONFS_SRCTAR}" ] ||
			gen_die "Could not find unionfs source tarball: ${UNIONFS_SRCTAR}!"
		cd "${TEMP}"
		rm -rf ${UNIONFS_DIR} > /dev/null
		rm -rf unionfs > /dev/null
		mkdir -p unionfs
		/bin/tar -zxpf ${UNIONFS_SRCTAR} ||
			gen_die 'Could not extract unionfs source tarball!'
		[ -d "${UNIONFS_DIR}" ] ||
			gen_die 'Unionfs directory ${UNIONFS_DIR} is invalid!'
		cd "${UNIONFS_DIR}"
		print_info 1 'unionfs modules: >> Compiling...'
		echo "LINUXSRC=${KERNEL_DIR}" >> fistdev.mk
		echo 'TOPINC=-I$(LINUXSRC)/include' >> fistdev.mk
		echo "MODDIR= /lib/modules/${KV}" >> fistdev.mk
		echo "KERNELVERSION=${KV}" >> fistdev.mk
		# Fix for hardened/selinux systems to have extened attributes
		# per r2d2's request
		echo "EXTRACFLAGS=-DUNIONFS_XATTR -DFIST_SETXATTR_CONSTVOID" \
			>> fistdev.mk
		# Here we do something really nasty and disable debugging, along with
		# change our default CFLAGS
		echo "UNIONFS_DEBUG_CFLAG=-DUNIONFS_NDEBUG" >> fistdev.mk
		echo "UNIONFS_OPT_CFLAG= -O2 -pipe" >> fistdev.mk

		if [ "${PAT}" -ge '6' ]
		then
			cd "${TEMP}"
			cd "${UNIONFS_DIR}"
			# Compile unionfs module within the unionfs
			# environment not within the kernelsrc dir
			make unionfs.ko
		else
			gen_die 'unionfs is only supported on 2.6 targets'
		fi
		print_info 1 'unionfs: >> Copying to cache...'
	
		mkdir -p ${TEMP}/unionfs/lib/modules/${KV}/kernel/fs
		
		if [ -f unionfs.ko ]
		then 
			cp unionfs.ko ${TEMP}/unionfs/lib/modules/${KV}/kernel/fs 
		else 
			cp unionfs.o ${TEMP}/unionfs/lib/modules/${KV}/kernel/fs 
 		fi
	
		cd ${TEMP}/unionfs	
		/bin/tar -cjf "${UNIONFS_MODULES_BINCACHE}" . ||
			gen_die 'Could not create unionfs modules binary cache'
	
		cd "${TEMP}"
		rm -rf "${UNIONFS_DIR}" > /dev/null
		rm -rf unionfs > /dev/null
	fi
}

compile_unionfs_utils() {
	if [ ! -f "${UNIONFS_BINCACHE}" ]
	then
		[ -f "${UNIONFS_SRCTAR}" ] ||
			gen_die "Could not find unionfs source tarball: ${UNIONFS_SRCTAR}!"
		cd "${TEMP}"
		rm -rf ${UNIONFS_DIR} > /dev/null
		rm -rf unionfs > /dev/null
		mkdir -p unionfs/sbin
		/bin/tar -zxpf ${UNIONFS_SRCTAR} ||
			gen_die 'Could not extract unionfs source tarball!'
		[ -d "${UNIONFS_DIR}" ] ||
			gen_die 'Unionfs directory ${UNIONFS_DIR} is invalid!'
		cd "${UNIONFS_DIR}"
		print_info 1 'unionfs tools: >> Compiling...'
		sed -i Makefile -e 's|${CC} -o|${CC} -static -o|g'
		compile_generic utils utils
		
		print_info 1 'unionfs: >> Copying to cache...'
		strip uniondbg unionctl
		cp uniondbg ${TEMP}/unionfs/sbin/ || 
			gen_die 'Could not copy the uniondbg binary to the tmp directory'
		cp unionctl ${TEMP}/unionfs/sbin/ ||
			gen_die 'Could not copy the unionctl binary to the tmp directory'
		cd ${TEMP}/unionfs	
		/bin/tar -cjf "${UNIONFS_BINCACHE}" . ||
			gen_die 'Could not create unionfs tools binary cache'
		
		cd "${TEMP}"
		rm -rf "${UNIONFS_DIR}" > /dev/null
		rm -rf unionfs > /dev/null
	fi
}

compile_busybox() {
	if [ ! -f "${BUSYBOX_BINCACHE}" ]
	then
		[ -f "${BUSYBOX_SRCTAR}" ] ||
			gen_die "Could not find busybox source tarball: ${BUSYBOX_SRCTAR}!"
		[ -f "${BUSYBOX_CONFIG}" ] ||
			gen_die "Cound not find busybox config file: ${BUSYBOX_CONFIG}!"
		cd "${TEMP}"
		rm -rf ${BUSYBOX_DIR} > /dev/null
		/bin/tar -jxpf ${BUSYBOX_SRCTAR} ||
			gen_die 'Could not extract busybox source tarball!'
		[ -d "${BUSYBOX_DIR}" ] ||
			gen_die 'Busybox directory ${BUSYBOX_DIR} is invalid!'
		cp "${BUSYBOX_CONFIG}" "${BUSYBOX_DIR}/.config"
		sed -i ${BUSYBOX_DIR}/.config -e 's/#\? \?CONFIG_FEATURE_INSTALLER[ =].*/CONFIG_FEATURE_INSTALLER=y/g'
		cd "${BUSYBOX_DIR}"
		if [ -f ${GK_SHARE}/pkg/busybox-1.00-headers_fix.patch ]
		then
			patch -p1 -i \
				${GK_SHARE}/pkg/busybox-1.00-headers_fix.patch \
				|| gen_die "Failed patching busybox"
		fi
		print_info 1 'busybox: >> Configuring...'
		yes '' 2>/dev/null | compile_generic oldconfig utils
		print_info 1 'busybox: >> Compiling...'
		compile_generic all utils
		print_info 1 'busybox: >> Copying to cache...'
		[ -f "${TEMP}/${BUSYBOX_DIR}/busybox" ] ||
			gen_die 'Busybox executable does not exist!'
		strip "${TEMP}/${BUSYBOX_DIR}/busybox" ||
			gen_die 'Could not strip busybox binary!'
		bzip2 "${TEMP}/${BUSYBOX_DIR}/busybox" ||
			gen_die 'bzip2 compression of busybox failed!'
		mv "${TEMP}/${BUSYBOX_DIR}/busybox.bz2" "${BUSYBOX_BINCACHE}" ||
			gen_die 'Could not copy the busybox binary to the package directory, does the directory exist?'

		cd "${TEMP}"
		rm -rf "${BUSYBOX_DIR}" > /dev/null
	fi
}

compile_lvm2() {
	compile_device_mapper
	if [ ! -f "${LVM2_BINCACHE}" ]
	then
		[ -f "${LVM2_SRCTAR}" ] ||
			gen_die "Could not find LVM2 source tarball: ${LVM2_SRCTAR}! Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf ${LVM2_DIR} > /dev/null
		/bin/tar -zxpf ${LVM2_SRCTAR} ||
			gen_die 'Could not extract LVM2 source tarball!'
		[ -d "${LVM2_DIR}" ] ||
			gen_die 'LVM2 directory ${LVM2_DIR} is invalid!'
		rm -rf "${TEMP}/device-mapper" > /dev/null
		/bin/tar -jxpf "${DEVICE_MAPPER_BINCACHE}" -C "${TEMP}" ||
			gen_die "Could not extract device-mapper binary cache!";
		
		cd "${LVM2_DIR}"
		print_info 1 'lvm2: >> Configuring...'
			LDFLAGS="-L${TEMP}/device-mapper/lib" \
			CFLAGS="-I${TEMP}/device-mapper/include" \
			CPPFLAGS="-I${TEMP}/device-mapper/include" \
			./configure --enable-static_link --prefix=${TEMP}/lvm2 >> ${DEBUGFILE} 2>&1 ||
				gen_die 'Configure of lvm2 failed!'
		print_info 1 'lvm2: >> Compiling...'
			compile_generic '' utils
			compile_generic 'install' utils

		cd "${TEMP}/lvm2"
		print_info 1 '      >> Copying to bincache...'
		strip "sbin/lvm.static" ||
			gen_die 'Could not strip lvm.static!'
		/bin/tar -cjf "${LVM2_BINCACHE}" sbin/lvm.static ||
			gen_die 'Could not create binary cache'

		cd "${TEMP}"
		rm -rf "${TEMP}/device-mapper" > /dev/null
		rm -rf "${LVM2_DIR}" lvm2
	fi
}

compile_dmraid() {
	compile_device_mapper
	if [ ! -f "${DMRAID_BINCACHE}" ]
	then
		[ -f "${DMRAID_SRCTAR}" ] ||
			gen_die "Could not find DMRAID source tarball: ${DMRAID_SRCTAR}! Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf ${DMRAID_DIR} > /dev/null
		/bin/tar -jxpf ${DMRAID_SRCTAR} ||
			gen_die 'Could not extract DMRAID source tarball!'
		[ -d "${DMRAID_DIR}" ] ||
			gen_die 'DMRAID directory ${DMRAID_DIR} is invalid!'
		rm -rf "${TEMP}/device-mapper" > /dev/null
		/bin/tar -jxpf "${DEVICE_MAPPER_BINCACHE}" -C "${TEMP}" ||
			gen_die "Could not extract device-mapper binary cache!";
		
		cd "${DMRAID_DIR}"
		print_info 1 'dmraid: >> Configuring...'
		
			LDFLAGS="-L${TEMP}/device-mapper/lib" \
			CFLAGS="-I${TEMP}/device-mapper/include" \
			CPPFLAGS="-I${TEMP}/device-mapper/include" \
			./configure --enable-static_link --prefix=${TEMP}/dmraid >> ${DEBUGFILE} 2>&1 ||
				gen_die 'Configure of dmraid failed!'
				
			#We dont necessarily have selinux installed yet .. look into selinux global support in the future.
			sed -i tools/Makefile -e "s|DMRAIDLIBS += -lselinux||g"
		mkdir -p "${TEMP}/dmraid"
		print_info 1 'dmraid: >> Compiling...'
			compile_generic '' utils
			#compile_generic 'install' utils
			mkdir ${TEMP}/dmraid/sbin
			install -m 0755 -s tools/dmraid "${TEMP}/dmraid/sbin/dmraid"
		print_info 1 '      >> Copying to bincache...'
		cd "${TEMP}/dmraid"
		/bin/tar -cjf "${DMRAID_BINCACHE}" sbin/dmraid ||
			gen_die 'Could not create binary cache'

		cd "${TEMP}"
		rm -rf "${TEMP}/device-mapper" > /dev/null
		rm -rf "${DMRAID_DIR}" dmraid
	fi
}

compile_modutils() {
	# I've disabled dietlibc support for the time being since the
	# version we use misses a few needed system calls.

	local ARGS
	if [ ! -f "${MODUTILS_BINCACHE}" ]
	then
		[ ! -f "${MODUTILS_SRCTAR}" ] &&
			gen_die "Could not find modutils source tarball: ${MODUTILS_SRCTAR}!"
		cd "${TEMP}"
		rm -rf "${MODUTILS_DIR}"
		/bin/tar -jxpf "${MODUTILS_SRCTAR}"
		[ ! -d "${MODUTILS_DIR}" ] &&
			gen_die "Modutils directory ${MODUTILS_DIR} invalid!"
		cd "${MODUTILS_DIR}"
		print_info 1 "modutils: >> Configuring..."

#		if [ "${USE_DIETLIBC}" -eq '1' ]
#		then
#			extract_dietlibc_bincache
#			OLD_CC="${UTILS_CC}"
#			UTILS_CC="${TEMP}/diet/bin/diet ${UTILS_CC}"
#		fi

		export_utils_args
		export ARCH=${ARCH}
		./configure --disable-combined --enable-insmod-static >> ${DEBUGFILE} 2>&1 ||
			gen_die 'Configuring modutils failed!'
		unset_utils_args

		print_info 1 'modutils: >> Compiling...'
		compile_generic all utils

#		if [ "${USE_DIETLIBC}" -eq '1' ]
#		then
#			clean_dietlibc_bincache
#			UTILS_CC="${OLD_CC}"
#		fi

		print_info 1 'modutils: >> Copying to cache...'
		[ -f "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" ] ||
			gen_die 'insmod.static does not exist after the compilation of modutils!'
		strip "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" ||
			gen_die 'Could not strip insmod.static!'
		bzip2 "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" ||
			gen_die 'Compression of insmod.static failed!'
		mv "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static.bz2" "${MODUTILS_BINCACHE}" ||
			gen_die 'Could not move the compressed insmod binary to the package cache!'

		cd "${TEMP}"
		rm -rf "${MODULE_INIT_TOOLS_DIR}" > /dev/null
	fi
}

compile_module_init_tools() {
	# I've disabled dietlibc support for the time being since the
	# version we use misses a few needed system calls.

	local ARGS
	if [ ! -f "${MODULE_INIT_TOOLS_BINCACHE}" ]
	then
		[ ! -f "${MODULE_INIT_TOOLS_SRCTAR}" ] &&
			gen_die "Could not find module-init-tools source tarball: ${MODULE_INIT_TOOLS_SRCTAR}"
		cd "${TEMP}"
		rm -rf "${MODULE_INIT_TOOLS_DIR}"
		/bin/tar -jxpf "${MODULE_INIT_TOOLS_SRCTAR}"
		[ ! -d "${MODULE_INIT_TOOLS_DIR}" ] &&
			gen_die "Module-init-tools directory ${MODULE_INIT_TOOLS_DIR} is invalid"
		cd "${MODULE_INIT_TOOLS_DIR}"
		print_info 1 'module-init-tools: >> Configuring'

#		if [ "${USE_DIETLIBC}" -eq '1' ]
#		then
#			extract_dietlibc_bincache
#			OLD_CC="${UTILS_CC}"
#			UTILS_CC="${TEMP}/diet/bin/diet ${UTILS_CC}"
#		fi

		export_utils_args
		./configure >> ${DEBUGFILE} 2>&1 ||
			gen_die 'Configure of module-init-tools failed!'
		unset_utils_args
		print_info 1 '                   >> Compiling...'
		compile_generic "all" utils

# 		if [ "${USE_DIETLIBC}" -eq '1' ]
#		then
#			clean_dietlibc_bincache
#			UTILS_CC="${OLD_CC}"
#		fi

		print_info 1 '                   >> Copying to cache...'
		[ -f "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" ] ||
			gen_die 'insmod.static does not exist after the compilation of module-init-tools!'
		strip "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" ||
			gen_die 'Could not strip insmod.static!'
		bzip2 "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" ||
			gen_die 'Compression of insmod.static failed!'
		[ -f "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static.bz2" ] ||
			gen_die 'Could not find compressed insmod.static.bz2 binary!'
		mv "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static.bz2" "${MODULE_INIT_TOOLS_BINCACHE}" ||
			gen_die 'Could not move the compressed insmod binary to the package cache!'

		cd "${TEMP}"
		rm -rf "${MODULE_INIT_TOOLS_DIR}" > /dev/null
	fi
}

compile_devfsd() {
	# I've disabled dietlibc support for the time being since the
	# version we use misses a few needed system calls.

	local ARGS
	if [ ! -f "${DEVFSD_BINCACHE}" ]
	then
		[ ! -f "${DEVFSD_SRCTAR}" ] &&
			gen_die "Could not find devfsd source tarball: ${DEVFSD_SRCTAR}"
		cd "${TEMP}"
		rm -rf "${DEVFSD_DIR}"
		/bin/tar -jxpf "${DEVFSD_SRCTAR}"
		[ ! -d "${DEVFSD_DIR}" ] &&
			gen_die "Devfsd directory ${DEVFSD_DIR} invalid"
		cd "${DEVFSD_DIR}"

#		if [ "${USE_DIETLIBC}" -eq '1' ]
#		then
#			extract_dietlibc_bincache
#			OLD_CC="${UTILS_CC}"
#			UTILS_CC="${TEMP}/diet/bin/diet ${UTILS_CC}"
#		fi

		print_info 1 'devfsd: >> Compiling...'
#		if [ "${USE_DIETLIBC}" -eq '1' ]
#		then
#			compile_generic 'has_dlopen=0 has_rpcsvc=0' utils
#		else
			compile_generic 'LDFLAGS=-static' utils
#		fi

#		if [ "${USE_DIETLIBC}" -eq '1' ]
#		then
#			clean_dietlibc_bincache
#			UTILS_CC="${OLD_CC}"
#		fi

		print_info 1 '        >> Copying to cache...'
		[ -f "${TEMP}/${DEVFSD_DIR}/devfsd" ] || gen_die 'The devfsd executable does not exist after the compilation of devfsd!'
		strip "${TEMP}/${DEVFSD_DIR}/devfsd" || gen_die 'Could not strip devfsd!'
		bzip2 "${TEMP}/${DEVFSD_DIR}/devfsd" || gen_die 'Compression of devfsd failed!'
		[ -f "${TEMP}/${DEVFSD_DIR}/devfsd.bz2" ] || gen_die 'Could not find compressed devfsd.bz2 binary!'
		mv "${TEMP}/${DEVFSD_DIR}/devfsd.bz2" "${DEVFSD_BINCACHE}" || gen_die 'Could not move compressed binary to the package cache!'

#		[ -f "${TEMP}/${DEVFSD_DIR}/devfsd.conf" ] || gen_die 'devfsd.conf does not exist after the compilation of devfsd!'
#		bzip2 "${TEMP}/${DEVFSD_DIR}/devfsd.conf" || gen_die 'Compression of devfsd.conf failed!'
#		mv "${TEMP}/${DEVFSD_DIR}/devfsd.conf.bz2" "${DEVFSD_CONF_BINCACHE}" || gen_die 'Could not move the compressed configuration to the package cache!'

		cd "${TEMP}"
		rm -rf "${DEVFSD_DIR}" > /dev/null
	fi
}

compile_device_mapper() {
	if [ ! -f "${DEVICE_MAPPER_BINCACHE}" ]
	then
		[ ! -f "${DEVICE_MAPPER_SRCTAR}" ] &&
			gen_die "Could not find device-mapper source tarball: ${DEVICE_MAPPER_SRCTAR}. Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf "${DEVICE_MAPPER_DIR}"
		/bin/tar -zxpf "${DEVICE_MAPPER_SRCTAR}"
		[ ! -d "${DEVICE_MAPPER_DIR}" ] &&
			gen_die "device-mapper directory ${DEVICE_MAPPER_DIR} invalid"
		cd "${DEVICE_MAPPER_DIR}"
		./configure  --prefix=${TEMP}/device-mapper --enable-static_link >> ${DEBUGFILE} 2>&1 ||
			gen_die 'Configuring device-mapper failed!'
		print_info 1 'device-mapper: >> Compiling...'
		compile_generic '' utils
		compile_generic 'install' utils
		print_info 1 '        >> Copying to cache...'
		cd "${TEMP}"
		rm -r "${TEMP}/device-mapper/man" ||
			gen_die 'Could not remove manual pages!'
		strip "${TEMP}/device-mapper/sbin/dmsetup" ||
			gen_die 'Could not strip dmsetup binary!'
		/bin/tar -jcpf "${DEVICE_MAPPER_BINCACHE}" device-mapper ||
			gen_die 'Could not tar up the device-mapper binary!'
		[ -f "${DEVICE_MAPPER_BINCACHE}" ] ||
			gen_die 'device-mapper cache not created!'
		cd "${TEMP}"
		rm -rf "${DEVICE_MAPPER_DIR}" > /dev/null
		rm -rf "${TEMP}/device-mapper" > /dev/null
	fi
}

compile_dietlibc() {
	local BUILD_DIETLIBC
	local ORIGTEMP

	BUILD_DIETLIBC=0
	[ ! -f "${DIETLIBC_BINCACHE}" ] && BUILD_DIETLIBC=1
	[ ! -f "${DIETLIBC_BINCACHE_TEMP}" ] && BUILD_DIETLIBC=1
	if ! isTrue "${BUILD_DIETLIBC}"
	then
		ORIGTEMP=`cat "${DIETLIBC_BINCACHE_TEMP}"`
		if [ "${TEMP}" != "${ORIGTEMP}" ]
		then
			print_warning 1 'dietlibc: Bincache exists, but the current temporary directory'
			print_warning 1 '          is different to the original. Rebuilding.'
			BUILD_DIETLIBC=1
		fi
	fi

	if [ "${BUILD_DIETLIBC}" -eq '1' ]
	then
		[ -f "${DIETLIBC_SRCTAR}" ] ||
			gen_die "Could not find dietlibc source tarball: ${DIETLIBC_SRCTAR}"
		cd "${TEMP}"
		rm -rf "${DIETLIBC_DIR}" > /dev/null
		/bin/tar -jxpf "${DIETLIBC_SRCTAR}" ||
			gen_die 'Could not extract dietlibc source tarball'
		[ -d "${DIETLIBC_DIR}" ] ||
			gen_die "Dietlibc directory ${DIETLIBC_DIR} is invalid!"
		cd "${DIETLIBC_DIR}"
		print_info 1 "dietlibc: >> Compiling..."
		compile_generic "prefix=${TEMP}/diet" utils
		print_info 1 "          >> Installing..."
		compile_generic "prefix=${TEMP}/diet install" utils
		print_info 1 "          >> Copying to bincache..."
		cd ${TEMP}
		/bin/tar -jcpf "${DIETLIBC_BINCACHE}" diet ||
			gen_die 'Could not tar up the dietlibc binary!'
		[ -f "${DIETLIBC_BINCACHE}" ] ||
			gen_die 'Dietlibc cache not created!'
		echo "${TEMP}" > "${DIETLIBC_BINCACHE_TEMP}"

		cd "${TEMP}"
		rm -rf "${DIETLIBC_DIR}" > /dev/null
		rm -rf "${TEMP}/diet" > /dev/null
	fi
}
compile_klibc() {
	cd "${TEMP}"
	rm -rf "${KLIBC_DIR}" klibc-build
	[ ! -f "${KLIBC_SRCTAR}" ] &&
		gen_die "Could not find klibc tarball: ${KLIBC_SRCTAR}"
	/bin/tar jxpf "${KLIBC_SRCTAR}" ||
		gen_die 'Could not extract klibc tarball'
	[ ! -d "${KLIBC_DIR}" ] &&
		gen_die "klibc tarball ${KLIBC_SRCTAR} is invalid"
	cd "${KLIBC_DIR}"
	if [ -f ${GK_SHARE}/pkg/klibc-1.1.16-sparc2.patch ]
	then
		patch -p1 -i \
			${GK_SHARE}/pkg/klibc-1.1.16-sparc2.patch \
			|| gen_die "Failed patching klibc"
	fi
	if [ -f "${GK_SHARE}/pkg/klibc-1.2.1-nostdinc-flags.patch" ]
	then
		patch -p1 -i \
			${GK_SHARE}/pkg/klibc-1.2.1-nostdinc-flags.patch \
			|| gen_die "Failed patching klibc"
	fi

	# Don't install to "//lib" fix
	sed -e 's:SHLIBDIR = /lib:SHLIBDIR = $(INSTALLROOT)$(INSTALLDIR)/$(KLIBCCROSS)lib:' -i scripts/Kbuild.install
	print_info 1 'klibc: >> Compiling...'
	ln -snf "${KERNEL_DIR}" linux || gen_die "Could not link to ${KERNEL_DIR}"
	sed -i Makefile -e "s|prefix      = /usr|prefix      = ${TEMP}/klibc-build|g"
	if [ "${UTILS_ARCH}" != '' ]
	then
		sed -i Makefile -e "s|export ARCH.*|export ARCH := ${UTILS_ARCH}|g"
	fi
	if [ "${ARCH}" = 'um' ]
	then
		compile_generic "ARCH=um" utils
	elif [ "${ARCH}" = 'x86' ]
	then
		compile_generic "ARCH=i386" utils
	elif [ "${UTILS_CROSS_COMPILE}" != '' ]
	then
		compile_generic "CROSS=${UTILS_CROSS_COMPILE}" utils
	else
		compile_generic "" utils
	fi

	compile_generic "install" utils
        
}
compile_udev() {
	if [ ! -f "${UDEV_BINCACHE}" ]
	then
		# PPC fixup for 2.6.14
		# Headers are moving around .. need to make them available
		if [ "${VER}" -eq '2' -a "${PAT}" -eq '6' -a "${SUB}" -ge '14' ]
		then
		    if [ "${ARCH}" = 'ppc' -o "${ARCH}" = 'ppc64' ]
		    then
	    		cd ${KERNEL_DIR}
			echo 'Applying hack to workaround 2.6.14+ PPC header breakages...'
	    		compile_generic 'include/asm' kernel
		    fi
		fi
		compile_klibc
		cd "${TEMP}"
		rm -rf "${UDEV_DIR}" udev
		[ ! -f "${UDEV_SRCTAR}" ] &&
			gen_die "Could not find udev tarball: ${UDEV_SRCTAR}"
		/bin/tar -jxpf "${UDEV_SRCTAR}" ||
			gen_die 'Could not extract udev tarball'
		[ ! -d "${UDEV_DIR}" ] &&
			gen_die "Udev tarball ${UDEV_SRCTAR} is invalid"

		cd "${UDEV_DIR}"
    		local extras="extras/scsi_id extras/volume_id extras/ata_id extras/run_directory extras/usb_id extras/floppy extras/cdrom_id extras/firmware"
		# No selinux support yet .. someday maybe
		#use selinux && myconf="${myconf} USE_SELINUX=true"
		print_info 1 'udev: >> Compiling...'
		# SPARC fixup
		if [ "${UTILS_ARCH}" = 'sparc' ]
		then
			echo "CFLAGS += -mcpu=v8 -mtune=v8" >> Makefile
		fi
		# PPC fixup for 2.6.14
		if [ "${VER}" -eq '2' -a "${PAT}" -eq '6' -a "${SUB}" -ge '14' ]
        	then
			if [ "${ARCH}" = 'ppc' -o "${ARCH}" = 'ppc64' ]
        		then
				# Headers are moving around .. need to make them available
				echo "CFLAGS += -I${KERNEL_DIR}/arch/${ARCH}/include" >> Makefile
			fi
		fi

		if [ "${ARCH}" = 'um' ]
		then
			compile_generic "EXTRAS=\"${extras}\" ARCH=um USE_KLIBC=true KLCC=${TEMP}/klibc-build/bin/klcc USE_LOG=false DEBUG=false udevdir=/dev all" utils
		else
			# This *needs* to be runtask, or else it breakson most
			# architectures.  -- wolf31o2
			compile_generic "EXTRAS=\"${extras}\" USE_KLIBC=true KLCC=${TEMP}/klibc-build/bin/klcc USE_LOG=false DEBUG=false udevdir=/dev all" runtask
		fi


		print_info 1 '      >> Installing...'
		install -d "${TEMP}/udev/etc/udev" "${TEMP}/udev/sbin" "${TEMP}/udev/etc/udev/scripts" "${TEMP}/udev/etc/udev/rules.d" "${TEMP}/udev/etc/udev/permissions.d" "${TEMP}/udev/etc/udev/extras" "${TEMP}/udev/etc" "${TEMP}/udev/sbin" "${TEMP}/udev/usr/" "${TEMP}/udev/usr/bin" "${TEMP}/udev/usr/sbin"||
			gen_die 'Could not create directory hierarchy'
		
		install -c etc/udev/gentoo/udev.rules "${TEMP}/udev/etc/udev/rules.d/50-udev.rules" ||
		    gen_die 'Could not copy gentoo udev.rules to 50-udev.rules'

#		compile_generic "EXTRAS=\"${extras}\" DESTDIR=${TEMP}/udev install-config" utils
#		compile_generic "EXTRAS=\"${extras}\" DESTDIR=${TEMP}/udev install-bin" utils
		# We are going to install our files by hand.  Why are we doing this?
		# Well, the udev ebuild does so, and I tend to think that Greg
		# Kroah-Hartman knows what he's doing with regards to udev.
		for i in udev udevd udevsend udevstart udevtrigger
		do
			install -D $i "${TEMP}/udev/sbin"
		done
		install -c extras/ide-devfs.sh "${TEMP}/udev/etc/udev/scripts" 
		install -c extras/scsi-devfs.sh "${TEMP}/udev/etc/udev/scripts" 
		install -c extras/raid-devfs.sh "${TEMP}/udev/etc/udev/scripts" 

		cd "${TEMP}/udev"
		print_info 1 '      >> Copying to bincache...'
		/bin/tar -cjf "${UDEV_BINCACHE}" * ||
			gen_die 'Could not create binary cache'

		cd "${TEMP}"
		rm -rf "${UDEV_DIR}" udev
		
		# PPC fixup for 2.6.14
		if [ "${VER}" -eq '2' -a "${PAT}" -eq '6' -a "${SUB}" -ge '14' ]
		then
		    if [ "${ARCH}" = 'ppc' -o "${ARCH}" = 'ppc64' ]
		    then
			cd ${KERNEL_DIR}
			compile_generic 'archclean' kernel
			cd "${TEMP}"
		    fi
		fi
	fi
}

compile_e2fsprogs() {
	if [ ! -f "${BLKID_BINCACHE}" ]
	then
		[ ! -f "${E2FSPROGS_SRCTAR}" ] &&
			gen_die "Could not find e2fsprogs source tarball: ${E2FSPROGS_SRCTAR}. Please place it there, or place another version, changing /etc/genkernel.conf as necessary!"
		cd "${TEMP}"
		rm -rf "${E2FSPROGS_DIR}"
		tar -zxpf "${E2FSPROGS_SRCTAR}"
		[ ! -d "${E2FSPROGS_DIR}" ] &&
			gen_die "e2fsprogs directory ${E2FSPROGS_DIR} invalid"
		cd "${E2FSPROGS_DIR}"
		print_info 1 'e2fsprogs: >> Configuring...'
		./configure  --with-ldopts=-static >> ${DEBUGFILE} 2>&1 ||
			gen_die 'Configuring e2fsprogs failed!'
		print_info 1 'e2fsprogs: >> Compiling...'
		MAKE=${UTILS_MAKE} compile_generic "" ""
		print_info 1 'blkid: >> Copying to cache...'
		[ -f "${TEMP}/${E2FSPROGS_DIR}/misc/blkid" ] ||
			gen_die 'Blkid executable does not exist!'
		strip "${TEMP}/${E2FSPROGS_DIR}/misc/blkid" ||
			gen_die 'Could not strip blkid binary!'
		bzip2 "${TEMP}/${E2FSPROGS_DIR}/misc/blkid" ||
			gen_die 'bzip2 compression of blkid failed!'
		mv "${TEMP}/${E2FSPROGS_DIR}/misc/blkid.bz2" "${BLKID_BINCACHE}" ||
			gen_die 'Could not copy the blkid binary to the package directory, does the directory exist?'

		cd "${TEMP}"
		rm -rf "${E2FSPROGS_DIR}" > /dev/null
	fi
}
