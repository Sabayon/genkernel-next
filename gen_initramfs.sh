#!/bin/bash

CPIO_ARGS="--quiet -o -H newc"

append_base_layout() {
	if [ -d "${TEMP}/initramfs-base-temp" ]
	then
		rm -rf "${TEMP}/initramfs-base-temp" > /dev/null
	fi
	mkdir -p ${TEMP}/initramfs-base-temp/dev
	mkdir -p ${TEMP}/initramfs-base-temp/bin
	mkdir -p ${TEMP}/initramfs-base-temp/etc
	mkdir -p ${TEMP}/initramfs-base-temp/usr
	mkdir -p ${TEMP}/initramfs-base-temp/proc
	mkdir -p ${TEMP}/initramfs-base-temp/temp
	mkdir -p ${TEMP}/initramfs-base-temp/sys
	mkdir -p ${TEMP}/initramfs-temp/.initrd
	mkdir -p ${TEMP}/initramfs-base-temp/var/lock/dmraid
	mkdir -p ${TEMP}/initramfs-base-temp/sbin
	mkdir -p ${TEMP}/initramfs-base-temp/usr/bin
	mkdir -p ${TEMP}/initramfs-base-temp/usr/sbin
	ln -s  lib  ${TEMP}/initramfs-base-temp/lib64

	echo "/dev/ram0     /           ext2    defaults	0 0" > ${TEMP}/initramfs-base-temp/etc/fstab
	echo "proc          /proc       proc    defaults    0 0" >> ${TEMP}/initramfs-base-temp/etc/fstab
	
	if [ "${DEVFS}" -eq '1' ]
	then
	    echo "REGISTER        .*           MKOLDCOMPAT" > ${TEMP}/initramfs-base-temp/etc/devfsd.conf
	    echo "UNREGISTER      .*           RMOLDCOMPAT" >> ${TEMP}/initramfs-base-temp/etc/devfsd.conf
	    echo "REGISTER        .*           MKNEWCOMPAT" >> ${TEMP}/initramfs-base-temp/etc/devfsd.conf
	    echo "UNREGISTER      .*           RMNEWCOMPAT" >> ${TEMP}/initramfs-base-temp/etc/devfsd.conf
	fi

	cd ${TEMP}/initramfs-base-temp/dev
	mknod -m 660 console c 5 1
	mknod -m 660 null c 1 3
	mknod -m 600 tty1 c 4 1
	cd "${TEMP}/initramfs-base-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -rf "${TEMP}/initramfs-base-temp" > /dev/null
}

append_busybox() {
	if [ -d "${TEMP}/initramfs-busybox-temp" ]
	then
		rm -rf "${TEMP}/initramfs-busybox-temp" > /dev/null
	fi
	mkdir -p "${TEMP}/initramfs-busybox-temp/bin/" 

	cp "${GK_SHARE}/generic/udhcpc.scripts" ${TEMP}/initramfs-busybox-temp/bin/
	chmod +x "${TEMP}/initramfs-busybox-temp/bin/udhcpc.scripts"
	cp "${BUSYBOX_BINCACHE}" "${TEMP}/initramfs-busybox-temp/bin/busybox.bz2" ||
		gen_die 'Could not copy busybox from bincache!'
	bunzip2 "${TEMP}/initramfs-busybox-temp/bin/busybox.bz2" ||
		gen_die 'Could not uncompress busybox!'
	chmod +x "${TEMP}/initramfs-busybox-temp/bin/busybox"

	# down devfsd we use with dietlibc
#	cp "${DEVFSD_CONF_BINCACHE}" "${TEMP}/initramfs-temp/etc/devfsd.conf.bz2" ||
#		gen_die "could not copy devfsd.conf from bincache"
#	bunzip2 "${TEMP}/initramfs-temp/etc/devfsd.conf.bz2" ||
#		gen_die "could not uncompress devfsd.conf"
	for i in '[' ash sh mount uname echo cut; do
		rm -f ${TEMP}/initramfs-busybox-temp/bin/$i > /dev/null
		ln ${TEMP}/initramfs-busybox-temp/bin/busybox ${TEMP}/initramfs-busybox-temp/bin/$i ||
			gen_die "Busybox error: could not link ${i}!"
	done
	
	cd "${TEMP}/initramfs-busybox-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -rf "${TEMP}/initramfs-busybox-temp" > /dev/null
}

