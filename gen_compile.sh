#!/bin/bash

compile_args()
{
	local ARGS

	ARGS=""
	if [ "${CC}" != "" ]
	then
		ARGS="CC=\"${CC}\""
	fi
	if [ "${LD}" != "" ]
	then
		ARGS="${ARGS} LD=\"${LD}\""
	fi

	if [ "${AS}" != "" ]
	then
		ARGS="${ARGS} AS=\"${AS}\""
	fi
	
	echo -n "${ARGS}"
}

compile_generic() {
	local RET
	if [ "$#" -lt "1" ]
	then
		gen_die "compile_generic(): improper usage"
	fi

	ARGS=`compile_args`

	if [ "${DEBUGLEVEL}" -gt "1" ]
	then
		# Output to stdout and debugfile
		print_info 2 "COMMAND: ${MAKE} ${ARGS} ${MAKEOPTS} ${1}" 1 0
		${MAKE} ${ARGS} ${MAKEOPTS} ${1} 2>&1 | tee -a ${DEBUGFILE}
		RET=$?
	else
		# Output to debugfile only
		print_info 2 "COMMAND: ${MAKE} ${ARGS} ${MAKEOPTS} ${1}" 1 0
		${MAKE} ${ARGS} ${MAKEOPTS} ${1} >> ${DEBUGFILE} 2>&1
		RET=$?
	fi
	[ "${RET}" -ne "0" ] && gen_die "compile of failed"
}

compile_dep() {
	# Only make dep for 2.4 kernels
	if [ "${PAT}" -gt "4" ]
	then
		print_info 1 "kernel: skipping make dep for non 2.4 kernels"
	else
		print_info 1 "kernel: Making dependancies for linux ${KV}"
		cd ${KERNEL_DIR}
		compile_generic "dep"
	fi
}

compile_modules() {
	print_info 1 "kernel: Starting compile of linux ${KV} modules"
	cd ${KERNEL_DIR}
	compile_generic "modules"
	compile_generic "modules_install"
}

compile_kernel() {
	[ "${KERNEL_MAKE}" = "" ] && gen_die "KERNEL_MAKE undefined. Don't know how to compile kernel for arch."
	cd ${KERNEL_DIR}
	print_info 1 "kernel: Starting compile of linux ${KV} ${KERNEL_MAKE}"
	compile_generic "${KERNEL_MAKE}"
	cp "${KERNEL_BINARY}" "/boot/kernel-${KV}" || gen_die "Could not copy kernel binary to boot"
}

compile_busybox() {
	if [ ! -f "${BUSYBOX_BINCACHE}" ]
	then
		[ ! -f "${BUSYBOX_SRCTAR}" ] && gen_die "Could not find busybox source tarball: ${BUSYBOX_SRCTAR}"
		[ ! -f "${BUSYBOX_CONFIG}" ] && gen_die "Cound not find busybox config file: ${BUSYBOX_CONFIG}"
		cd ${TEMP}
		rm -rf ${BUSYBOX_DIR} > /dev/null
		tar -jxpf ${BUSYBOX_SRCTAR} || gen_die "Could not extract busybox source tarball"
		[ ! -d "${BUSYBOX_DIR}" ] && gen_die "Busybox directory ${BUSYBOX_DIR} invalid"
		cp "${BUSYBOX_CONFIG}" "${BUSYBOX_DIR}/.config"
		cd "${BUSYBOX_DIR}"
		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			OLD_CC="${CC}"
			CC="${TEMP}/diet/bin/diet ${CC}"
		fi
		print_info 1 "Busybox: make oldconfig"
		compile_generic "oldconfig"
		print_info 1 "Busybox: make all"
		compile_generic "all"
		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			CC="${OLD_CC}"
		fi
		print_info 1 "Busybox: copying to bincache"
		[ ! -f "${TEMP}/${BUSYBOX_DIR}/busybox" ] && gen_die "busybox executable does not exist after compile, error"
		strip "${TEMP}/${BUSYBOX_DIR}/busybox" || gen_die "could not strip busybox"
		bzip2 "${TEMP}/${BUSYBOX_DIR}/busybox" || gen_die "bzip2 compression of busybox failed"
		[ ! -f "${TEMP}/${BUSYBOX_DIR}/busybox.bz2" ] && gen_die "could not find compressed busybox binary"
		mv "${TEMP}/${BUSYBOX_DIR}/busybox.bz2" "${BUSYBOX_BINCACHE}" || gen_die "could not copy busybox binary to arch package directory, does the directory exist?"
	else
		print_info 1 "Busybox: Found bincache at ${BUSYBOX_BINCACHE}"
	fi
}

