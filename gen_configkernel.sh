#!/bin/bash

config_kernel() {
	print_info 1 "kernel: configuring source"
	if [ "${CMD_KERNEL_CONFIG}" != "" ]
	then
		KERNEL_CONFIG="${CMD_KERNEL_CONFIG}"
	elif [ "${DEFAULT_KERNEL_CONFIG}" != "" ]
	then
		KERNEL_CONFIG="${DEFAULT_KERNEL_CONFIG}"
	else
		gen_die "no kernel config specified"
	fi

	[ ! -f "${KERNEL_CONFIG}" ] && gen_die "kernel config not found at specified location"


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
