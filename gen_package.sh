#!/bin/bash

gen_minkernpackage()
{
	print_info 1 'Creating minimal kernel package'
	rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
	mkdir "${TEMP}/minkernpackage" || gen_die 'Could not make a directory for the kernel package!'
	if [ "${CMD_KERNCACHE}" != "" ]
	then
	    /bin/tar -xj -C ${TEMP}/minkernpackage -f ${CMD_KERNCACHE} kernel-${ARCH}-${KV}
	    /bin/tar -xj -C ${TEMP}/minkernpackage -f ${CMD_KERNCACHE} config-${ARCH}-${KV}
	    if [ "${KERNEL_BINARY_2}" != '' -a "${GENERATE_Z_IMAGE}" = '1' ]
            then
	    	/bin/tar -xj -C ${TEMP}/minkernpackage -f ${CMD_KERNCACHE} kernelz-${ARCH}-${KV}
            fi
	else
	    cd "${KERNEL_DIR}"
	    cp "${KERNEL_BINARY}" "${TEMP}/minkernpackage/kernel-${KV}" || gen_die 'Could not the copy kernel for the min kernel package!'
	    cp ".config" "${TEMP}/minkernpackage/config-${ARCH}-${KV}" || gen_die 'Could not the copy kernel config for the min kernel package!'
	    if [ "${KERNEL_BINARY_2}" != '' -a "${GENERATE_Z_IMAGE}" = '1' ]
            then
            	cp "${KERNEL_BINARY_2}" "${TEMP}/minkernpackage/kernelz-${KV}" || gen_die "Could not copy the kernelz for the min kernel package"
            fi

	fi
	
	if [ "${GENERATE_Z_IMAGE}" != '1' ]
	then
	    if [ "${KERN_24}" != '1' -a  "${CMD_BOOTSPLASH}" != '1' ]
	    then
		    [ "${BUILD_INITRD}" -ne 0 ] && { cp "${TMPDIR}/initramfs-${KV}" "${TEMP}/minkernpackage/initramfs-${ARCH}-${KV}" || gen_die 'Could not copy the initramfs for the kernel package!'; }
	    else
		    [ "${BUILD_INITRD}" -ne 0 ] && { cp "${TMPDIR}/initrd-${KV}" "${TEMP}/minkernpackage/initrd-${ARCH}-${KV}" || gen_die 'Could not copy the initrd for the kernel package!'; }
	    fi
	fi
	
	cd "${TEMP}/minkernpackage" 
	/bin/tar -jcpf ${MINKERNPACKAGE} * || gen_die 'Could not compress the kernel package!'
	cd "${TEMP}" && rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
}
gen_modulespackage()
{
	print_info 1 'Creating modules package'
	rm -rf "${TEMP}/modulespackage" > /dev/null 2>&1
	mkdir "${TEMP}/modulespackage" || gen_die 'Could not make a directory for the kernel package!'

	if [ -d ${INSTALL_MOD_PATH}/lib/modules/${KV} ]
	then
	    mkdir -p ${TEMP}/modulespackage/lib/modules
	    cp -r "${INSTALL_MOD_PATH}/lib/modules/${KV}" "${TEMP}/modulespackage/lib/modules"
	    cd "${TEMP}/modulespackage" 
	    /bin/tar -jcpf ${MODULESPACKAGE} * || gen_die 'Could not compress the modules package!'
	else
	    print_info 1 "Could not create a modules package ${INSTALL_MOD_PATH}/lib/modules/${KV} was not found"
	fi
	cd "${TEMP}" && rm -rf "${TEMP}/modulespackage" > /dev/null 2>&1
}
gen_kerncache()
{
	print_info 1 'Creating kernel cache'
	rm -rf "${TEMP}/kerncache" > /dev/null 2>&1
	mkdir "${TEMP}/kerncache" || gen_die 'Could not make a directory for the kernel cache!'
	cd "${KERNEL_DIR}"
	cp "${KERNEL_BINARY}" "${TEMP}/kerncache/kernel-${ARCH}-${KV}" || gen_die 'Could not the copy kernel for the kernel package!'
	cp "${KERNEL_DIR}/.config" "${TEMP}/kerncache/config-${ARCH}-${KV}"
	cp "${KERNEL_DIR}/System.map" "${TEMP}/kerncache/System.map-${ARCH}-${KV}"
	if [ "${KERNEL_BINARY_2}" != '' -a "${GENERATE_Z_IMAGE}" = '1' ]
        then
        	cp "${KERNEL_BINARY_2}" "${TEMP}/kerncache/kernelz-${ARCH}-${KV}" || gen_die "Could not copy the kernelz for the kernel package"
        fi
	
	echo "VERSION = ${VER}" > "${TEMP}/kerncache/kerncache.config"
	echo "PATCHLEVEL = ${PAT}" >> "${TEMP}/kerncache/kerncache.config"
	echo "SUBLEVEL = ${SUB}" >> "${TEMP}/kerncache/kerncache.config"
	echo "EXTRAVERSION = ${EXV}" >> "${TEMP}/kerncache/kerncache.config"
	
	mkdir -p "${TEMP}/kerncache/lib/modules/"
	
	if [ -d ${INSTALL_MOD_PATH}/lib/modules/${KV} ]
	then
	    cp -r "${INSTALL_MOD_PATH}/lib/modules/${KV}" "${TEMP}/kerncache/lib/modules"
	fi
	
	cd "${TEMP}/kerncache" 
	/bin/tar -jcpf ${KERNCACHE} * || gen_die 'Could not compress the kernel package!'
	cd "${TEMP}" && rm -rf "${TEMP}/kerncache" > /dev/null 2>&1
}

