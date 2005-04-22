#!/bin/bash

gen_minkernpackage()
{
	print_info 1 'Creating minimal kernel package'
	rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
	mkdir "${TEMP}/minkernpackage" || gen_die 'Could not make a directory for the kernel package!'
	if [ "${CMD_KERNCACHE}" != "" ]
	then
	    tar -xj -C ${TEMP}/minkernpackage -f ${CMD_KERNCACHE} kernel-${ARCH}-${KV}
	    tar -xj -C ${TEMP}/minkernpackage -f ${CMD_KERNCACHE} config-${ARCH}-${KV}
	else
	    cd "${KERNEL_DIR}"
	    cp "${KERNEL_BINARY}" "${TEMP}/minkernpackage/kernel-${KV}" || gen_die 'Could not the copy kernel for the min kernel package!'
	    cp ".config" "${TEMP}/kerncache/config-${ARCH}-${KV}" || gen_die 'Could not the copy kernel config for the min kernel package!'
	fi
	if [ "${PAT}" -gt '4' -a  "${CMD_BOOTSPLASH}" != '1' ]
	then
		[ "${BUILD_INITRD}" -ne 0 ] && { cp "${TEMP}/initramfs-${KV}" "${TEMP}/minkernpackage/initramfs-${ARCH}-${KV}" || gen_die 'Could not copy the initramfs for the kernel package!'; }
	else
		[ "${BUILD_INITRD}" -ne 0 ] && { cp "${TEMP}/initrd-${KV}" "${TEMP}/minkernpackage/initrd-${ARCH}-${KV}" || gen_die 'Could not copy the initrd for the kernel package!'; }
	fi
	cd "${TEMP}/minkernpackage" 
	tar -jcpf ${MINKERNPACKAGE} * || gen_die 'Could not compress the kernel package!'
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
	    tar -jcpf ${MODULESPACKAGE} * || gen_die 'Could not compress the modules package!'
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
	tar -jcpf ${KERNCACHE} * || gen_die 'Could not compress the kernel package!'
	cd "${TEMP}" && rm -rf "${TEMP}/kerncache" > /dev/null 2>&1
}

gen_kerncache_extract_kernel()
{
	[ -d ${tmp} ] && gen_die "temporary directory already exists! Exiting."
	(umask 077 && mkdir ${tmp}) || {
	    gen_die "Could not create temporary directory! Exiting."
	}
       	tar -f ${KERNCACHE} -C ${tmp} -xj 
	cp "${tmp}/kernel-${ARCH}-${KV}" "/boot/kernel-${KNAME}-${ARCH}-${KV}" || {
		rm -r ${tmp}
		gen_die 'Could not copy the kernel binary to /boot!'
		}
        cp "${tmp}/System.map-${ARCH}-${KV}" "/boot/System.map-${KNAME}-${ARCH}-${KV}" || {
		rm -r ${tmp}
		gen_die 'Could not copy System.map to /boot!'
		}
	rm -r ${tmp}
}

gen_kerncache_extract_modules()
{
        if [ -e "${KERNCACHE}" ] 
	then
		print_info 1 'Extracting kerncache kernel modules'
        	if [ "${INSTALL_MOD_PATH}" != '' ]
		then
        		tar xjf ${KERNCACHE} -C ${INSTALL_MOD_PATH} lib
		else
        		tar xjf ${KERNCACHE} -C / lib
		fi
	fi
}

gen_kerncache_is_valid()
{
	KERNCACHE_IS_VALID=0
	if [ "${CMD_NO_KERNEL_SOURCES}" = '1' ]
	then
		
		BUILD_KERNEL=0
		# Can make this more secure ....
		[ -d ${tmp} ] && gen_die "temporary directory already exists! Exiting."
		(umask 077 && mkdir ${tmp}) || {
		    gen_die "Could not create temporary directory! Exiting."
		}
		
		tar -xj -f ${KERNCACHE} -C ${tmp}
		if [ -e ${tmp}/config-${ARCH}-${KV} -a -e ${tmp}/kernel-${ARCH}-${KV} ] 
		then 	
			print_info 1 'Valid kernel cache found; no sources will be used'
			KERNCACHE_IS_VALID=1
		fi
		/bin/rm -r ${tmp}
        else
		if [ -e "${KERNCACHE}" ] 
		then
			[ -d ${tmp} ] && gen_die "temporary directory already exists! Exiting."
			(umask 077 && mkdir ${tmp}) || {
			    gen_die "Could not create temporary directory! Exiting."
			    
			}
		
			tar -xj -f ${KERNCACHE} -C ${tmp}
			if [ -e ${tmp}/config-${ARCH}-${KV} -a -e /${KERNEL_DIR}/.config ]
			then
	
				test1=$(md5sum ${tmp}/config-${ARCH}-${KV} | cut -d " " -f 1)
				test2=$(md5sum /${KERNEL_DIR}/.config | cut -d " " -f 1)
				if [ "${test1}" == "${test2}" ]
				then
	
					echo
					print_info 1 "No kernel configuration change, skipping kernel build..."
					echo
					KERNCACHE_IS_VALID=1
				fi
			fi
			/bin/rm -r ${tmp}
		fi
	fi
	export KERNCACHE_IS_VALID	
	return 1
}
