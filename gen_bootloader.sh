# $Id$

set_bootloader() {
    case "${BOOTLOADER}" in
        grub)
            set_bootloader_grub
            ;;
        grub2)
            set_bootloader_grub2
            ;;
        *)
            print_warning "Bootloader ${BOOTLOADER} is not currently supported"
            ;;
    esac
}

set_bootloader_read_fstab() {
    local ROOTFS=$(awk 'BEGIN{RS="((#[^\n]*)?\n)"}( $2 == "/" ) { print $1; exit }' /etc/fstab)
    local BOOTFS=$(awk 'BEGIN{RS="((#[^\n]*)?\n)"}( $2 == "'${BOOTDIR}'") { print $1; exit }' /etc/fstab)

    # If ${BOOTDIR} is not defined in /etc/fstab, it must be the same as /
    [ -z "${BOOTFS}" ] && BOOTFS=${ROOTFS}

    echo "${ROOTFS} ${BOOTFS}"
}

set_bootloader_grub_read_device_map() {
    # Read GRUB device map
    [ ! -d ${TEMP} ] && mkdir ${TEMP}
    echo "quit" | grub --batch --device-map=${TEMP}/grub.map &>/dev/null
    echo "${TEMP}/grub.map"
}

set_bootloader_grub2() {
    local GRUB_CONF
    for candidate in \
            "${BOOTDIR}/grub2/grub.cfg" \
            "${BOOTDIR}/grub/grub.cfg" \
            ; do
        if [[ -e "${candidate}" ]]; then
            GRUB_CONF=${candidate}
            break
        fi
    done

    if [[ -z "${GRUB_CONF}" ]]; then
        print_error 1 "Error! Grub2 configuration file does not exist, please ensure grub2 is correctly setup first."
        return 0
    fi

    print_info 1 "You can customize Grub2 parameters in /etc/default/grub."
    print_info 1 "Running grub2-mkconfig to create ${GRUB_CONF}..."
    grub2-mkconfig -o "${GRUB_CONF}" 2> /dev/null || grub-mkconfig -o "${GRUB_CONF}" 2> /dev/null || gen_die "grub-mkconfig failed"
    [ "${BUILD_RAMDISK}" -ne 0 ] && sed -i 's/ro single/ro debug/' "${GRUB_CONF}"
}

set_bootloader_grub() {
    local GRUB_CONF="${BOOTDIR}/grub/grub.conf"

    print_info 1 "Adding kernel to ${GRUB_CONF}..."

    if [ ! -e ${GRUB_CONF} ]
    then
        local GRUB_BOOTFS
        if [ -n "${BOOTFS}" ]
        then
            GRUB_BOOTFS=$BOOTFS
        else
            GRUB_BOOTFS=$(set_bootloader_read_fstab | cut -d' ' -f2)
        fi

        # Get the GRUB mapping for our device
        local GRUB_BOOT_DISK1=$(echo ${GRUB_BOOTFS} | sed -e 's#\(/dev/.\+\)[[:digit:]]\+#\1#')
        local GRUB_BOOT_DISK=$(awk '{if ($2 == "'${GRUB_BOOT_DISK1}'") {gsub(/(\(|\))/, "", $1); print $1;}}' ${TEMP}/grub.map)
        local GRUB_BOOT_PARTITION=$(($(echo ${GRUB_BOOTFS} | sed -e 's#/dev/.\+\([[:digit:]]?*\)#\1#') - 1))

        if [ -n "${GRUB_BOOT_DISK}" -a -n "${GRUB_BOOT_PARTITION}" ]
        then

            # Create grub configuration directory and file if it doesn't exist.
            [ ! -d `dirname ${GRUB_CONF}` ] && mkdir -p `dirname ${GRUB_CONF}`

            touch ${GRUB_CONF}
            echo 'default 0' >> ${GRUB_CONF}
            echo 'timeout 5' >> ${GRUB_CONF}
            echo "root (${GRUB_BOOT_DISK},${GRUB_BOOT_PARTITION})" >> ${GRUB_CONF}
            echo >> ${GRUB_CONF}

            # Add grub configuration to grub.conf
            echo "# Genkernel generated entry, see GRUB documentation for details" >> ${GRUB_CONF}
            echo "title=Gentoo Linux ($KV)" >> ${GRUB_CONF}
            echo -e "\tkernel /kernel-${KNAME}-${ARCH}-${KV}${KAPPENDNAME} root=${GRUB_ROOTFS}" >> ${GRUB_CONF}
            if [ "${BUILD_INITRD}" = '1' ]
            then
                if [ "${PAT}" -gt '4' ]
                then
                    echo -e "\tinitrd /initramfs-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}" >> ${GRUB_CONF}
                fi
            fi
            echo >> ${GRUB_CONF}
        else
            print_error 1 "Error! ${BOOTDIR}/grub/grub.conf does not exist and the correct settings can not be automatically detected."
            print_error 1 "Please manually create your ${BOOTDIR}/grub/grub.conf file."
        fi

    else
        # The grub.conf already exists, so let's try to duplicate the default entry
        if set_bootloader_grub_check_for_existing_entry "${GRUB_CONF}"; then
            print_warning 1 "An entry was already found for a kernel/initramfs with this name...skipping update"
            return 0
        fi

        set_bootloader_grub_duplicate_default "${GRUB_CONF}"
    fi

}

