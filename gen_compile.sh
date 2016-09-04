#!/bin/bash
# $Id$

compile_kernel_args() {
    local ARGS

    ARGS=''
    if [ "${KERNEL_CC}" != '' ]
    then
        ARGS="CC=\"${KERNEL_CC}\""
    fi
    if [ "${KERNEL_LD}" != '' ]
    then
        ARGS="${ARGS} LD=\"${KERNEL_LD}\""
    fi
    if [ "${KERNEL_AS}" != '' ]
    then
        ARGS="${ARGS} AS=\"${KERNEL_AS}\""
    fi
    if [ -n "${KERNEL_ARCH}" ]
    then
        ARGS="${ARGS} ARCH=\"${KERNEL_ARCH}\""
    fi
    if [ -n "${KERNEL_OUTPUTDIR}" -a "${KERNEL_OUTPUTDIR}" != "${KERNEL_DIR}" ]
    then
        ARGS="${ARGS} O=\"${KERNEL_OUTPUTDIR}\""
    fi
    echo -n "${ARGS}"
}

compile_utils_args()
{
    local ARGS
    ARGS=''

    if [ "${UTILS_ARCH}" != '' ]
    then
        ARGS="ARCH=\"${UTILS_ARCH}\""
    fi
    if [ "${UTILS_CC}" != '' ]
    then
        ARGS="CC=\"${UTILS_CC}\""
    fi
    if [ "${UTILS_LD}" != '' ]
    then
        ARGS="${ARGS} LD=\"${UTILS_LD}\""
    fi
    if [ "${UTILS_AS}" != '' ]
    then
        ARGS="${ARGS} AS=\"${UTILS_AS}\""
    fi

    echo -n "${ARGS}"
}

export_utils_args()
{
    save_args
    if [ "${UTILS_ARCH}" != '' ]
    then
        export ARCH="${UTILS_ARCH}"
    fi
    if [ "${UTILS_CC}" != '' ]
    then
        export CC="${UTILS_CC}"
    fi
    if [ "${UTILS_LD}" != '' ]
    then
        export LD="${UTILS_LD}"
    fi
    if [ "${UTILS_AS}" != '' ]
    then
        export AS="${UTILS_AS}"
    fi
}

unset_utils_args()
{
    if [ "${UTILS_ARCH}" != '' ]
    then
        unset ARCH
    fi
    if [ "${UTILS_CC}" != '' ]
    then
        unset CC
    fi
    if [ "${UTILS_LD}" != '' ]
    then
        unset LD
    fi
    if [ "${UTILS_AS}" != '' ]
    then
        unset AS
    fi
    reset_args
}

export_kernel_args()
{
    if [ "${KERNEL_CC}" != '' ]
    then
        export CC="${KERNEL_CC}"
    fi
    if [ "${KERNEL_LD}" != '' ]
    then
        export LD="${KERNEL_LD}"
    fi
    if [ "${KERNEL_AS}" != '' ]
    then
        export AS="${KERNEL_AS}"
    fi
}

unset_kernel_args()
{
    if [ "${KERNEL_CC}" != '' ]
    then
        unset CC
    fi
    if [ "${KERNEL_LD}" != '' ]
    then
        unset LD
    fi
    if [ "${KERNEL_AS}" != '' ]
    then
        unset AS
    fi
}
save_args()
{
    if [ "${ARCH}" != '' ]
    then
        export ORIG_ARCH="${ARCH}"
    fi
    if [ "${CC}" != '' ]
    then
        export ORIG_CC="${CC}"
    fi
    if [ "${LD}" != '' ]
    then
        export ORIG_LD="${LD}"
    fi
    if [ "${AS}" != '' ]
    then
        export ORIG_AS="${AS}"
    fi
}
reset_args()
{
    if [ "${ORIG_ARCH}" != '' ]
    then
        export ARCH="${ORIG_ARCH}"
        unset ORIG_ARCH
    fi
    if [ "${ORIG_CC}" != '' ]
    then
        export CC="${ORIG_CC}"
        unset ORIG_CC
    fi
    if [ "${ORIG_LD}" != '' ]
    then
        export LD="${ORIG_LD}"
        unset ORIG_LD
    fi
    if [ "${ORIG_AS}" != '' ]
    then
        export AS="${ORIG_AS}"
        unset ORIG_AS
    fi
}

