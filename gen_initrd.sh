#!/bin/bash

# create_initrd_loop(size)
create_initrd_loop() {
	local inodes
	[ "$#" -ne '1' ] && gen_die 'create_initrd_loop(): Not enough arguments!'
	mkdir -p ${TEMP}/initrd-mount ||
		gen_die 'Could not create loopback mount directory!'
	dd if=/dev/zero of=${TEMP}/initrd-${KV} bs=1k count=${1} >> "${DEBUGFILE}" 2>&1 ||
		gen_die "Could not zero initrd-${KV}"
	mke2fs -F -N500 -q "${TEMP}/initrd-${KV}" >> "${DEBUGFILE}" 2>&1 ||
		gen_die "Could not format initrd-${KV}!"
	mount -t ext2 -o loop "${TEMP}/initrd-${KV}" "${TEMP}/initrd-mount" >> "${DEBUGFILE}" 2>&1 ||
		gen_die 'Could not mount the initrd filesystem!'
}

create_initrd_unmount_loop()
{
	cd ${TEMP}
	umount "${TEMP}/initrd-mount" ||
		gen_die 'Could not unmount initrd system!'
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
	mkdir -p ${TEMP}/initrd-temp/sys
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

	cp "${BUSYBOX_BINCACHE}" "${TEMP}/initrd-temp/bin/busybox.bz2" ||
		gen_die 'Could not copy busybox from bincache!'
	bunzip2 "${TEMP}/initrd-temp/bin/busybox.bz2" ||
		gen_die 'Could not uncompress busybox!'
	chmod +x "${TEMP}/initrd-temp/bin/busybox"

	if [ "${NOINITRDMODULES}" = '' ]
	then
		if [ "${PAT}" -gt "4" ]
		then
			cp "${MODULE_INIT_TOOLS_BINCACHE}" "${TEMP}/initrd-temp/bin/insmod.static.bz2" ||
				gen_die 'Could not copy insmod.static from bincache!'
		else
			cp "${MODUTILS_BINCACHE}" "${TEMP}/initrd-temp/bin/insmod.static.bz2" ||
				gen_die 'Could not copy insmod.static from bincache'
		fi

		bunzip2 "${TEMP}/initrd-temp/bin/insmod.static.bz2" ||
			gen_die 'Could not uncompress insmod.static!'
		mv "${TEMP}/initrd-temp/bin/insmod.static" "${TEMP}/initrd-temp/bin/insmod"
		chmod +x "${TEMP}/initrd-temp/bin/insmod"
	fi

	cp "${DEVFSD_BINCACHE}" "${TEMP}/initrd-temp/bin/devfsd.bz2" || gen_die "could not copy devfsd executable from bincache"
	bunzip2 "${TEMP}/initrd-temp/bin/devfsd.bz2" || gen_die "could not uncompress devfsd"
	chmod +x "${TEMP}/initrd-temp/bin/devfsd"

	[ "${UDEV}" -eq '1' ] && { tar -jxpf "${UDEV_BINCACHE}" -C "${TEMP}/initrd-temp" ||
		gen_die "Could not extract udev binary cache!"; }
		ln -sf "./udev" "${TEMP}/initrd-temp/bin/udevstart" ||
			gen_die 'Could not symlink udev -> udevstart!'

# We make our own devfsd.conf these days, the default one doesn't work with the stripped
# down devfsd we use with dietlibc
#	cp "${DEVFSD_CONF_BINCACHE}" "${TEMP}/initrd-temp/etc/devfsd.conf.bz2" ||
#		gen_die "could not copy devfsd.conf from bincache"
#	bunzip2 "${TEMP}/initrd-temp/etc/devfsd.conf.bz2" ||
#		gen_die "could not uncompress devfsd.conf"

	# LVM2
	if [ "${CMD_LVM2}" -eq '1' ]
	then
		if [ -e '/sbin/lvm' ] && ldd /sbin/lvm|grep -q 'not a dynamic executable';
		then
			print_info 1 'LVM2: Adding support (using local static binaries)...'
			cp /sbin/lvm "${TEMP}/initrd-temp/bin/lvm" ||
				gen_die 'Could not copy over lvm!'
			ln -sf "${TEMP}/initrd-temp/bin/lvm" "${TEMP}/initrd-temp/bin/vgscan" ||
				gen_die 'Could not symlink lvm -> vgscan!'
			ln -sf "${TEMP}/initrd-temp/bin/lvm" "${TEMP}/initrd-temp/bin/vgchange" ||
				gen_die 'Could not symlink lvm -> vgchange!'
		else
			print_info 1 'LVM2: Adding support (compiling binaries)...'
			compile_lvm2

			tar -jxpf "${LVM2_BINCACHE}" -C "${TEMP}/initrd-temp" ||
				gen_die "Could not extract lvm2 binary cache!";
			mv ${TEMP}/initrd-temp/bin/lvm.static ${TEMP}/initrd-temp/bin/lvm ||
				gen_die 'LVM2 error: Could not move lvm.static to lvm!'
			for i in vgchange vgscan; do
				ln  ${TEMP}/initrd-temp/bin/lvm ${TEMP}/initrd-temp/bin/$i ||
					gen_die "LVM2 error: Could not link ${i}!"
			done
		fi	
	else # Deprecation warning; remove in a few versions.
		if [ -e '/sbin/lvm' ]
		then
			if ldd /sbin/lvm|grep -q 'not a dynamic executable';
			then
				print_warning 1 'LVM2: For support, use --lvm2!'
			fi
		fi
	fi
	
	# EVMS2
	if [ -e '/sbin/evms_activate' ]
	then
		if [ "${CMD_NOEVMS2}" -ne '1' ]
		then
			print_info 1 'EVMS2: Adding support...'	
			mkdir -p ${TEMP}/initrd-temp/lib
			cp -a /lib/ld-* "${TEMP}/initrd-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libc-* /lib/libc.* "${TEMP}/initrd-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libdl-* /lib/libdl.* "${TEMP}/initrd-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libpthread* "${TEMP}/initrd-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libuuid*so* "${TEMP}/initrd-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libevms*so* "${TEMP}/initrd-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/evms "${TEMP}/initrd-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/evms/* "${TEMP}/initrd-temp/lib/evms" || gen_die 'Could not copy files for EVMS2!'
			cp -a /etc/evms.conf "${TEMP}/initrd-temp/etc" || gen_die 'Could not copy files for EVMS2!'
			cp /sbin/evms_activate "${TEMP}/initrd-temp/bin/evms_activate" || gen_die 'Could not copy over vgscan!'
		fi
	fi	

	for i in '[' ash basename cat chroot clear cp dirname echo env false find \
	grep gunzip gzip ln ls loadkmap losetup lsmod mkdir mknod more mount mv \
	pivot_root ps awk pwd rm rmdir rmmod sed sh sleep tar test touch true umount uname \
	xargs yes zcat chmod chown cut kill killall; do
		rm -f ${TEMP}/initrd-temp/bin/$i > /dev/null
		ln  ${TEMP}/initrd-temp/bin/busybox ${TEMP}/initrd-temp/bin/$i ||
			gen_die "Busybox error: could not link ${i}!"
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
	local group
	local group_modules
	
	if [ "${PAT}" -gt "4" ]
	then
		MOD_EXT=".ko"
	else
		MOD_EXT=".o"
	fi

	print_info 2 "initrd: >> Searching for modules..."
	if [ "${INSTALL_MOD_PATH}" != '' ]
	then
	  cd ${INSTALL_MOD_PATH}
	else
	  cd /
	fi
	for i in `gen_dep_list`
	do
		mymod=`find ./lib/modules/${KV} -name "${i}${MOD_EXT}" | head -n 1`
		if [ -z "${mymod}" ]
		then
			print_warning 2 "Warning :: ${i}${MOD_EXT} not found; skipping..."
			continue;
		fi
		print_info 2 "initrd: >> Copying ${i}${MOD_EXT}..."
		cp -ax --parents "${mymod}" "${TEMP}/initrd-temp"
	done

	cp -ax --parents ./lib/modules/${KV}/modules* ${TEMP}/initrd-temp

	mkdir -p "${TEMP}/initrd-temp/etc/modules"
	for group_modules in ${!MODULES_*}; do
		group="$(echo $group_modules | cut -d_ -f2 | tr "[:upper:]" "[:lower:]")"
		print_list ${!group_modules} > "${TEMP}/initrd-temp/etc/modules/${group}"
	done
}

