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
	mkdir -p ${TEMP}/initrd-temp/new_root
	mkdir -p ${TEMP}/initrd-temp/keymaps
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
	pivot_root ps awk pwd rm rmdir rmmod sh sleep tar test touch true umount uname \
	xargs yes zcat chmod chown cut kill killall; do
		rm -f ${TEMP}/initrd-temp/bin/$i > /dev/null
		ln  ${TEMP}/initrd-temp/bin/busybox ${TEMP}/initrd-temp/bin/$i || gen_die "could not link ${i}"
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
	for i in `gen_dep_list`
	do
		print_info 2 "$i : module searching" 1 0
		mymod=`find /lib/modules/${KV} -name "${i}${MOD_EXT}"`
		if [ -z "${mymod}" ]
		then
			print_info 2 "Warning : ${i}${MOD_EXT} not found; skipping..."
			continue;
		fi
		print_info 2 "copying ${mymod} to initrd"
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

	print_info 1 "initrd: creating base system"
	create_base_initrd_sys

	if [ "${NOINITRDMODULES}" = "" ]
	then
		print_info 1 "initrd: copying modules"
		create_initrd_modules
	else
		print_info 1 "initrd: not copying modules"
	fi

	print_info 1 "initrd: copying auxilary files"
	create_initrd_aux

	print_info 1 "initrd: calculating initrd size"
	INITRD_CALC_SIZE=`calc_initrd_size`

	print_info 1 "initrd: calculated size ${INITRD_CALC_SIZE} + 100k slop for fs overhead"
	INITRD_SIZE=`expr ${INITRD_CALC_SIZE} + 100`

	print_info 1 "initrd: real size ${INITRD_SIZE}"

	print_info 1 "initrd: creating loopback filesystem"
	create_initrd_loop ${INITRD_SIZE}

	print_info 1 "initrd: moving initrd fs to loopback"
	move_initrd_to_loop

	print_info 1 "initrd: cleaning up and compressing initrd"
	create_initrd_unmount_loop

	if [ "${COMPRESS_INITRD}" ]
	then
		gzip -f -9 ${TEMP}/initrd-loop
		mv ${TEMP}/initrd-loop.gz ${TEMP}/initrd-loop
	fi

	if [ "${BOOTSPLASH}" -eq "1" ]
	then
		print_info 1 "initrd: copying bootsplash"
		/sbin/splash -s -f /etc/bootsplash/gentoo/config/bootsplash-800x600.cfg >> ${TEMP}/initrd-loop || gen_die "could not copy 800x600 bootsplash"
		/sbin/splash -s -f /etc/bootsplash/gentoo/config/bootsplash-1024x768.cfg >> ${TEMP}/initrd-loop || gen_die "could not copy 1024x768 bootsplash"
		/sbin/splash -s -f /etc/bootsplash/gentoo/config/bootsplash-1280x1024.cfg >> ${TEMP}/initrd-loop || gen_die "could not copy 1280x1024 bootsplash"
		/sbin/splash -s -f /etc/bootsplash/gentoo/config/bootsplash-1600x1200.cfg >> ${TEMP}/initrd-loop || gen_die "could not copy 1600x1200 bootsplash"
	fi
	cp ${TEMP}/initrd-loop /boot/initrd-${KV} || gen_die "could not copy initrd to boot"
}

