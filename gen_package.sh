#!/bin/bash

gen_minkernpackage()
{
	print_info 1 'Creating kernel package'
	rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
	mkdir "${TEMP}/minkernpackage" || gen_die 'Could not make a directory for the kernel package!'
	cd "${KERNEL_DIR}"
	cp "${KERNEL_BINARY}" "${TEMP}/minkernpackage/kernel-${KV}" || gen_die 'Could not the copy kernel for the kernel package!'
	[ "${BUILD_INITRD}" -ne 0 ] && { cp "${TEMP}/initrd-${KV}" "${TEMP}/minkernpackage/initrd-${KV}" || gen_die 'Could not copy the initrd for the kernel package!'; }
	cd "${TEMP}/minkernpackage" 
	tar -jcpf ${MINKERNPACKAGE} * || gen_die 'Could not compress the kernel package!'
	cd "${TEMP}" && rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
}