gen_kerncache_extract_kernel()
{
       	/bin/tar -f ${KERNCACHE} -C ${TEMP} -xj 
	cp "${TEMP}/kernel-${ARCH}-${KV}" "${BOOTDIR}/kernel-${KNAME}-${ARCH}-${KV}" || gen_die "Could not copy the kernel binary to ${BOOTDIR}!"
	if [ "${KERNEL_BINARY_2}" != '' -a "${GENERATE_Z_IMAGE}" = '1' ]
        then
		cp "${TEMP}/kernelz-${ARCH}-${KV}" "${BOOTDIR}/kernelz-${KNAME}-${ARCH}-${KV}" || gen_die "Could not copy the kernel binary to ${BOOTDIR}!"
        fi
        cp "${TEMP}/System.map-${ARCH}-${KV}" "${BOOTDIR}/System.map-${KNAME}-${ARCH}-${KV}" || gen_die "Could not copy System.map to ${BOOTDIR}!"
}

gen_kerncache_extract_modules()
{
        if [ -e "${KERNCACHE}" ] 
	then
		print_info 1 'Extracting kerncache kernel modules'
        	if [ "${INSTALL_MOD_PATH}" != '' ]
		then
        		/bin/tar -xjf ${KERNCACHE} -C ${INSTALL_MOD_PATH} lib
		else
        		/bin/tar -xjf ${KERNCACHE} -C / lib
		fi
	fi
}

gen_kerncache_extract_config()
{
	if [ -e "${KERNCACHE}" ] 
	then
		print_info 1 'Extracting kerncache config to /etc/kernels'
		mkdir -p /etc/kernels
        	/bin/tar -xjf ${KERNCACHE} -C /etc/kernels config-${ARCH}-${KV}
		mv /etc/kernels/config-${ARCH}-${KV} /etc/kernels/kernel-config-${ARCH}-${KV}
	fi
}

gen_kerncache_is_valid()
{
	KERNCACHE_IS_VALID=0
	if [ "${CMD_NO_KERNEL_SOURCES}" = '1' ]
	then
		
		BUILD_KERNEL=0
		# Can make this more secure ....
		
		/bin/tar -xj -f ${KERNCACHE} -C ${TEMP}
		if [ -e ${TEMP}/config-${ARCH}-${KV} -a -e ${TEMP}/kernel-${ARCH}-${KV} ] 
		then 	
			print_info 1 'Valid kernel cache found; no sources will be used'
			KERNCACHE_IS_VALID=1
		fi
        else
		if [ -e "${KERNCACHE}" ] 
		then
			/bin/tar -xj -f ${KERNCACHE} -C ${TEMP}
			if [ -e ${TEMP}/config-${ARCH}-${KV} -a -e /${KERNEL_DIR}/.config ]
			then
	
				test1=$(md5sum ${TEMP}/config-${ARCH}-${KV} | cut -d " " -f 1)
				test2=$(md5sum /${KERNEL_DIR}/.config | cut -d " " -f 1)
				if [ "${test1}" == "${test2}" ]
				then
	
					echo
					print_info 1 "No kernel configuration change, skipping kernel build..."
					echo
					KERNCACHE_IS_VALID=1
				fi
			fi
		fi
	fi
	export KERNCACHE_IS_VALID	
	return 1
}
