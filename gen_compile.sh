#!/bin/bash

compile_kernel_args()
{
	local ARGS

	ARGS=""
	if [ "${KERNEL_CC}" != "" ]
	then
		ARGS="CC=\"${KERNEL_CC}\""
	fi
	if [ "${KERNEL_LD}" != "" ]
	then
		ARGS="${ARGS} LD=\"${KERNEL_LD}\""
	fi

	if [ "${KERNEL_AS}" != "" ]
	then
		ARGS="${ARGS} AS=\"${KERNEL_AS}\""
	fi

	echo -n "${ARGS}"
}

compile_utils_args()
{
	local ARGS

	ARGS=""
	if [ "${UTILS_CC}" != "" ]
	then
		ARGS="CC=\"${UTILS_CC}\""
	fi
	if [ "${UTILS_LD}" != "" ]
	then
		ARGS="${ARGS} LD=\"${UTILS_LD}\""
	fi

	if [ "${UTILS_AS}" != "" ]
	then
		ARGS="${ARGS} AS=\"${UTILS_AS}\""
	fi

	echo -n "${ARGS}"
}

export_utils_args()
{
	if [ "${UTILS_CC}" != "" ]
	then
		export CC="${UTILS_CC}"
	fi
	if [ "${UTILS_LD}" != "" ]
	then
		export LD="${UTILS_LD}"
	fi
	if [ "${UTILS_AS}" != "" ]
	then
		export AS="${UTILS_AS}"
	fi
}

unset_utils_args()
{
	if [ "${UTILS_CC}" != "" ]
	then
		unset CC
	fi
	if [ "${UTILS_LD}" != "" ]
	then
		unset LD
	fi
	if [ "${UTILS_AS}" != "" ]
	then
		unset AS
	fi
}

export_kernel_args()
{
	if [ "${KERNEL_CC}" != "" ]
	then
		export CC="${KERNEL_CC}"
	fi
	if [ "${KERNEL_LD}" != "" ]
	then
		export LD="${KERNEL_LD}"
	fi
	if [ "${KERNEL_AS}" != "" ]
	then
		export AS="${KERNEL_AS}"
	fi
}

unset_kernel_args()
{
	if [ "${KERNEL_CC}" != "" ]
	then
		unset CC
	fi
	if [ "${KERNEL_LD}" != "" ]
	then
		unset LD
	fi
	if [ "${KERNEL_AS}" != "" ]
	then
		unset AS
	fi
}

compile_generic() {
	local RET
	if [ "$#" -lt "2" ]
	then
		gen_die "compile_generic(): improper usage"
	fi

	if [ "${2}" = "kernel" ]
	then
		export_kernel_args
		MAKE=${KERNEL_MAKE}
	elif [ "${2}" = "utils" ]
	then
		export_utils_args
		MAKE=${UTILS_MAKE}
	fi

	if [ "${DEBUGLEVEL}" -gt "1" ]
	then
		# Output to stdout and debugfile
		print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} ${1}" 1 0 1
		${MAKE} ${MAKEOPTS} ${1} 2>&1 | tee -a ${DEBUGFILE}
		RET=$?
	else
		# Output to debugfile only
		print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} ${1}" 1 0 1
		${MAKE} ${MAKEOPTS} ${1} >> ${DEBUGFILE} 2>&1
		RET=$?
	fi
	[ "${RET}" -ne "0" ] && gen_die "compile of failed"

	unset MAKE
	if [ "${2}" = "kernel" ]
	then
		unset_kernel_args
	elif [ "${2}" = "utils" ]
	then
		unset_utils_args
	fi

}

extract_dietlibc_bincache() {
	print_info 1 "extracting dietlibc bincache"
	CURR_DIR=`pwd`
	cd "${TEMP}"
	rm -rf "${TEMP}/diet" > /dev/null
	tar -jxpf "${DIETLIBC_BINCACHE}" || gen_die "Could not extract dietlibc bincache"
	[ ! -d "${TEMP}/diet" ] && gen_die "${TEMP}/diet directory not found"
	cd "${CURR_DIR}"
}

clean_dietlibc_bincache() {
	print_info 1 "cleaning up dietlibc bincache"
	CURR_DIR=`pwd`
	cd "${TEMP}"
	rm -rf "${TEMP}/diet" > /dev/null
	cd "${CURR_DIR}"
}