compile_modutils() {
	if [ ! -f "${MODUTILS_BINCACHE}" ]
	then
		[ ! -f "${MODUTILS_SRCTAR}" ] && gen_die "Could not find modutils source tarball: ${MODUTILS_BINCACHE}"
		cd ${TEMP}
		rm -rf "${MODUTILS_DIR}"
		tar -jxpf "${MODUTILS_SRCTAR}"
		[ ! -d "${MODUTILS_DIR}" ] && gen_die "Modutils directory ${MODUTILS_DIR} invalid"
		cd "${MODUTILS_DIR}"
		print_info 1 "modutils: configure"
		${ARGS} ./configure --disable-combined --enable-insmod-static >> ${DEBUGFILE} 2>&1 || gen_die "Configure of modutils failed"
		print_info 1 "modutils: make all"
		compile_generic "all"
		print_info 1 "modutils: copying to bincache"
		[ ! -f "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" ] && gen_die "insmod.static does not exist after compilation of modutils"
		strip "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" || gen_die "could not strip insmod.static"
		bzip2 "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" || gen_die "compression of insmod.static failed"
		[ ! -f "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static.bz2" ] && gen_die "could not find compressed insmod.static.bz2 binary"
		mv "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static.bz2" "${MODUTILS_BINCACHE}"
	else
		print_info 1 "modutils: Found bincache at ${MODUTILS_BINCACHE}"
	fi
}

compile_module_init_tools() {
	if [ ! -f "${MODULE_INIT_TOOLS_BINCACHE}" ]
	then
		[ ! -f "${MODULE_INIT_TOOLS_SRCTAR}" ] && gen_die "Could not find module-init-tools source tarball: ${MODULE_INIT_TOOLS_BINCACHE}"
		cd ${TEMP}
		rm -rf "${MODULE_INIT_TOOLS_DIR}"
		tar -jxpf "${MODULE_INIT_TOOLS_SRCTAR}"
		[ ! -d "${MODULE_INIT_TOOLS_DIR}" ] && gen_die "Module-init-tools directory ${MODULE_INIT_TOOLS_DIR} invalid"
		cd "${MODULE_INIT_TOOLS_DIR}"
		print_info 1 "module-init-tools: configure"
		${ARGS} ./configure >> ${DEBUGFILE} 2>&1 || gen_die "Configure of module-init-tools failed"
		print_info 1 "module-init-tools: make all"
		compile_generic "all"
		print_info 1 "module-init-tools: copying to bincache"
		[ ! -f "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" ] && gen_die "insmod.static does not exist after compilation of module-init-tools"
		strip "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" || gen_die "could not strip insmod.static"
		bzip2 "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" || gen_die "compression of insmod.static failed"
		[ ! -f "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static.bz2" ] && gen_die "could not find compressed insmod.static.bz2 binary"
		mv "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static.bz2" "${MODULE_INIT_TOOLS_BINCACHE}"
	else
		print_info 1 "module-init-tools: Found bincache at ${MODULE_INIT_TOOLS_BINCACHE}"
	fi
}

compile_dietlibc() {
	local BUILD_DIETLIBC
	local ORIGTEMP

	BUILD_DIETLIBC=0
	[ ! -f "${DIETLIBC_BINCACHE}" ] && BUILD_DIETLIBC=1
	[ ! -f "${DIETLIBC_BINCACHE_TEMP}" ] && BUILD_DIETLIBC=1
	if [ "${BUILD_DIETLIBC}" -eq "0" ]
	then
		ORIGTEMP=`cat "${DIETLIBC_BINCACHE_TEMP}"`
		if [ "${TEMP}" != "${ORIGTEMP}" ]
		then
			print_info 1 "Dietlibc: Bincache exists, but current temp directory is different than original. Rebuilding."
			BUILD_DIETLIBC=1
		fi
	fi

	if [ "${BUILD_DIETLIBC}" -eq "1" ]
	then
		[ ! -f "${DIETLIBC_SRCTAR}" ] && gen_die "Could not find dietlibc source tarball: ${DIETLIBC_SRCTAR}"
		cd ${TEMP}
		rm -rf ${DIETLIBC_DIR} > /dev/null
		tar -jxpf ${DIETLIBC_SRCTAR} || gen_die "Could not extract dietlibc source tarball"
		[ ! -d "${DIETLIBC_DIR}" ] && gen_die "Dietlibc directory ${DIETLIBC_DIR} invalid"
		cd "${DIETLIBC_DIR}"
		print_info 1 "Dietlibc: make"
		compile_generic "prefix=${TEMP}/diet"
		print_info 1 "Dietlibc: installing"
		compile_generic "prefix=${TEMP}/diet install"
		print_info 1 "Dietlibc: copying to bincache"
		cd ${TEMP}
		tar -jcpf "${DIETLIBC_BINCACHE}" diet || gen_die "Could not tar up dietlibc bin"
		[ ! -f "${DIETLIBC_BINCACHE}" ] && gen_die "bincache not created"
		echo "${TEMP}" > "${DIETLIBC_BINCACHE_TEMP}"
	else
		print_info 1 "Dietlibc: Found bincache at ${DIETLIBC_BINCACHE}"
	fi
}