append_insmod() {
	if [ -d "${TEMP}/initramfs-insmod-temp" ]
	then
		rm -rf "${TEMP}/initramfs-insmod-temp" > /dev/null
	fi
	mkdir -p "${TEMP}/initramfs-insmod-temp/bin/" 
	cp "${MODULE_INIT_TOOLS_BINCACHE}" "${TEMP}/initramfs-insmod-temp/bin/insmod.static.bz2" ||
		gen_die 'Could not copy insmod.static from bincache!'

	bunzip2 "${TEMP}/initramfs-insmod-temp/bin/insmod.static.bz2" ||
		gen_die 'Could not uncompress insmod.static!'
	mv "${TEMP}/initramfs-insmod-temp/bin/insmod.static" "${TEMP}/initramfs-insmod-temp/bin/insmod"
	chmod +x "${TEMP}/initramfs-insmod-temp/bin/insmod"
	
	cd "${TEMP}/initramfs-insmod-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -rf "${TEMP}/initramfs-insmod-temp" > /dev/null
}

append_udev(){
	if [ -d "${TEMP}/initramfs-udev-temp" ]
	then
		rm -r "${TEMP}/initramfs-udev-temp/"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-udev-temp/bin/"
	[ "${UDEV}" -eq '1' ] && { /bin/tar -jxpf "${UDEV_BINCACHE}" -C "${TEMP}/initramfs-udev-temp" ||
		gen_die "Could not extract udev binary cache!"; }
	cd "${TEMP}/initramfs-udev-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -rf "${TEMP}/initramfs-udev-temp" > /dev/null
}

append_blkid(){
	if [ -d "${TEMP}/initramfs-blkid-temp" ]
	then
		rm -r "${TEMP}/initramfs-blkid-temp/"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-blkid-temp/bin/"
	[ "${DISKLABEL}" -eq '1' ] && { /bin/bzip2 -dc "${BLKID_BINCACHE}" > "${TEMP}/initramfs-blkid-temp/bin/blkid" ||
		gen_die "Could not extract blkid binary cache!"; }
	chmod a+x "${TEMP}/initramfs-blkid-temp/bin/blkid"
	cd "${TEMP}/initramfs-blkid-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -rf "${TEMP}/initramfs-blkid-temp" > /dev/null
}

append_devfs(){
	if [ -d "${TEMP}/initramfs-devfs-temp" ]
	then
		rm -r "${TEMP}/initramfs-devfs-temp/"
	fi
	cd ${TEMP}
	print_info 1 'DEVFS: Adding support (compiling binaries)...'
	compile_devfsd
	mkdir -p "${TEMP}/initramfs-devfs-temp/bin/"
	cp "${DEVFSD_BINCACHE}" "${TEMP}/initramfs-devfs-temp/bin/devfsd.bz2" || gen_die "could not copy devfsd executable from bincache"
	bunzip2 "${TEMP}/initramfs-devfs-temp/bin/devfsd.bz2" || gen_die "could not uncompress devfsd"
	chmod +x "${TEMP}/initramfs-devfs-temp/bin/devfsd"
	cd "${TEMP}/initramfs-devfs-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -rf "${TEMP}/initramfs-devfs-temp" > /dev/null
}

append_unionfs_modules(){
	if [ -d "${TEMP}/initramfs-unionfs-modules-temp" ]
	then
		rm -r "${TEMP}/initramfs-unionfs-modules-temp/"
	fi
	print_info 1 'UNIONFS MODULES: Adding support (compiling)...'
	compile_unionfs_modules
	mkdir -p "${TEMP}/initramfs-unionfs-modules-temp/"
	/bin/tar -jxpf "${UNIONFS_MODULES_BINCACHE}" -C "${TEMP}/initramfs-unionfs-modules-temp" ||
		gen_die "Could not extract unionfs modules binary cache!";
	cd "${TEMP}/initramfs-unionfs-modules-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -r "${TEMP}/initramfs-unionfs-modules-temp/"
}

append_unionfs_tools(){
	if [ -d "${TEMP}/initramfs-unionfs-tools-temp" ]
	then
		rm -r "${TEMP}/initramfs-unionfs-tools-temp/"
	fi
	print_info 1 'UNIONFS TOOLS: Adding support (compiling)...'
	compile_unionfs_utils
	mkdir -p "${TEMP}/initramfs-unionfs-tools-temp/bin/"
	/bin/tar -jxpf "${UNIONFS_BINCACHE}" -C "${TEMP}/initramfs-unionfs-tools-temp" ||
		gen_die "Could not extract unionfs tools binary cache!";
	cd "${TEMP}/initramfs-unionfs-tools-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -r "${TEMP}/initramfs-unionfs-tools-temp/"
}

