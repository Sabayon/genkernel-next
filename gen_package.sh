#!/bin/bash

gen_minkernpackage()
{
	print_info 1 "Creating minkernpackage"
	rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
	mkdir "${TEMP}/minkernpackage" || gen_die "Could not make directory for minkernpackage"
	cd "${KERNEL_DIR}"
	cp "${KERNEL_BINARY}" "${TEMP}/minkernpackage/kernel" || gen_die "Could not copy kernel for minkernpackage"
	cp "/boot/initrd-${KV}" "${TEMP}/minkernpackage/initrd" || gen_die "Could not copy initrd for minkernpackage"
	cd "${TEMP}/minkernpackage" 
	tar -jcpf ${MINKERNPACKAGE} * || gen_die "Could not tar up minkernpackage"	
}
