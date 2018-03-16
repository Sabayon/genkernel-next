#!/bin/bash
# $Id$

# Fills variable KERNEL_CONFIG
determine_config_file() {
    if [ "${CMD_KERNEL_CONFIG}" != "" ]
    then
        KERNEL_CONFIG="${CMD_KERNEL_CONFIG}"
    elif [ -f "/etc/kernels/kernel-config-${ARCH}-${KV}" ]
    then
        KERNEL_CONFIG="/etc/kernels/kernel-config-${ARCH}-${KV}"
    elif [ -f "${GK_SHARE}/arch/${ARCH}/kernel-config-${KV}" ]
    then
        KERNEL_CONFIG="${GK_SHARE}/arch/${ARCH}/kernel-config-${KV}"
    elif [ "${DEFAULT_KERNEL_CONFIG}" != "" -a -f "${DEFAULT_KERNEL_CONFIG}" ]
    then
        KERNEL_CONFIG="${DEFAULT_KERNEL_CONFIG}"
    elif [ -f "${GK_SHARE}/arch/${ARCH}/kernel-config-${VER}.${PAT}" ]
    then
        KERNEL_CONFIG="${GK_SHARE}/arch/${ARCH}/kernel-config-${VER}.${PAT}"
    elif [ -f "${GK_SHARE}/arch/${ARCH}/kernel-config" ]
    then
        KERNEL_CONFIG="${GK_SHARE}/arch/${ARCH}/kernel-config"
    else
        gen_die 'Error: No kernel .config specified, or file not found!'
    fi
    KERNEL_CONFIG="$(readlink -f "${KERNEL_CONFIG}")"
}

copy_certs() {
    if isTrue "${KCERTS}" && [ "${KCERTS_SRC}" != "" ] && [ "${KCERTS_DST}" != "" ]
    then
        print_info 1 "Copying kernel certificates from ${KCERTS_SRC} to ${KCERTS_DST}"
        cp ${KCERTS_SRC}/* ${KCERTS_DST}
    fi
}

config_kernel() {
    determine_config_file
    cd "${KERNEL_DIR}" || gen_die 'Could not switch to the kernel directory!'

    # Backup current kernel .config
    if isTrue "${MRPROPER}" || [ ! -f "${KERNEL_OUTPUTDIR}/.config" ]
    then
        print_info 1 "kernel: Using config from ${KERNEL_CONFIG}"
        if [ -f "${KERNEL_OUTPUTDIR}/.config" ]
        then
            NOW=`date +--%Y-%m-%d--%H-%M-%S`
            cp "${KERNEL_OUTPUTDIR}/.config" "${KERNEL_OUTPUTDIR}/.config${NOW}.bak" \
                    || gen_die "Could not backup kernel config (${KERNEL_OUTPUTDIR}/.config)"
            print_info 1 "        Previous config backed up to .config${NOW}.bak"
        fi
    fi

    if isTrue ${MRPROPER}
    then
        print_info 1 'kernel: >> Running mrproper...'
        compile_generic mrproper kernel
    else
        print_info 1 "kernel: --mrproper is disabled; not running 'make mrproper'."
    fi

    # If we're not cleaning a la mrproper, then we don't want to try to overwrite the configs
    # or we might remove configurations someone is trying to test.
    if isTrue "${MRPROPER}" || [ ! -f "${KERNEL_OUTPUTDIR}/.config" ]
    then
        local message='Could not copy configuration file!'
        if [[ "$(file --brief --mime-type "${KERNEL_CONFIG}")" == application/x-gzip ]]; then
            # Support --kernel-config=/proc/config.gz, mainly
            zcat "${KERNEL_CONFIG}" > "${KERNEL_OUTPUTDIR}/.config" || gen_die "${message}"
        else
            cp "${KERNEL_CONFIG}" "${KERNEL_OUTPUTDIR}/.config" || gen_die "${message}"
        fi
    fi

    if isTrue "${OLDCONFIG}"
    then
        print_info 1 '        >> Running oldconfig...'
        yes '' 2>/dev/null | compile_generic oldconfig kernel 2>/dev/null
    else
        print_info 1 "kernel: --oldconfig is disabled; not running 'make oldconfig'."
    fi
    if isTrue "${CLEAN}"
    then
        print_info 1 'kernel: >> Cleaning...'
        compile_generic clean kernel
    else
        print_info 1 "kernel: --clean is disabled; not running 'make clean'."
    fi

    if isTrue ${MENUCONFIG}
    then
        print_info 1 'kernel: >> Invoking menuconfig...'
        compile_generic menuconfig kernelruntask
        [ "$?" ] || gen_die 'Error: menuconfig failed!'
    elif isTrue ${NCONFIG}
    then
        print_info 1 'kernel: >> Invoking nconfig...'
        compile_generic nconfig kernelruntask
        [ "$?" ] || gen_die 'Error: nconfig failed!'
    elif isTrue ${CMD_GCONFIG}
    then
        print_info 1 'kernel: >> Invoking gconfig...'
        compile_generic gconfig kernel
        [ "$?" ] || gen_die 'Error: gconfig failed!'

        CMD_XCONFIG=0
    fi

    if isTrue ${CMD_XCONFIG}
    then
        print_info 1 'kernel: >> Invoking xconfig...'
        compile_generic xconfig kernel
        [ "$?" ] || gen_die 'Error: xconfig failed!'
    fi

    copy_certs
}
