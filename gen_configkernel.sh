#!/bin/bash

determine_config_file() {
	if [ "${CMD_KERNEL_CONFIG}" != "" ]
	then
		KERNEL_CONFIG="${CMD_KERNEL_CONFIG}"
	elif [ "${DEFAULT_KERNEL_CONFIG}" != "" -a -f "${DEFAULT_KERNEL_CONFIG}" ]
	then
		KERNEL_CONFIG="${DEFAULT_KERNEL_CONFIG}"
	elif [ -f "${GK_SHARE}/${ARCH}/kernel-config-${VER}.${PAT}" ]
	then
		KERNEL_CONFIG="${GK_SHARE}/${ARCH}/kernel-config-${VER}.${PAT}"
	elif [ -f "${GK_SHARE}/${ARCH}/kernel-config" ]
	then
		KERNEL_CONFIG="${GK_SHARE}/${ARCH}/kernel-config"
	else
		gen_die "no kernel config specified, or file not found"
	fi
}

config_kernel() {
	print_info 1 "kernel: configuring source"

	determine_config_file

	cd "${KERNEL_DIR}" || gen_die "could not switch to kernel directory"

	if isTrue ${MRPROPER}
	then
		print_info 1 "kernel: running mrproper"
		compile_generic "mrproper"
	fi

	# If we're not cleaning, then we don't want to try to overwrite the configs there
	# or we might screw up something someone is trying to test.
	if isTrue ${CLEAN}
	then
		print_info 1 "kernel: using config from ${KERNEL_CONFIG}"
		cp "${KERNEL_CONFIG}" "${KERNEL_DIR}/.config" || gen_die "could not copy config file"

		print_info 1 "kernel: running oldconfig"
		yes "" | compile_generic "oldconfig"

		if isTrue ${MENUCONFIG}
		then
			print_info 1 "kernel: running menuconfig"
			make menuconfig
		fi

		print_info 1 "kernel: running clean"
		compile_generic "clean"
	else
		print_info 1 "kernel: skipping copy of config. CLEAN is OFF"
	fi

}
