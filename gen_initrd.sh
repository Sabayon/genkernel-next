#!/bin/bash

# create_initrd_loop(size)
create_initrd_loop() {
	local inodes
	[ "$#" -ne "1" ] && gen_die "invalid use of create_initrd_loop"
	mkdir -p ${TEMP}/initrd-mount || gen_die "could not create loopback mount dir"
	dd if=/dev/zero of=${TEMP}/initrd-loop bs=1k count=${1} >> "${DEBUGFILE}" 2>&1 || gen_die "could not zero initrd-loop"
	mke2fs -F -N500 -q "${TEMP}/initrd-loop" >> "${DEBUGFILE}" 2>&1 || gen_die "could not format initrd-loop"
	mount -t ext2 -o loop "${TEMP}/initrd-loop" "${TEMP}/initrd-mount" >> "${DEBUGFILE}" 2>&1 || gen_die "could not mount initrd filesystem"
}

create_initrd_unmount_loop()
{
	cd ${TEMP}
	umount "${TEMP}/initrd-mount" || gen_die "could not unmount initrd system"
}

move_initrd_to_loop()
{
	cd "${TEMP}/initrd-temp"
	mv * "${TEMP}/initrd-mount" >> ${DEBUGFILE} 2>&1
}

create_base_initrd_sys() {
	rm -rf "${TEMP}/initrd-temp" > /dev/null
	mkdir -p ${TEMP}/initrd-temp/dev
	mkdir -p ${TEMP}/initrd-temp/bin
	mkdir -p ${TEMP}/initrd-temp/etc
	mkdir -p ${TEMP}/initrd-temp/usr
	mkdir -p ${TEMP}/initrd-temp/proc
	mkdir -p ${TEMP}/initrd-temp/temp
	mkdir -p ${TEMP}/initrd-temp/.initrd
	ln -s bin ${TEMP}/initrd-temp/sbin
	ln -s ../bin ${TEMP}/initrd-temp/usr/bin
	ln -s ../bin ${TEMP}/initrd-temp/usr/sbin
	echo "/dev/ram0     /           ext2    defaults" > ${TEMP}/initrd-temp/etc/fstab
	echo "proc          /proc       proc    defaults    0 0" >> ${TEMP}/initrd-temp/etc/fstab

	echo "REGISTER        .*           MKOLDCOMPAT" > ${TEMP}/initrd-temp/etc/devfsd.conf
	echo "UNREGISTER      .*           RMOLDCOMPAT" >> ${TEMP}/initrd-temp/etc/devfsd.conf
	echo "REGISTER        .*           MKNEWCOMPAT" >> ${TEMP}/initrd-temp/etc/devfsd.conf
	echo "UNREGISTER      .*           RMNEWCOMPAT" >> ${TEMP}/initrd-temp/etc/devfsd.conf

	cd ${TEMP}/initrd-temp/dev
	MAKEDEV std
	MAKEDEV console

	cp "${BUSYBOX_BINCACHE}" "${TEMP}/initrd-temp/bin/busybox.bz2" || gen_die "could not copy busybox from bincache"
	bunzip2 "${TEMP}/initrd-temp/bin/busybox.bz2" || gen_die "could not uncompress busybox"
	chmod +x "${TEMP}/initrd-temp/bin/busybox"

	if [ "${NOINITRDMODULES}" = "" ]
	then
		if [ "${PAT}" -gt "4" ]
		then
			cp "${MODULE_INIT_TOOLS_BINCACHE}" "${TEMP}/initrd-temp/bin/insmod.static.bz2" || gen_die "could not copy insmod.static from bincache"
		else
			cp "${MODUTILS_BINCACHE}" "${TEMP}/initrd-temp/bin/insmod.static.bz2" || gen_die "could not copy insmod.static from bincache"
		fi

		bunzip2 "${TEMP}/initrd-temp/bin/insmod.static.bz2" || gen_die "could not uncompress insmod.static"
		mv "${TEMP}/initrd-temp/bin/insmod.static" "${TEMP}/initrd-temp/bin/insmod"
		chmod +x "${TEMP}/initrd-temp/bin/insmod"
	fi

	cp "${DEVFSD_BINCACHE}" "${TEMP}/initrd-temp/bin/devfsd.bz2" || gen_die "could not copy devfsd executable from bincache"
	bunzip2 "${TEMP}/initrd-temp/bin/devfsd.bz2" || gen_die "could not uncompress devfsd"
	chmod +x "${TEMP}/initrd-temp/bin/devfsd"

# We make our own devfsd.conf these days, the default one doesn't work with the stripped
# down devfsd we use with dietlibc
#	cp "${DEVFSD_CONF_BINCACHE}" "${TEMP}/initrd-temp/etc/devfsd.conf.bz2" || gen_die "could not copy devfsd.conf from bincache"
#	bunzip2 "${TEMP}/initrd-temp/etc/devfsd.conf.bz2" || gen_die "could not uncompress devfsd.conf"

	for i in '[' ash basename cat chroot clear cp dirname echo env false find \
	grep gunzip gzip ln ls loadkmap losetup lsmod mkdir mknod more mount mv \
	pivot_root ps awk pwd rm rmdir rmmod sed sh sleep tar test touch true umount uname \
	xargs yes zcat chmod chown cut kill killall; do
		rm -f ${TEMP}/initrd-temp/bin/$i > /dev/null
		ln  ${TEMP}/initrd-temp/bin/busybox ${TEMP}/initrd-temp/bin/$i || gen_die "Busybox error: could not link ${i}!"
	done
}