create_initrd_aux() {
	if [ -f "${CMD_LINUXRC}" ]
	then
		cp "${CMD_LINUXRC}" "${TEMP}/initrd-temp/linuxrc"
		print_info 2 "        >> Copying user specified linuxrc: ${CMD_LINUXRC}"
	else	
		if [ -f "${GK_SHARE}/${ARCH}/linuxrc" ]
		then
			cp "${GK_SHARE}/${ARCH}/linuxrc" "${TEMP}/initrd-temp/linuxrc"
		else
			cp "${GK_SHARE}/generic/linuxrc" "${TEMP}/initrd-temp/linuxrc"
		fi
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
	
	echo -n 'HWOPTS="$HWOPTS ' >> "${TEMP}/initrd-temp/etc/initrd.defaults"	
	for group_modules in ${!MODULES_*}; do
		group="$(echo $group_modules | cut -d_ -f2 | tr "[:upper:]" "[:lower:]")"
		echo -n "${group} " >> "${TEMP}/initrd-temp/etc/initrd.defaults"
	done
	echo '"' >> "${TEMP}/initrd-temp/etc/initrd.defaults"	

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

	if [ "${NOINITRDMODULES}" = '' ]
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
		gzip -f -9 ${TEMP}/initrd-${KV}
		mv ${TEMP}/initrd-${KV}.gz ${TEMP}/initrd-${KV}
	fi

	if [ "${BOOTSPLASH}" -eq "1" ]
	then
		if [ -x /sbin/splash ]
		then
			[ -z "${BOOTSPLASH_THEME}" ] && [ -e /etc/conf.d/bootsplash.conf ] && source /etc/conf.d/bootsplash.conf
			[ -z "${BOOTSPLASH_THEME}" ] && [ -e /etc/conf.d/bootsplash ] && source /etc/conf.d/bootsplash
			[ -z "${BOOTSPLASH_THEME}" ] && BOOTSPLASH_THEME=default
			print_info 1 "        >> Installing bootsplash [ using the ${BOOTSPLASH_THEME} theme ]..."
			for bootRes in '800x600' '1024x768' '1280x1024' '1600x1200'
			do
				if [ -f "/etc/bootsplash/${BOOTSPLASH_THEME}/config/bootsplash-${bootRes}.cfg" ]
				then
					/sbin/splash -s -f /etc/bootsplash/${BOOTSPLASH_THEME}/config/bootsplash-${bootRes}.cfg >> ${TEMP}/initrd-${KV} ||
						gen_die "Error: could not copy ${bootRes} bootsplash!"
				else
					print_warning 1 "splash: Did not find a bootsplash for the ${bootRes} resolution..."
				fi
			done
		else
			print_warning 1 '        >> No bootsplash detected; skipping!'
		fi
	fi
	if ! isTrue "${CMD_NOINSTALL}"
	then
		cp ${TEMP}/initrd-${KV} /boot/initrd-${KV} ||
			gen_die 'Could not copy the initrd to /boot!'
	fi
}