append_suspend(){
	if [ -d "${TEMP}/initramfs-suspend-temp" ];
	then
		rm -r "${TEMP}/initramfs-suspend-temp/"
	fi
	print_info 1 'SUSPEND: Adding support (compiling binaries)...'
	compile_suspend
	mkdir -p "${TEMP}/initramfs-suspend-temp/"
	/bin/tar -jxpf "${SUSPEND_BINCACHE}" -C "${TEMP}/initramfs-suspend-temp" ||
		gen_die "Could not extract suspend binary cache!"
	mkdir -p "${TEMP}/initramfs-suspend-temp/etc"
	cp -f /etc/suspend.conf "${TEMP}/initramfs-suspend-temp/etc" ||
		gen_die 'Could not copy /etc/suspend.conf'
	cd "${TEMP}/initramfs-suspend-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -r "${TEMP}/initramfs-suspend-temp/"
}

append_dmraid(){
	if [ -d "${TEMP}/initramfs-dmraid-temp" ]
	then
		rm -r "${TEMP}/initramfs-dmraid-temp/"
	fi
	print_info 1 'DMRAID: Adding support (compiling binaries)...'
	compile_dmraid
	mkdir -p "${TEMP}/initramfs-dmraid-temp/"
	/bin/tar -jxpf "${DMRAID_BINCACHE}" -C "${TEMP}/initramfs-dmraid-temp" ||
		gen_die "Could not extract dmraid binary cache!";
	cd "${TEMP}/initramfs-dmraid-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -r "${TEMP}/initramfs-dmraid-temp/"
}

append_lvm2(){
	if [ -d "${TEMP}/initramfs-lvm2-temp" ]
	then
		rm -r "${TEMP}/initramfs-lvm2-temp/"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-lvm2-temp/bin/"
	mkdir -p "${TEMP}/initramfs-lvm2-temp/etc/lvm/"
	if [ -e '/sbin/lvm' ] && ldd /sbin/lvm|grep -q 'not a dynamic executable';
	then
		print_info 1 '		LVM2: Adding support (using local static binaries)...'
		cp /sbin/lvm "${TEMP}/initramfs-lvm2-temp/bin/lvm" ||
			gen_die 'Could not copy over lvm!'
	else
		print_info 1 '		LVM2: Adding support (compiling binaries)...'
		compile_lvm2
		/bin/tar -jxpf "${LVM2_BINCACHE}" -C "${TEMP}/initramfs-lvm2-temp" ||
			gen_die "Could not extract lvm2 binary cache!";
		mv ${TEMP}/initramfs-lvm2-temp/sbin/lvm.static ${TEMP}/initramfs-lvm2-temp/bin/lvm ||
			gen_die 'LVM2 error: Could not move lvm.static to lvm!'
	fi
	cp /etc/lvm/lvm.conf "${TEMP}/initramfs-lvm2-temp/etc/lvm/lvm.conf" ||
		gen_die 'Could not copy over lvm.conf!'
	cd "${TEMP}/initramfs-lvm2-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -r "${TEMP}/initramfs-lvm2-temp/"
}