set_bootloader_grub_duplicate_default_replace_kernel_initrd() {
    sed -r -e "/^[[:space:]]*kernel/s/kernel-[[:alnum:][:punct:]]+/kernel-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}/" - |
    sed -r -e "/^[[:space:]]*initrd/s/init(rd|ramfs)-[[:alnum:][:punct:]]+/init\1-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}/"
}

set_bootloader_grub_check_for_existing_entry() {
    local GRUB_CONF=$1
    if grep -q "^[[:space:]]*kernel[[:space:]=]*.*/kernel-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}\([[:space:]]\|$\)" "${GRUB_CONF}" &&
        grep -q "^[[:space:]]*initrd[[:space:]=]*.*/initramfs-${KNAME}-${ARCH}-${KV}${KAPPENDNAME}\([[:space:]]\|$\)" "${GRUB_CONF}"
    then
        return 0
    fi
    return 1
}

set_bootloader_grub_duplicate_default() {
    local GRUB_CONF=$1
    local GRUB_CONF_TMP="${GRUB_CONF}.tmp"

    line_count=$(wc -l < "${GRUB_CONF}")
    line_nums="$(grep -n "^title" "${GRUB_CONF}" | cut -d: -f1)"
    if [ -z "${line_nums}" ]; then
        print_error 1 "No current 'title' entries found in your grub.conf...skipping update"
        return 0
    fi
    line_nums="${line_nums} $((${line_count}+1))"

    # Find default entry
    default=$(sed -rn '/^[[:space:]]*default[[:space:]=]/s/^.*default[[:space:]=]+([[:alnum:]]+).*$/\1/p' "${GRUB_CONF}")
    if [ -z "${default}" ]; then
        print_warning 1 "No default entry found...assuming 0"
        default=0
    fi
    if ! echo ${default} | grep -q '^[0-9]\+$'; then
        print_error 1 "We don't support non-numeric (such as 'saved') default values...skipping update"
        return 0
    fi

    # Grub defaults are 0 based, cut is 1 based
    # Figure out where the default entry lives
    startstop=$(echo ${line_nums} | cut -d" " -f$((${default}+1))-$((${default}+2)))
    startline=$(echo ${startstop} | cut -d" " -f1)
    stopline=$(echo ${startstop} | cut -d" " -f2)

    # Write out the bits before the default entry
    sed -n 1,$((${startline}-1))p "${GRUB_CONF}" > "${GRUB_CONF_TMP}"

    # Put in our title
    echo "title=Gentoo Linux (${KV})" >> "${GRUB_CONF_TMP}"

    # Pass the default entry (minus the title) through to the replacement function and pipe the output to GRUB_CONF_TMP
    sed -n $((${startline}+1)),$((${stopline}-1))p "${GRUB_CONF}" | set_bootloader_grub_duplicate_default_replace_kernel_initrd >> "${GRUB_CONF_TMP}"

    # Finish off with everything including the previous default entry
    sed -n ${startline},${line_count}p "${GRUB_CONF}" >> "${GRUB_CONF_TMP}"

    cp "${GRUB_CONF}" "${GRUB_CONF}.bak"
    cp "${GRUB_CONF_TMP}" "${GRUB_CONF}"
    rm "${GRUB_CONF_TMP}"
}
