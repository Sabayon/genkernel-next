#!/bin/bash

set_bootloader() {
	if [ "x${BOOTLOADER}" == 'xgrub' ]
	then
		set_grub_bootloader
	else
		return 0
	fi
}

set_grub_bootloader() {
	local GRUB_CONF="${BOOTDIR}/grub/grub.conf"

	print_info 1 ''
	print_info 1 "Adding kernel to ${GRUB_CONF}..."
	if [ "${BOOTFS}" != '' ]
	then
		GRUB_BOOTFS=${BOOTFS}
	else	
		# Extract block device information from /etc/fstab
		GRUB_ROOTFS=$(awk 'BEGIN{RS="((#[^\n]*)?\n)"}( $2 == "/" ) { print $1; exit }' /etc/fstab)
		GRUB_BOOTFS=$(awk 'BEGIN{RS="((#[^\n]*)?\n)"}( $2 == "'${BOOTDIR}'") { print $1; exit }' /etc/fstab)

		# If ${BOOTDIR} is not defined in /etc/fstab, it must be the same as /
		[ "x${GRUB_BOOTFS}" == 'x' ] && GRUB_BOOTFS=${GRUB_ROOTFS}
	fi

	# Read GRUB device map
	[ ! -d ${TEMP} ] && mkdir ${TEMP}
	grub --batch --device-map=${TEMP}/grub.map <<EOF >/dev/null 2>&1
quit
EOF
	# Get the GRUB mapping for our device
	local GRUB_BOOT_DISK1=$(echo ${GRUB_BOOTFS} | sed -e 's#\(/dev/.\+\)[[:digit:]]\+#\1#')
	local GRUB_BOOT_DISK=$(awk '{if ($2 == "'${GRUB_BOOT_DISK1}'") {gsub(/(\(|\))/, "", $1); print $1;}}' ${TEMP}/grub.map)

	local GRUB_BOOT_PARTITION=$(echo ${GRUB_BOOTFS} | sed -e 's#/dev/.\+\([[:digit:]]?*\)#\1#')
	[ ! -d ${TEMP} ] && rm -r ${TEMP}
	
	# Create grub configuration directory and file if it doesn't exist.
	[ ! -e `dirname ${GRUB_CONF}` ] && mkdir -p `dirname ${GRUB_CONF}`

	if [ ! -e ${GRUB_CONF} ]
	then
		if [ "${GRUB_BOOT_DISK}" != '' -a "${GRUB_BOOT_PARTITION}" != '' ]
		then
			GRUB_BOOT_PARTITION=`expr ${GRUB_BOOT_PARTITION} - 1`
			# grub.conf doesn't exist - create it with standard defaults
			touch ${GRUB_CONF}
			echo 'default 0' >> ${GRUB_CONF}
			echo 'timeout 5' >> ${GRUB_CONF}
			echo >> ${GRUB_CONF}

			# Add grub configuration to grub.conf	
			echo "# Genkernel generated entry, see GRUB documentation for details" >> ${GRUB_CONF}
			echo "title=Gentoo Linux ($KV)" >> ${GRUB_CONF}
			echo -e "\troot (${GRUB_BOOT_DISK},${GRUB_BOOT_PARTITION})" >> ${GRUB_CONF}
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
		# grub.conf already exists; so...
		# ... Clone the first boot definition and change the version.
		local TYPE
		[ "${KERN_24}" -eq '1' ] && TYPE='rd' || TYPE='ramfs'

		cp -f ${GRUB_CONF} ${GRUB_CONF}.bak
		awk 'BEGIN { RS="\n"; }
		     {
			if(match($0, "kernel-" KNAME "-" ARCH "-" KV))
			{ have_k="1" }
			if(match($0, "init" TYPE "-" KNAME "-" ARCH "-" KV))
			{ have_i="1" }
			if(have_k == "1" && have_i == "1")
			{ exit 1; }
		     }' KNAME=${KNAME} ARCH=${ARCH} KV=${KV} TYPE=${TYPE} ${GRUB_CONF}.bak
		if [ "$?" -eq '0' ]
		then
			local LIMIT=$(wc -l ${GRUB_CONF}.bak)
			awk -f ${GK_SHARE}/gen_bootloader_grub.awk LIMIT=${LIMIT/ */} KNAME=${KNAME} ARCH=${ARCH} KV=${KV} TYPE=${TYPE} ${GRUB_CONF}.bak > ${GRUB_CONF}
		else
			print_info 1 "GRUB: Definition found, not duplicating."
		fi
	fi
}
