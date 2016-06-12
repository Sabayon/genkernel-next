#!/bin/bash
# $Id$

gen_minkernpackage() {
    print_info 1 'Creating minimal kernel package'
    rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
    mkdir "${TEMP}/minkernpackage" || gen_die 'Could not make a directory for the kernel package!'
    if [ "${KERNCACHE}" != "" ]
    then
        /bin/tar -xj -C ${TEMP}/minkernpackage -f ${KERNCACHE} kernel-${ARCH}-${KV}
        /bin/tar -xj -C ${TEMP}/minkernpackage -f ${KERNCACHE} config-${ARCH}-${KV}
        if isTrue "${GENZIMAGE}"
        then
            /bin/tar -xj -C ${TEMP}/minkernpackage -f ${KERNCACHE} kernelz-${ARCH}-${KV}
        fi
    else
        local tmp_kernel_binary=$(find_kernel_binary ${KERNEL_BINARY})
        local tmp_kernel_binary2=$(find_kernel_binary ${KERNEL_BINARY_2})
        if [ -z "${tmp_kernel_binary}" ]
        then
            gen_die "Cannot locate kernel binary"
        fi
        cd "${KERNEL_OUTPUTDIR}"
        cp "${tmp_kernel_binary}" "${TEMP}/minkernpackage/kernel-${KV}" || gen_die 'Could not the copy kernel for the min kernel package!'
        cp ".config" "${TEMP}/minkernpackage/config-${ARCH}-${KV}" || gen_die 'Could not the copy kernel config for the min kernel package!'
        if isTrue "${GENZIMAGE}"
        then
            cp "${tmp_kernel_binary2}" "${TEMP}/minkernpackage/kernelz-${KV}" || gen_die "Could not copy the kernelz for the min kernel package"
        fi
    fi

    if ! isTrue "${INTEGRATED_INITRAMFS}"
    then
        [ "${BUILD_RAMDISK}" != '0' ] && { cp "${TMPDIR}/initramfs-${KV}" "${TEMP}/minkernpackage/initramfs-${ARCH}-${KV}" || gen_die 'Could not copy the initramfs for the kernel package!'; }
    fi

    if [ "${KERNCACHE}" != "" ]
    then
        /bin/tar -xj -C ${TEMP}/minkernpackage -f ${KERNCACHE} System.map-${ARCH}-${KV}
    else
        cp "${KERNEL_OUTPUTDIR}/System.map" "${TEMP}/minkernpackage/System.map-${ARCH}-${KV}" || gen_die 'Could not copy System.map for the kernel package!';
    fi

    cd "${TEMP}/minkernpackage"
    /bin/tar -jcpf ${MINKERNPACKAGE} * || gen_die 'Could not compress the kernel package!'
    cd "${TEMP}" && rm -rf "${TEMP}/minkernpackage" > /dev/null 2>&1
}

gen_modulespackage() {
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

    local tmp_kernel_binary=$(find_kernel_binary ${KERNEL_BINARY})
    local tmp_kernel_binary2=$(find_kernel_binary ${KERNEL_BINARY_2})
    if [ -z "${tmp_kernel_binary}" ]
    then
        gen_die "Cannot locate kernel binary"
    fi

    cd "${KERNEL_OUTPUTDIR}"
    cp "${tmp_kernel_binary}" "${TEMP}/kerncache/kernel-${ARCH}-${KV}" || gen_die 'Could not the copy kernel for the kernel package!'
    cp "${KERNEL_OUTPUTDIR}/.config" "${TEMP}/kerncache/config-${ARCH}-${KV}"

    if [[ "$(file --brief --mime-type "${KERNEL_CONFIG}")" == application/x-gzip ]]; then
        # Support --kernel-config=/proc/config.gz, mainly
        zcat "${KERNEL_CONFIG}" > "${TEMP}/kerncache/config-${ARCH}-${KV}.orig"
    else
        cp "${KERNEL_CONFIG}" "${TEMP}/kerncache/config-${ARCH}-${KV}.orig"
    fi
    cp "${KERNEL_OUTPUTDIR}/System.map" "${TEMP}/kerncache/System.map-${ARCH}-${KV}"
    if isTrue "${GENZIMAGE}"
    then
        cp "${tmp_kernel_binary2}" "${TEMP}/kerncache/kernelz-${ARCH}-${KV}" || gen_die "Could not copy the kernelz for the kernel package"
    fi

    echo "VERSION = ${VER}" > "${TEMP}/kerncache/kerncache.config"
    echo "PATCHLEVEL = ${PAT}" >> "${TEMP}/kerncache/kerncache.config"
    echo "SUBLEVEL = ${SUB}" >> "${TEMP}/kerncache/kerncache.config"
    echo "EXTRAVERSION = ${EXV}" >> "${TEMP}/kerncache/kerncache.config"
    echo "CONFIG_LOCALVERSION = ${LOV}" >> "${TEMP}/kerncache/kerncache.config"

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
    copy_image_with_preserve "kernel" \
        "${TEMP}/kernel-${ARCH}-${KV}" \
        "kernel-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}"

    if isTrue "${GENZIMAGE}"
    then
        copy_image_with_preserve "kernelz" \
            "${TEMP}/kernelz-${ARCH}-${KV}" \
            "kernelz-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}"
    fi

    copy_image_with_preserve "System.map" \
        "${TEMP}/System.map-${ARCH}-${KV}" \
        "System.map-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}"
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
    if [ -e "${KERNCACHE}" -a "${SAVE_CONFIG}" = '1' ]
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
    if [ "${KERNEL_SOURCES}" = '0' ]
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
            KERNEL_CONFIG="/${KERNEL_OUTPUTDIR}/.config"
            if [ "${CMD_KERNEL_CONFIG}" != '' ]
            then
                KERNEL_CONFIG="${CMD_KERNEL_CONFIG}"
            fi

            /bin/tar -xj -f ${KERNCACHE} -C ${TEMP}
            if [ -e ${TEMP}/config-${ARCH}-${KV} -a -e ${KERNEL_CONFIG} ]
            then

                if [ -e ${TEMP}/config-${ARCH}-${KV}.orig ]
                then
                    test1=$(grep -v "^#" ${TEMP}/config-${ARCH}-${KV}.orig | md5sum | cut -d " " -f 1)
                else
                    test1=$(grep -v "^#" ${TEMP}/config-${ARCH}-${KV} | md5sum | cut -d " " -f 1)
                fi

                if [[ "$(file --brief --mime-type "${KERNEL_CONFIG}")" == application/x-gzip ]]; then
                    # Support --kernel-config=/proc/config.gz, mainly
                    local CONFGREP=zgrep
                else
                    local CONFGREP=grep
                fi
                test2=$("${CONFGREP}" -v "^#" ${KERNEL_CONFIG} | md5sum | cut -d " " -f 1)


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
