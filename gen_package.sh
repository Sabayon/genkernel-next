#!/bin/bash

gen_minkernpackage()
{
	print_info 1 'Creating minimal kernel package'
	rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
	mkdir "${TEMP}/minkernpackage" || gen_die 'Could not make a directory for the kernel package!'
	cd "${KERNEL_DIR}"
	cp "${KERNEL_BINARY}" "${TEMP}/minkernpackage/kernel-${KV}" || gen_die 'Could not the copy kernel for the kernel package!'
	[ "${BUILD_INITRD}" -ne 0 ] && { cp "${TEMP}/initrd-${KV}" "${TEMP}/minkernpackage/initrd-${KV}" || gen_die 'Could not copy the initrd for the kernel package!'; }
	cd "${TEMP}/minkernpackage" 
	tar -jcpf ${MINKERNPACKAGE} * || gen_die 'Could not compress the kernel package!'
	cd "${TEMP}" && rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
}

gen_maxkernpackage()
{
	print_info 1 'Creating maximum kernel package'
	rm -rf "${TEMP}/maxkernpackage" > /dev/null 2>&1
	mkdir "${TEMP}/maxkernpackage" || gen_die 'Could not make a directory for the kernel package!'
	cd "${KERNEL_DIR}"
	cp "${KERNEL_BINARY}" "${TEMP}/maxkernpackage/kernel-${KV}" || gen_die 'Could not the copy kernel for the kernel package!'
	[ "${BUILD_INITRD}" -ne 0 ] && { cp "${TEMP}/initrd-${KV}" "${TEMP}/maxkernpackage/initrd-${KV}" || gen_die 'Could not copy the initrd for the kernel package!'; }
	cp "${KERNEL_DIR}/.config" "${TEMP}/maxkernpackage/kernel-config-${ARCH}-${KV}"
	mkdir -p "${TEMP}/maxkernpackage/lib/modules/"
	cp -r "/lib/modules/${KV}" "${TEMP}/maxkernpackage/lib/modules/"
	cd "${TEMP}/maxkernpackage" 
	tar -jcpf ${MAXKERNPACKAGE} * || gen_die 'Could not compress the kernel package!'
	cd "${TEMP}" && rm -rf "${TEMP}/maxkernpackage" > /dev/null 2>&1
}