append_evms2(){
	if [ -d "${TEMP}/initramfs-evms2-temp" ]
	then
		rm -r "${TEMP}/initramfs-evms2-temp/"
	fi
	mkdir -p "${TEMP}/initramfs-evms2-temp/lib/evms"
	mkdir -p "${TEMP}/initramfs-evms2-temp/etc/"
	mkdir -p "${TEMP}/initramfs-evms2-temp/bin/"
	mkdir -p "${TEMP}/initramfs-evms2-temp/sbin/"
	if [ "${EVMS2}" -eq '1' ]
	then
		print_info 1 '		EVMS2: Adding support...'
		mkdir -p ${TEMP}/initramfs-evms2-temp/lib
		cp -a /lib/ld-* "${TEMP}/initramfs-evms2-temp/lib" \
			|| gen_die 'Could not copy files for EVMS2!'
		if [ -n "`ls /lib/libgcc_s*`" ]
		then
			cp -a /lib/libgcc_s* "${TEMP}/initramfs-evms2-temp/lib" \
				|| gen_die 'Could not copy files for EVMS2!'
		fi
		cp -a /lib/libc-* /lib/libc.* "${TEMP}/initramfs-evms2-temp/lib" \
			|| gen_die 'Could not copy files for EVMS2!'
		cp -a /lib/libdl-* /lib/libdl.* "${TEMP}/initramfs-evms2-temp/lib" \
			|| gen_die 'Could not copy files for EVMS2!'
		cp -a /lib/libpthread* "${TEMP}/initramfs-evms2-temp/lib" \
			|| gen_die 'Could not copy files for EVMS2!'
		cp -a /lib/libuuid*so* "${TEMP}/initramfs-evms2-temp/lib" \
			|| gen_die 'Could not copy files for EVMS2!'
		cp -a /lib/libevms*so* "${TEMP}/initramfs-evms2-temp/lib" \
			|| gen_die 'Could not copy files for EVMS2!'
		cp -a /lib/evms "${TEMP}/initramfs-evms2-temp/lib" \
			|| gen_die 'Could not copy files for EVMS2!'
		cp -a /lib/evms/* "${TEMP}/initramfs-evms2-temp/lib/evms" \
			|| gen_die 'Could not copy files for EVMS2!'
		cp -a /etc/evms.conf "${TEMP}/initramfs-evms2-temp/etc" \
			|| gen_die 'Could not copy files for EVMS2!'
		cp /sbin/evms_activate "${TEMP}/initramfs-evms2-temp/sbin" \
			|| gen_die 'Could not copy over evms_activate!'

		# Fix EVMS2 complaining that it can't find the swap utilities.
		# These are not required in the initramfs
		for swap_libs in "${TEMP}/initramfs-evms2-temp/lib/evms/*/swap*.so"
		do
			rm ${swap_libs}
		done
	fi
	cd "${TEMP}/initramfs-evms2-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -r "${TEMP}/initramfs-evms2-temp/"
}

append_gensplash(){
	if [ -x /usr/bin/splash_geninitramfs ] || [ -x /sbin/splash_geninitramfs ]
	then
		[ -z "${GENSPLASH_THEME}" ] && [ -e /etc/conf.d/splash ] && source /etc/conf.d/splash
		[ -z "${GENSPLASH_THEME}" ] && GENSPLASH_THEME=default
		print_info 1 "  >> Installing gensplash [ using the ${GENSPLASH_THEME} theme ]..."
		if [ -d "${TEMP}/initramfs-gensplash-temp" ]
		then
			rm -r "${TEMP}/initramfs-gensplash-temp/"
		fi
		mkdir -p "${TEMP}/initramfs-gensplash-temp"
		cd /
		local tmp=""
		[ -n "${GENSPLASH_RES}" ] && tmp="-r ${GENSPLASH_RES}"
		splash_geninitramfs -c "${TEMP}/initramfs-gensplash-temp" ${tmp} ${GENSPLASH_THEME} || gen_die "Could not build splash cpio archive"
		if [ -e "/usr/share/splashutils/initrd.splash" ]; then
			mkdir -p "${TEMP}/initramfs-gensplash-temp/etc"
			cp -f "/usr/share/splashutils/initrd.splash" "${TEMP}/initramfs-gensplash-temp/etc"
		fi
		cd "${TEMP}/initramfs-gensplash-temp/"
		find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing splash cpio"
		rm -r "${TEMP}/initramfs-gensplash-temp/"
	else
		print_warning 1 '               >> No splash detected; skipping!'
	fi
}

append_overlay(){
	cd ${INITRAMFS_OVERLAY}
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
}
print_list()
{
	local x
	for x in ${*}
	do
		echo ${x}
	done
}

