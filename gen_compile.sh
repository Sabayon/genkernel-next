#!/bin/bash

compile_kernel_args()
{
	local ARGS

	ARGS=''
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

	echo -n "${ARGS}"
}

compile_utils_args()
{
	local ARGS

	ARGS=''
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
	tar -jxpf "${DIETLIBC_BINCACHE}" ||
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
	if [ "${VER}" -eq '2' -a "${PAT}" -le '4' ]
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
	if [ "${VER}" -eq '2' -a "${PAT}" -le '4' ]
	then
		MAKEOPTS_SAVE="${MAKEOPTS}"
		MAKEOPTS='-j1'
	fi
	[ "${INSTALL_MOD_PATH}" != '' ] && export INSTALL_MOD_PATH
	compile_generic "modules_install" kernel
	[ "${VER}" -eq '2' -a "${PAT}" -le '4' ] && MAKEOPTS="${MAKEOPTS_SAVE}"
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
		cp "${KERNEL_BINARY}" "/boot/kernel-${KV}" ||
			gen_die 'Could not copy the kernel binary to /boot!'
		cp "System.map" "/boot/System.map-${KV}" ||
			gen_die 'Could not copy System.map to /boot!'
	else
		cp "${KERNEL_BINARY}" "${TEMP}/kernel-${KV}" ||
			gen_die "Could not copy the kernel binary to ${TEMP}!"
		cp "System.map" "${TEMP}/System.map-${KV}" ||
			gen_die "Could not copy System.map to ${TEMP}!"
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
		tar -jxpf ${BUSYBOX_SRCTAR} ||
			gen_die 'Could not extract busybox source tarball!'
		[ -d "${BUSYBOX_DIR}" ] ||
			gen_die 'Busybox directory ${BUSYBOX_DIR} is invalid!'
		cp "${BUSYBOX_CONFIG}" "${BUSYBOX_DIR}/.config"
		cd "${BUSYBOX_DIR}"
# Busybox and dietlibc don't play nice right now
#		if [ "${USE_DIETLIBC}" -eq "1" ]
#		then
#			extract_dietlibc_bincache
#			OLD_CC="${UTILS_CC}"
#			UTILS_CC="${TEMP}/diet/bin/diet ${UTILS_CC}"
#		fi
		print_info 1 'busybox: >> Configuring...'
		yes '' | compile_generic oldconfig utils
		print_info 1 'busybox: >> Compiling...'
		compile_generic all utils
# Busybox and dietlibc don't play nice right now
# 		if [ "${USE_DIETLIBC}" -eq "1" ]
#		then
#			clean_dietlibc_bincache
#			UTILS_CC="${OLD_CC}"
#		fi
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
		tar -zxpf ${LVM2_SRCTAR} ||
			gen_die 'Could not extract LVM2 source tarball!'
		[ -d "${LVM2_DIR}" ] ||
			gen_die 'LVM2 directory ${LVM2_DIR} is invalid!'
		rm -rf "${TEMP}/device-mapper" > /dev/null
		tar -jxpf "${DEVICE_MAPPER_BINCACHE}" -C "${TEMP}" ||
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
		tar -cjf "${LVM2_BINCACHE}" sbin/lvm.static ||
			gen_die 'Could not create binary cache'

		cd "${TEMP}"
		rm -rf "${TEMP}/device-mapper" > /dev/null
		rm -rf "${LVM2_DIR}" lvm2
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
		tar -jxpf "${MODUTILS_SRCTAR}"
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
		tar -jxpf "${MODULE_INIT_TOOLS_SRCTAR}"
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
		tar -jxpf "${DEVFSD_SRCTAR}"
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
		tar -zxpf "${DEVICE_MAPPER_SRCTAR}"
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
		tar -jcpf "${DEVICE_MAPPER_BINCACHE}" device-mapper ||
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
		tar -jxpf "${DIETLIBC_SRCTAR}" ||
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
		tar -jcpf "${DIETLIBC_BINCACHE}" diet ||
			gen_die 'Could not tar up the dietlibc binary!'
		[ -f "${DIETLIBC_BINCACHE}" ] ||
			gen_die 'Dietlibc cache not created!'
		echo "${TEMP}" > "${DIETLIBC_BINCACHE_TEMP}"

		cd "${TEMP}"
		rm -rf "${DIETLIBC_DIR}" > /dev/null
		rm -rf "${TEMP}/diet" > /dev/null
	fi
}

compile_udev() {
	if [ ! -f "${UDEV_BINCACHE}" ]
	then
		cd "${TEMP}"
		rm -rf "${UDEV_DIR}" udev
		[ ! -f "${UDEV_SRCTAR}" ] &&
			gen_die "Could not find udev tarball: ${UDEV_SRCTAR}"
		tar -jxpf "${UDEV_SRCTAR}" ||
			gen_die 'Could not extract udev tarball'
		[ ! -d "${UDEV_DIR}" ] &&
			gen_die "Udev tarball ${UDEV_SRCTAR} is invalid"

		cd "${UDEV_DIR}"
		print_info 1 'udev: >> Compiling...'
		ln -snf "${KERNEL_DIR}" klibc/linux ||
			gen_die "Could not link to ${KERNEL_DIR}"
		compile_generic "KERNEL_DIR=$KERNEL_DIR USE_KLIBC=true USE_LOG=false DEBUG=false udevdir=/dev all etc/udev/udev.conf" utils
		strip udev || gen_die 'Failed to strip the udev binary!'

		print_info 1 '      >> Installing...'
		install -d "${TEMP}/udev/etc/udev" "${TEMP}/udev/sbin" "${TEMP}/udev/etc/udev/scripts" "${TEMP}/udev/etc/udev/rules.d" "${TEMP}/udev/etc/udev/permissions.d" ||
			gen_die 'Could not create directory hierarchy'
		install -m 0755 udev "${TEMP}/udev/sbin" ||
			gen_die 'Could not install udev binary!'
		install -m 0644 etc/udev/udev.conf "${TEMP}/udev/etc/udev" ||
				gen_die 'Could not install udev configuration!'
		install -m 0644 etc/udev/udev.rules.gentoo "${TEMP}/udev/etc/udev/rules.d/50-udev.rules" ||
				gen_die 'Could not install udev rules!'
		install -m 0644 etc/udev/udev.permissions "${TEMP}/udev/etc/udev/permissions.d/50-udev.permissions" ||
				gen_die 'Could not install udev permissions!'
		install -m 0755 extras/ide-devfs.sh "${TEMP}/udev/etc/udev/scripts" ||
			gen_die 'Could not install udev scripts!'

		cd "${TEMP}/udev"
		print_info 1 '      >> Copying to bincache...'
		tar -cjf "${UDEV_BINCACHE}" * ||
			gen_die 'Could not create binary cache'

		cd "${TEMP}"
		rm -rf "${UDEV_DIR}" udev
	fi
}

