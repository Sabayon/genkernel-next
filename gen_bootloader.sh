set_bootloader() {
	case "${BOOTLOADER}" in
		grub)
			set_bootloader_grub
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
			if [ "${BUILD_INITRD}" -eq '0' ]
			then
				echo -e "\tkernel /kernel-${KNAME}-${ARCH}-${KV} root=${GRUB_ROOTFS}" >> ${GRUB_CONF}
			else
				echo -e "\tkernel /kernel-${KNAME}-${ARCH}-${KV} root=/dev/ram0 init=/linuxrc real_root=${GRUB_ROOTFS}" >> ${GRUB_CONF}
				if [ "${PAT}" -gt '4' ]
				then
				    echo -e "\tinitrd /initramfs-${KNAME}-${ARCH}-${KV}" >> ${GRUB_CONF}
				fi
			fi
			echo >> ${GRUB_CONF}
		else
			print_error 1 "Error! ${BOOTDIR}/grub/grub.conf does not exist and the correct settings can not be automatically detected."
			print_error 1 "Please manually create your ${BOOTDIR}/grub/grub.conf file."
		fi

	else
		# The grub.conf already exists, so let's try to duplicate the default entry
	fi

}