append_modules() {
	local group
	local group_modules
	local MOD_EXT=".ko"

	print_info 2 "initramfs: >> Searching for modules..."
	if [ "${INSTALL_MOD_PATH}" != '' ]
	then
	  cd ${INSTALL_MOD_PATH}
	else
	  cd /
	fi
	
	if [ -d "${TEMP}/initramfs-modules-${KV}-temp" ]
	then
		rm -r "${TEMP}/initramfs-modules-${KV}-temp/"
	fi
	mkdir -p "${TEMP}/initramfs-modules-${KV}-temp/lib/modules/${KV}"	
	for i in `gen_dep_list`
	do
		mymod=`find ./lib/modules/${KV} -name "${i}${MOD_EXT}" 2>/dev/null| head -n 1 `
		if [ -z "${mymod}" ]
		then
			print_warning 2 "Warning :: ${i}${MOD_EXT} not found; skipping..."
			continue;
		fi
		
		print_info 2 "initramfs: >> Copying ${i}${MOD_EXT}..."
		cp -ax --parents "${mymod}" "${TEMP}/initramfs-modules-${KV}-temp"
	done
	
	cp -ax --parents ./lib/modules/${KV}/modules* ${TEMP}/initramfs-modules-${KV}-temp 2>/dev/null

	mkdir -p "${TEMP}/initramfs-modules-${KV}-temp/etc/modules"
	for group_modules in ${!MODULES_*}; do
		group="$(echo $group_modules | cut -d_ -f2 | tr "[:upper:]" "[:lower:]")"
		print_list ${!group_modules} > "${TEMP}/initramfs-modules-${KV}-temp/etc/modules/${group}"
	done
	cd "${TEMP}/initramfs-modules-${KV}-temp/"
	find . | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -r "${TEMP}/initramfs-modules-${KV}-temp/"	
}

# check for static linked file with objdump
is_static() {
	objdump -T $1 2>&1 | grep "not a dynamic object" > /dev/null
	return $?
}

append_auxilary() {
	if [ -d "${TEMP}/initramfs-aux-temp" ]
	then
		rm -r "${TEMP}/initramfs-aux-temp/"
	fi
	mkdir -p "${TEMP}/initramfs-aux-temp/etc"	
	mkdir -p "${TEMP}/initramfs-aux-temp/sbin"	
	if [ -f "${CMD_LINUXRC}" ]
	then
		cp "${CMD_LINUXRC}" "${TEMP}/initramfs-aux-temp/init"
		print_info 2 "        >> Copying user specified linuxrc: ${CMD_LINUXRC} to init"
	else	
		if [ -f "${GK_SHARE}/${ARCH}/linuxrc" ]
		then
			cp "${GK_SHARE}/${ARCH}/linuxrc" "${TEMP}/initramfs-aux-temp/init"
		else
			cp "${GK_SHARE}/generic/linuxrc" "${TEMP}/initramfs-aux-temp/init"
		fi
	fi

	# Make sure it's executable
	chmod 0755 "${TEMP}/initramfs-aux-temp/init"

	# Make a symlink to init .. incase we are bundled inside the kernel as one
	# big cpio.
	cd ${TEMP}/initramfs-aux-temp
	ln -s init linuxrc
#	ln ${TEMP}/initramfs-aux-temp/init ${TEMP}/initramfs-aux-temp/linuxrc 

	if [ -f "${GK_SHARE}/${ARCH}/initrd.scripts" ]
	then
		cp "${GK_SHARE}/${ARCH}/initrd.scripts" "${TEMP}/initramfs-aux-temp/etc/initrd.scripts"
	else	
		cp "${GK_SHARE}/generic/initrd.scripts" "${TEMP}/initramfs-aux-temp/etc/initrd.scripts"
	fi

	if [ -f "${GK_SHARE}/${ARCH}/initrd.defaults" ]
	then
		cp "${GK_SHARE}/${ARCH}/initrd.defaults" "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	else
		cp "${GK_SHARE}/generic/initrd.defaults" "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	fi
	
	echo -n 'HWOPTS="$HWOPTS ' >> "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"	
	for group_modules in ${!MODULES_*}; do
		group="$(echo $group_modules | cut -d_ -f2 | tr "[:upper:]" "[:lower:]")"
		echo -n "${group} " >> "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	done
	echo '"' >> "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"	

	if [ -f "${GK_SHARE}/${ARCH}/modprobe" ]
	then
		cp "${GK_SHARE}/${ARCH}/modprobe" "${TEMP}/initramfs-aux-temp/sbin/modprobe"
	else
		cp "${GK_SHARE}/generic/modprobe" "${TEMP}/initramfs-aux-temp/sbin/modprobe"
	fi
	if isTrue $CMD_DOKEYMAPAUTO
	then
		echo 'MY_HWOPTS="${MY_HWOPTS} keymap"' >> ${TEMP}/initramfs-aux-temp/etc/initrd.defaults
	fi
	mkdir -p "${TEMP}/initramfs-aux-temp/lib/keymaps"
	/bin/tar -C "${TEMP}/initramfs-aux-temp/lib/keymaps" -zxf "${GK_SHARE}/generic/keymaps.tar.gz"
	if isTrue $CMD_SLOWUSB
	then
		echo 'MY_HWOPTS="${MY_HWOPTS} slowusb"' >> ${TEMP}/initramfs-aux-temp/etc/initrd.defaults
	fi
	if isTrue ${LUKS}
	then
		if is_static /bin/cryptsetup
		then
			print_info 1 "Including LUKS support"
			rm -f ${TEMP}/initramfs-aux-temp/sbin/cryptsetup
			cp /bin/cryptsetup ${TEMP}/initramfs-aux-temp/sbin/cryptsetup
			chmod +x "${TEMP}/initramfs-aux-temp/sbin/cryptsetup"
		else
			print_info 1 "LUKS support requires static cryptsetup at /bin/cryptsetup"
			print_info 1 "Not including LUKS support"
		fi
	fi

	cd ${TEMP}/initramfs-aux-temp/sbin && ln -s ../init init
	cd ${TEMP}
	chmod +x "${TEMP}/initramfs-aux-temp/init"
	chmod +x "${TEMP}/initramfs-aux-temp/etc/initrd.scripts"
	chmod +x "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	chmod +x "${TEMP}/initramfs-aux-temp/sbin/modprobe"
	cd "${TEMP}/initramfs-aux-temp/"
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -r "${TEMP}/initramfs-aux-temp/"	
}