apply_patches() {
    util=$1
    version=$2

    if [ -d "${GK_SHARE}/patches/${util}/${version}" ]
    then
        print_info 1 "${util}: >> Applying patches..."
        for i in ${GK_SHARE}/patches/${util}/${version}/*{diff,patch}
        do
            [ -f "${i}" ] || continue
            patch_success=0
            for j in `seq 0 5`
            do
                patch -p${j} --backup-if-mismatch -f < "${i}" >/dev/null
                if [ $? = 0 ]
                then
                    patch_success=1
                    break
                fi
            done
            if [ ${patch_success} -eq 1 ]
            then
                print_info 1 "          - `basename ${i}`"
            else
                gen_die "could not apply patch ${i} for ${util}-${version}"
            fi
        done
    fi
}

compile_generic() {
    local RET
    [ "$#" -lt '2' ] &&
        gen_die 'compile_generic(): improper usage!'
    local target=${1}
    local argstype=${2}

    case "${argstype}" in
        kernel|kernelruntask)
            export_kernel_args
            MAKE=${KERNEL_MAKE}
            ;;
        utils)
            export_utils_args
            MAKE=${UTILS_MAKE}
            ;;
    esac

    case "${argstype}" in
        kernel|kernelruntask) ARGS="`compile_kernel_args`" ;;
        utils) ARGS="`compile_utils_args`" ;;
        *) ARGS="" ;;
    esac
    shift 2

    # the eval usage is needed in the next set of code
    # as ARGS can contain spaces and quotes, eg:
    # ARGS='CC="ccache gcc"'
    if [ "${argstype}" == 'kernelruntask' ]
    then
        # Silent operation, forced -j1
        print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} -j1 ${ARGS} ${target} $*" 1 0 1
        eval ${MAKE} -s ${MAKEOPTS} -j1 "${ARGS}" ${target} $*
        RET=$?
    elif [ "${LOGLEVEL}" -gt "1" ]
    then
        # Output to stdout and logfile
        print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} ${ARGS} ${target} $*" 1 0 1
        eval ${MAKE} ${MAKEOPTS} ${ARGS} ${target} $* 2>&1 | tee -a ${LOGFILE}
        RET=${PIPESTATUS[0]}
    else
        # Output to logfile only
        print_info 2 "COMMAND: ${MAKE} ${MAKEOPTS} ${ARGS} ${1} $*" 1 0 1
        eval ${MAKE} ${MAKEOPTS} ${ARGS} ${target} $* >> ${LOGFILE} 2>&1
        RET=$?
    fi
    [ ${RET} -ne 0 ] &&
        gen_die "Failed to compile the \"${target}\" target..."

    unset MAKE
    unset ARGS

    case "${argstype}" in
        kernel) unset_kernel_args ;;
        utils) unset_utils_args ;;
    esac
}

compile_modules() {
    print_info 1 "        >> Compiling ${KV} modules..."
    cd ${KERNEL_DIR}
    compile_generic modules kernel
    export UNAME_MACHINE="${ARCH}"
    [ "${INSTALL_MOD_PATH}" != '' ] && export INSTALL_MOD_PATH
    MAKEOPTS="${MAKEOPTS} -j1" compile_generic "modules_install" kernel
    print_info 1 "        >> Generating module dependency data..."
    if [ "${INSTALL_MOD_PATH}" != '' ]
    then
        depmod -a -e -F "${KERNEL_OUTPUTDIR}"/System.map -b "${INSTALL_MOD_PATH}" ${KV}
    else
        depmod -a -e -F "${KERNEL_OUTPUTDIR}"/System.map ${KV}
    fi
    unset UNAME_MACHINE
}

compile_kernel() {
    [ "${KERNEL_MAKE}" = '' ] &&
        gen_die "KERNEL_MAKE undefined - I don't know how to compile a kernel for this arch!"
    cd ${KERNEL_DIR}
    local kernel_make_directive="${KERNEL_MAKE_DIRECTIVE}"
    if [ "${KERNEL_MAKE_DIRECTIVE_OVERRIDE}" != "${DEFAULT_KERNEL_MAKE_DIRECTIVE_OVERRIDE}" ]; then
        kernel_make_directive="${KERNEL_MAKE_DIRECTIVE_OVERRIDE}"
    fi
    print_info 1 "        >> Compiling ${KV} ${kernel_make_directive/_install/ [ install ]/}..."
    compile_generic "${kernel_make_directive}" kernel
    if [ "${KERNEL_MAKE_DIRECTIVE_2}" != '' ]
    then
        print_info 1 "        >> Starting supplimental compile of ${KV}: ${KERNEL_MAKE_DIRECTIVE_2}..."
        compile_generic "${KERNEL_MAKE_DIRECTIVE_2}" kernel
    fi

    local firmware_in_kernel_line=`fgrep CONFIG_FIRMWARE_IN_KERNEL "${KERNEL_OUTPUTDIR}"/.config`
    if [ -n "${firmware_in_kernel_line}" -a "${firmware_in_kernel_line}" != CONFIG_FIRMWARE_IN_KERNEL=y ]
    then
        print_info 1 "        >> Installing firmware ('make firmware_install') due to CONFIG_FIRMWARE_IN_KERNEL != y..."
        [ "${INSTALL_MOD_PATH}" != '' ] && export INSTALL_MOD_PATH
        [ "${INSTALL_FW_PATH}" != '' ] && export INSTALL_FW_PATH
        MAKEOPTS="${MAKEOPTS} -j1" compile_generic "firmware_install" kernel
    else
        print_info 1 "        >> Not installing firmware as it's included in the kernel already (CONFIG_FIRMWARE_IN_KERNEL=y)..."
    fi

    local tmp_kernel_binary=$(find_kernel_binary ${KERNEL_BINARY_OVERRIDE:-${KERNEL_BINARY}})
    local tmp_kernel_binary2=$(find_kernel_binary ${KERNEL_BINARY_2})
    if [ -z "${tmp_kernel_binary}" ]
    then
        gen_die "Cannot locate kernel binary"
    fi

    if isTrue "${CMD_INSTALL}"
    then
        copy_image_with_preserve "kernel" \
            "${tmp_kernel_binary}" \
            "kernel-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}"

        copy_image_with_preserve "System.map" \
            "System.map" \
            "System.map-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}"

        if isTrue "${GENZIMAGE}"
        then
            copy_image_with_preserve "kernelz" \
                "${tmp_kernel_binary2}" \
                "kernelz-${KV}"
        fi
    else
        cp "${tmp_kernel_binary}" "${TMPDIR}/kernel-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}" ||
            gen_die "Could not copy the kernel binary to ${TMPDIR}!"
        cp "System.map" "${TMPDIR}/System.map-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}" ||
            gen_die "Could not copy System.map to ${TMPDIR}!"
        if isTrue "${GENZIMAGE}"
        then
            cp "${tmp_kernel_binary2}" "${TMPDIR}/kernelz-${KV}" ||
                gen_die "Could not copy the kernelz binary to ${TMPDIR}!"
        fi
    fi
}

compile_busybox() {
    [ -f "${BUSYBOX_SRCTAR}" ] ||
        gen_die "Could not find busybox source tarball: ${BUSYBOX_SRCTAR}!"

    if [ -n "${BUSYBOX_CONFIG}" ]
    then
        [ -f "${BUSYBOX_CONFIG}" ] ||
            gen_die "Could not find busybox config file: ${BUSYBOX_CONFIG}"
    elif isTrue "${NETBOOT}" && [ -f "$(arch_replace "${GK_SHARE}/arch/%%ARCH%%/netboot-busy-config")" ]
    then
        BUSYBOX_CONFIG="$(arch_replace "${GK_SHARE}/arch/%%ARCH%%/netboot-busy-config")"
    elif isTrue "${NETBOOT}" && [ -f "${GK_SHARE}/netboot/busy-config" ]
    then
        BUSYBOX_CONFIG="${GK_SHARE}/netboot/busy-config"
    elif [ -f "$(arch_replace "${GK_SHARE}/arch/%%ARCH%%/busy-config")" ]
    then
        BUSYBOX_CONFIG="$(arch_replace "${GK_SHARE}/arch/%%ARCH%%/busy-config")"
    elif [ -f "${GK_SHARE}/defaults/busy-config" ]
    then
        BUSYBOX_CONFIG="${GK_SHARE}/defaults/busy-config"
    else
        gen_die "Could not find a busybox config file"
    fi

    # Delete cache if stored config's MD5 does not match one to be used
    if [ -f "${BUSYBOX_BINCACHE}" ]
    then
        oldconfig_md5=$(tar -xjf "${BUSYBOX_BINCACHE}" -O .config.gk_orig 2>/dev/null | md5sum)
        newconfig_md5=$(md5sum < "${BUSYBOX_CONFIG}")
        if [ "${oldconfig_md5}" != "${newconfig_md5}" ]
        then
            print_info 1 "busybox: >> Removing stale cache..."
            rm -rf "${BUSYBOX_BINCACHE}"
        else
            print_info 1 "busybox: >> Using cache"
        fi
    fi

    if [ ! -f "${BUSYBOX_BINCACHE}" ]
    then
        cd "${TEMP}"
        rm -rf "${BUSYBOX_DIR}" > /dev/null
        /bin/tar -jxpf ${BUSYBOX_SRCTAR} ||
            gen_die 'Could not extract busybox source tarball!'
        [ -d "${BUSYBOX_DIR}" ] ||
            gen_die "Busybox directory ${BUSYBOX_DIR} is invalid!"
        cp "${BUSYBOX_CONFIG}" "${BUSYBOX_DIR}/.config"
        cp "${BUSYBOX_CONFIG}" "${BUSYBOX_DIR}/.config.gk_orig"
        cd "${BUSYBOX_DIR}"
        apply_patches busybox ${BUSYBOX_VER}
        print_info 1 'busybox: >> Configuring...'
        yes '' 2>/dev/null | compile_generic oldconfig utils

        print_info 1 'busybox: >> Compiling...'
        compile_generic all utils
        print_info 1 'busybox: >> Copying to cache...'
        [ -f "${TEMP}/${BUSYBOX_DIR}/busybox" ] ||
            gen_die 'Busybox executable does not exist!'
        strip "${TEMP}/${BUSYBOX_DIR}/busybox" ||
            gen_die 'Could not strip busybox binary!'
        tar -cj -C "${TEMP}/${BUSYBOX_DIR}" -f "${BUSYBOX_BINCACHE}" busybox .config .config.gk_orig ||
            gen_die 'Could not create the busybox bincache!'

        cd "${TEMP}"
        rm -rf "${BUSYBOX_DIR}" > /dev/null
    fi
}