compile_dep() {
	# Only make dep for 2.4 kernels
	if [ "${PAT}" -gt "4" ]
	then
		print_info 1 "kernel: skipping make dep for non 2.4 kernels"
	else
		print_info 1 "kernel: Making dependencies for linux ${KV}"
		cd ${KERNEL_DIR}
		compile_generic "dep" kernel
	fi
}

compile_modules() {
	print_info 1 "kernel: Starting compile of linux ${KV} modules"
	cd ${KERNEL_DIR}
	compile_generic "modules" kernel
	compile_generic "modules_install" kernel
}

compile_kernel() {
	[ "${KERNEL_MAKE}" = "" ] && gen_die "KERNEL_MAKE undefined. Don't know how to compile kernel for arch."
	cd ${KERNEL_DIR}
	print_info 1 "kernel: Starting compile of linux ${KV} ${KERNEL_MAKE_DIRECTIVE}"
	compile_generic "${KERNEL_MAKE_DIRECTIVE}" kernel
	if [ "${KERNEL_MAKE_DIRECTIVE_2}" != "" ]
	then
		print_info 1 "kernel: Starting suppliment compile of linux ${KV} ${KERNEL_MAKE_DIRECTIVE_2}"
		compile_generic "${KERNEL_MAKE_DIRECTIVE_2}" kernel
	fi
	cp "${KERNEL_BINARY}" "/boot/kernel-${KV}" || gen_die "Could not copy kernel binary to boot"
}

compile_busybox() {
	if [ ! -f "${BUSYBOX_BINCACHE}" ]
	then
		[ ! -f "${BUSYBOX_SRCTAR}" ] && gen_die "Could not find busybox source tarball: ${BUSYBOX_SRCTAR}"
		[ ! -f "${BUSYBOX_CONFIG}" ] && gen_die "Cound not find busybox config file: ${BUSYBOX_CONFIG}"
		cd "${TEMP}"
		rm -rf ${BUSYBOX_DIR} > /dev/null
		tar -jxpf ${BUSYBOX_SRCTAR} || gen_die "Could not extract busybox source tarball"
		[ ! -d "${BUSYBOX_DIR}" ] && gen_die "Busybox directory ${BUSYBOX_DIR} invalid"
		cp "${BUSYBOX_CONFIG}" "${BUSYBOX_DIR}/.config"
		cd "${BUSYBOX_DIR}"
# Busybox and dietlibc don't play nice right now
#		if [ "${USE_DIETLIBC}" -eq "1" ]
#		then
#			extract_dietlibc_bincache
#			OLD_CC="${UTILS_CC}"
#			UTILS_CC="${TEMP}/diet/bin/diet ${UTILS_CC}"
#		fi
		print_info 1 "Busybox: make oldconfig"
		yes "" | compile_generic "oldconfig" utils
		print_info 1 "Busybox: make all"
		compile_generic "all" utils
# Busybox and dietlibc don't play nice right now
# 		if [ "${USE_DIETLIBC}" -eq "1" ]
#		then
#			clean_dietlibc_bincache
#			UTILS_CC="${OLD_CC}"
#		fi
		print_info 1 "Busybox: copying to bincache"
		[ ! -f "${TEMP}/${BUSYBOX_DIR}/busybox" ] && gen_die "busybox executable does not exist after compile, error"
		strip "${TEMP}/${BUSYBOX_DIR}/busybox" || gen_die "could not strip busybox"
		bzip2 "${TEMP}/${BUSYBOX_DIR}/busybox" || gen_die "bzip2 compression of busybox failed"
		[ ! -f "${TEMP}/${BUSYBOX_DIR}/busybox.bz2" ] && gen_die "could not find compressed busybox binary"
		mv "${TEMP}/${BUSYBOX_DIR}/busybox.bz2" "${BUSYBOX_BINCACHE}" || gen_die "could not copy busybox binary to arch package directory, does the directory exist?"

		print_info 1 "Busybox: cleaning up"
		cd "${TEMP}"
		rm -rf "${BUSYBOX_DIR}" > /dev/null
	else
		print_info 1 "Busybox: Found bincache at ${BUSYBOX_BINCACHE}"
	fi
}