append_data() {
	local name=$1 var=$2
	local func="append_${name}"

	if [ $# -eq '1' ] || [ "${var}" -eq '1' ]
	then
	    print_info 1 "        >> Appending ${name} cpio data..."
	    ${func}
	fi
}

create_initramfs() {
	print_info 1 "initramfs: >> Initializing..."

	# Create empty cpio
	CPIO="${TMPDIR}/initramfs-${KV}"
	echo | cpio ${CPIO_ARGS} -F "${CPIO}" 2>/dev/null \
		|| gen_die "Could not create empty cpio at ${CPIO}"

	append_data 'base_layout'
	append_data 'auxilary'
	append_data 'busybox' "${BUSYBOX}"
	append_data 'devfs' "${DEVFS}"
#	append_data 'udev' "${UDEV}"
	append_data 'unionfs_modules' "${UNIONFS}"
	append_data 'unionfs_tools' "${UNIONFS}"
	append_data 'suspend' "${SUSPEND}"
	append_data 'lvm2' "${LVM2}"
	append_data 'dmraid' "${DMRAID}"
	append_data 'evms2' "${EVMS2}"
	
	if [ "${NOINITRDMODULES}" = '' ]
	then
		append_data 'insmod'
		append_data 'modules'
	else
		print_info 1 "initramfs: Not copying modules..."
	fi

	append_data 'blkid' "${DISKLABEL}"
	append_data 'gensplash' "${GENSPLASH}"

	# This should always be appended last
	if [ "${INITRAMFS_OVERLAY}" != '' ]
	then
		append_data 'overlay'
	fi

	gzip -9 "${CPIO}"
	mv -f "${CPIO}.gz" "${CPIO}"

	# Pegasos hack for merging the initramfs into the kernel at compile time
	[ "${KERNEL_MAKE_DIRECTIVE}" == 'zImage.initrd' -a "${GENERATE_Z_IMAGE}" = '1' ] ||
		[ "${KERNEL_MAKE_DIRECTIVE_2}" == 'zImage.initrd' -a "${GENERATE_Z_IMAGE}" = '1' ] &&
			cp ${TMPDIR}/initramfs-${KV} ${KERNEL_DIR}/arch/powerpc/boot/ramdisk.image.gz &&
			rm ${TMPDIR}/initramfs-${KV}

	# Mips also mimics Pegasos to merge the initramfs into the kernel
	if [ ${BUILD_INITRAMFS} -eq 1 ]; then
		cp ${TMPDIR}/initramfs-${KV} ${KERNEL_DIR}/initramfs.cpio.gz
		gunzip -f ${KERNEL_DIR}/initramfs.cpio.gz
	fi

	if ! isTrue "${CMD_NOINSTALL}"
	then
		if [ "${GENERATE_Z_IMAGE}" != '1' ]
		then
			copy_image_with_preserve "initramfs" \
				"${TMPDIR}/initramfs-${KV}" \
				"initramfs-${KNAME}-${ARCH}-${KV}"
		fi
	fi
}