print_list()
{
	local x
	for x in ${*}
	do
		echo ${x}
	done
}

create_initrd_modules() {
	if [ "${PAT}" -gt "4" ]
	then
		MOD_EXT=".ko"
	else
		MOD_EXT=".o"
	fi

	print_info 2 "initrd: >> Searching for modules..."
	for i in `gen_dep_list`
	do
		mymod=`find /lib/modules/${KV} -name "${i}${MOD_EXT}"`
		if [ -z "${mymod}" ]
		then
			print_warning 2 "Warning :: ${i}${MOD_EXT} not found; skipping..."
			continue;
		fi
		print_info 2 "initrd: >> Copying ${i}${MOD_EXT}..."
		cp -ax --parents "${mymod}" "${TEMP}/initrd-temp"
	done

	cp -ax --parents /lib/modules/${KV}/modules* ${TEMP}/initrd-temp

	mkdir -p "${TEMP}/initrd-temp/etc/modules"
	print_list ${SCSI_MODULES} > "${TEMP}/initrd-temp/etc/modules/scsi"
	print_list ${FIREWIRE_MODULES} > "${TEMP}/initrd-temp/etc/modules/firewire"
	print_list ${ATARAID_MODULES} > "${TEMP}/initrd-temp/etc/modules/ataraid"
	print_list ${PCMCIA_MODULES} > "${TEMP}/initrd-temp/etc/modules/pcmcia"
	print_list ${USB_MODULES} > "${TEMP}/initrd-temp/etc/modules/usb"
}