compile_modutils() {
	local ARGS
	if [ ! -f "${MODUTILS_BINCACHE}" ]
	then
		[ ! -f "${MODUTILS_SRCTAR}" ] && gen_die "Could not find modutils source tarball: ${MODUTILS_SRCTAR}"
		cd "${TEMP}"
		rm -rf "${MODUTILS_DIR}"
		tar -jxpf "${MODUTILS_SRCTAR}"
		[ ! -d "${MODUTILS_DIR}" ] && gen_die "Modutils directory ${MODUTILS_DIR} invalid"
		cd "${MODUTILS_DIR}"
		print_info 1 "modutils: configure"

		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			extract_dietlibc_bincache
			OLD_CC="${UTILS_CC}"
			UTILS_CC="${TEMP}/diet/bin/diet ${UTILS_CC}"
		fi

		export_utils_args
		./configure --disable-combined --enable-insmod-static >> ${DEBUGFILE} 2>&1 || gen_die "Configure of modutils failed"
		unset_utils_args

		print_info 1 "modutils: make all"
		compile_generic "all" utils

 		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			clean_dietlibc_bincache
			UTILS_CC="${OLD_CC}"
		fi

		print_info 1 "modutils: copying to bincache"
		[ ! -f "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" ] && gen_die "insmod.static does not exist after compilation of modutils"
		strip "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" || gen_die "could not strip insmod.static"
		bzip2 "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static" || gen_die "compression of insmod.static failed"
		[ ! -f "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static.bz2" ] && gen_die "could not find compressed insmod.static.bz2 binary"
		mv "${TEMP}/${MODUTILS_DIR}/insmod/insmod.static.bz2" "${MODUTILS_BINCACHE}" || gen_die "could not move compress binary to bincache"

		print_info 1 "modutils: cleaning up"
		cd "${TEMP}"
		rm -rf "${MODULE_INIT_TOOLS_DIR}" > /dev/null
	else
		print_info 1 "modutils: Found bincache at ${MODUTILS_BINCACHE}"
	fi
}

compile_module_init_tools() {
	local ARGS
	if [ ! -f "${MODULE_INIT_TOOLS_BINCACHE}" ]
	then
		[ ! -f "${MODULE_INIT_TOOLS_SRCTAR}" ] && gen_die "Could not find module-init-tools source tarball: ${MODULE_INIT_TOOLS_SRCTAR}"
		cd "${TEMP}"
		rm -rf "${MODULE_INIT_TOOLS_DIR}"
		tar -jxpf "${MODULE_INIT_TOOLS_SRCTAR}"
		[ ! -d "${MODULE_INIT_TOOLS_DIR}" ] && gen_die "Module-init-tools directory ${MODULE_INIT_TOOLS_DIR} invalid"
		cd "${MODULE_INIT_TOOLS_DIR}"
		print_info 1 "module-init-tools: configure"

		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			extract_dietlibc_bincache
			OLD_CC="${UTILS_CC}"
			UTILS_CC="${TEMP}/diet/bin/diet ${UTILS_CC}"
		fi

		export_utils_args
		./configure >> ${DEBUGFILE} 2>&1 || gen_die "Configure of module-init-tools failed"
		unset_utils_args
		print_info 1 "module-init-tools: make all"
		compile_generic "all" utils

 		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			clean_dietlibc_bincache
			UTILS_CC="${OLD_CC}"
		fi

		print_info 1 "module-init-tools: copying to bincache"
		[ ! -f "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" ] && gen_die "insmod.static does not exist after compilation of module-init-tools"
		strip "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" || gen_die "could not strip insmod.static"
		bzip2 "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static" || gen_die "compression of insmod.static failed"
		[ ! -f "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static.bz2" ] && gen_die "could not find compressed insmod.static.bz2 binary"
		mv "${TEMP}/${MODULE_INIT_TOOLS_DIR}/insmod.static.bz2" "${MODULE_INIT_TOOLS_BINCACHE}" || gen_die "could not move compressed binary to bincache"

		print_info 1 "module-init-tools: cleaning up"
		cd "${TEMP}"
		rm -rf "${MODULE_INIT_TOOLS_DIR}" > /dev/null
	else
		print_info 1 "module-init-tools: Found bincache at ${MODULE_INIT_TOOLS_BINCACHE}"
	fi
}

compile_devfsd() {
	local ARGS
	if [ ! -f "${DEVFSD_BINCACHE}" -o ! -f "${DEVFSD_CONF_BINCACHE}" ]
	then
		[ ! -f "${DEVFSD_SRCTAR}" ] && gen_die "Could not find devfsd source tarball: ${DEVFSD_SRCTAR}"
		cd "${TEMP}"
		rm -rf "${DEVFSD_DIR}"
		tar -jxpf "${DEVFSD_SRCTAR}"
		[ ! -d "${DEVFSD_DIR}" ] && gen_die "Devfsd directory ${DEVFSD_DIR} invalid"
		cd "${DEVFSD_DIR}"

		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			extract_dietlibc_bincache
			OLD_CC="${UTILS_CC}"
			UTILS_CC="${TEMP}/diet/bin/diet ${UTILS_CC}"
		fi

		print_info 1 "devfsd: make all"

		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			compile_generic "has_dlopen=0 has_rpcsvc=0" utils
		else
			compile_generic "LDFLAGS=-static" utils
		fi

 		if [ "${USE_DIETLIBC}" -eq "1" ]
		then
			clean_dietlibc_bincache
			UTILS_CC="${OLD_CC}"
		fi

		print_info 1 "devfsd: copying to bincache"
		[ ! -f "${TEMP}/${DEVFSD_DIR}/devfsd" ] && gen_die "devfsd executable does not exist after compilation of devfsd"
		strip "${TEMP}/${DEVFSD_DIR}/devfsd" || gen_die "could not strip devfsd"
		bzip2 "${TEMP}/${DEVFSD_DIR}/devfsd" || gen_die "compression of devfsd failed"
		[ ! -f "${TEMP}/${DEVFSD_DIR}/devfsd.bz2" ] && gen_die "could not find compressed devfsd.bz2 binary"
		mv "${TEMP}/${DEVFSD_DIR}/devfsd.bz2" "${DEVFSD_BINCACHE}" || gen_die "could not move compressed binary to bincache"

		[ ! -f "${TEMP}/${DEVFSD_DIR}/devfsd.conf" ] && gen_die "devfsd.conf does not exist after compilation of devfsd"
		bzip2 "${TEMP}/${DEVFSD_DIR}/devfsd.conf" || gen_die "compression of devfsd.conf failed"
		[ ! -f "${TEMP}/${DEVFSD_DIR}/devfsd.conf.bz2" ] && gen_die "could not find compressed devfsd.conf.bz2 binary"
		mv "${TEMP}/${DEVFSD_DIR}/devfsd.conf.bz2" "${DEVFSD_CONF_BINCACHE}" || gen_die "could not move compressed binary to bincache"

		print_info 1 "devfsd: cleaning up"
		cd "${TEMP}"
		rm -rf "${DEVFSD_DIR}" > /dev/null
	else
		print_info 1 "devfsd: Found bincache at ${DEVFSD_BINCACHE} and ${DEVFSD_CONF_BINCACHE}"
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
		cd "${TEMP}"
		rm -rf "${DIETLIBC_DIR}" > /dev/null
		tar -jxpf ${DIETLIBC_SRCTAR} || gen_die "Could not extract dietlibc source tarball"
		[ ! -d "${DIETLIBC_DIR}" ] && gen_die "Dietlibc directory ${DIETLIBC_DIR} invalid"
		cd "${DIETLIBC_DIR}"
		print_info 1 "Dietlibc: make"
		compile_generic "prefix=${TEMP}/diet" utils
		print_info 1 "Dietlibc: installing"
		compile_generic "prefix=${TEMP}/diet install" utils
		print_info 1 "Dietlibc: copying to bincache"
		cd ${TEMP}
		tar -jcpf "${DIETLIBC_BINCACHE}" diet || gen_die "Could not tar up dietlibc bin"
		[ ! -f "${DIETLIBC_BINCACHE}" ] && gen_die "bincache not created"
		echo "${TEMP}" > "${DIETLIBC_BINCACHE_TEMP}"

		print_info 1 "Dietlibc: cleaning up"
		cd "${TEMP}"
		rm -rf "${DIETLIBC_DIR}" > /dev/null
		rm -rf "${TEMP}/diet" > /dev/null
	else
		print_info 1 "Dietlibc: Found bincache at ${DIETLIBC_BINCACHE}"
	fi
}