create_initrd_aux() {
	if [ -f "${GK_SHARE}/${ARCH}/linuxrc" ]
	then
		cp "${GK_SHARE}/${ARCH}/linuxrc" "${TEMP}/initrd-temp/linuxrc"
	else
		cp "${GK_SHARE}/generic/linuxrc" "${TEMP}/initrd-temp/linuxrc"
	fi

	if [ -f "${GK_SHARE}/${ARCH}/initrd.scripts" ]
	then
		cp "${GK_SHARE}/${ARCH}/initrd.scripts" "${TEMP}/initrd-temp/etc/initrd.scripts"
	else	
		cp "${GK_SHARE}/generic/initrd.scripts" "${TEMP}/initrd-temp/etc/initrd.scripts"
	fi

	if [ -f "${GK_SHARE}/${ARCH}/initrd.defaults" ]
	then
		cp "${GK_SHARE}/${ARCH}/initrd.defaults" "${TEMP}/initrd-temp/etc/initrd.defaults"
	else
		cp "${GK_SHARE}/generic/initrd.defaults" "${TEMP}/initrd-temp/etc/initrd.defaults"
	fi
	if [ -f "${GK_SHARE}/${ARCH}/modprobe" ]
	then
		cp "${GK_SHARE}/${ARCH}/modprobe" "${TEMP}/initrd-temp/sbin/modprobe"
	else
		cp "${GK_SHARE}/generic/modprobe" "${TEMP}/initrd-temp/sbin/modprobe"
	fi
	if isTrue $CMD_DOKEYMAPAUTO
	then
		echo 'MY_HWOPTS="${MY_HWOPTS} keymap"' >> ${TEMP}/initrd-temp/etc/initrd.defaults
	fi
	mkdir -p "${TEMP}/initrd-temp/lib/keymaps"
	tar -C "${TEMP}/initrd-temp/lib/keymaps" -zxf "${GK_SHARE}/generic/keymaps.tar.gz"

	cd ${TEMP}/initrd-temp/sbin && ln -s ../linuxrc init
	cd ${OLDPWD}
	chmod +x "${TEMP}/initrd-temp/linuxrc"
	chmod +x "${TEMP}/initrd-temp/etc/initrd.scripts"
	chmod +x "${TEMP}/initrd-temp/etc/initrd.defaults"
	chmod +x "${TEMP}/initrd-temp/sbin/modprobe"
}

calc_initrd_size() {
	local TEST
	cd ${TEMP}/initrd-temp/
	TEST=`du -sk 2> /dev/null` 
	echo $TEST | cut "-d " -f1
}

create_initrd() {
	local MOD_EXT

	print_info 1 "initrd: >> Initializing..."
	create_base_initrd_sys

	if [ "${NOINITRDMODULES}" = "" ]
	then
		print_info 1 "        >> Copying modules..."
		create_initrd_modules
	else
		print_info 1 "initrd: Not copying modules..."
	fi

	print_info 1 "        >> Copying auxilary files..."
	create_initrd_aux

	INITRD_CALC_SIZE=`calc_initrd_size`
	INITRD_SIZE=`expr ${INITRD_CALC_SIZE} + 100`
	print_info 1 "        :: Size is at ${INITRD_SIZE}K"

	print_info 1 "        >> Creating loopback filesystem..."
	create_initrd_loop ${INITRD_SIZE}

	print_info 1 "        >> Moving initrd files to the loopback..."
	move_initrd_to_loop

	print_info 1 "        >> Cleaning up and compressing the initrd..."
	create_initrd_unmount_loop

	if [ "${COMPRESS_INITRD}" ]
	then
		gzip -f -9 ${TEMP}/initrd-loop
		mv ${TEMP}/initrd-loop.gz ${TEMP}/initrd-loop
	fi

	if [ "${BOOTSPLASH}" -eq "1" ]
	then
		if [ -x /sbin/splash ]
		then
			[ -z "${BOOTSPLASH_THEME}" ] && source /etc/conf.d/bootsplash.conf
			[ -z "${BOOTSPLASH_THEME}" ] && BOOTSPLASH_THEME=default
			print_info 1 "        >> Installing bootsplash [ using the ${BOOTSPLASH_THEME} theme ]..."
			for bootRes in '800x600' '1024x768' '1280x1024' '1600x1200'
			do
				if [ -f "/etc/bootsplash/${BOOTSPLASH_THEME}/config/bootsplash-${bootRes}.cfg" ]
				then
					/sbin/splash -s -f /etc/bootsplash/${BOOTSPLASH_THEME}/config/bootsplash-${bootRes}.cfg >> ${TEMP}/initrd-loop || gen_die "Error: could not copy ${bootRes} bootsplash!"
				else
					print_info 1 "splash: Did not find a bootplash for the ${bootRes} resolution..."
				fi
			done
		else
			print_warning 1 "      >> No bootsplash detected; skipping!"
		fi
	fi
	if ! isTrue "${CMD_NOINSTALL}"
	then
		cp ${TEMP}/initrd-loop /boot/initrd-${KV} || gen_die "Could not copy the initrd to /boot!"
	else
		mv ${TEMP}/initrd-loop ${TEMP}/initrd-${KV} || gen_die "Could not move the initrd to ${TEMP}/initrd-${KV}!"
	fi
}
