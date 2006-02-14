#!/bin/bash

create_base_layout_cpio() {
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
	ln -s  ../lib  ${TEMP}/initramfs-base-temp/lib64

	echo "/dev/ram0     /           ext2    defaults	0 0" > ${TEMP}/initramfs-base-temp/etc/fstab
	echo "proc          /proc       proc    defaults    0 0" >> ${TEMP}/initramfs-base-temp/etc/fstab
	
	if [ "${DEVFS}" -eq '1' ]
	then
	    echo "REGISTER        .*           MKOLDCOMPAT" > ${TEMP}/initramfs-base-temp/etc/devfsd.conf
	    echo "UNREGISTER      .*           RMOLDCOMPAT" >> ${TEMP}/initramfs-base-temp/etc/devfsd.conf
	    echo "REGISTER        .*           MKNEWCOMPAT" >> ${TEMP}/initramfs-base-temp/etc/devfsd.conf
	    echo "UNREGISTER      .*           RMNEWCOMPAT" >> ${TEMP}/initramfs-base-temp/etc/devfsd.conf
	fi

	# SGI LiveCDs need the following binary (no better place for it than here)
	# getdvhoff is a DEPEND of genkernel, so it *should* exist
	if [ ${BUILD_INITRAMFS} -eq 1 -a "${MIPS_LIVECD}" != '' ]
	then
		[ -e /usr/lib/getdvhoff/getdvhoff ] \
			&& cp /usr/lib/getdvhoff/getdvhoff ${TEMP}/initramfs-base-temp/bin \
			|| gen_die "sys-boot/getdvhoff not merged!"
	fi

	cd ${TEMP}/initramfs-base-temp/dev
	mknod -m 660 console c 5 1
	mknod -m 660 null c 1 3
	mknod -m 600 tty1 c 4 1
	cd "${TEMP}/initramfs-base-temp/"
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-base-layout.cpio.gz
	rm -rf "${TEMP}/initramfs-base-temp" > /dev/null
}

create_busybox_cpio() {
	if [ -d "${TEMP}/initramfs-busybox-temp" ]
	then
		rm -rf "${TEMP}/initramfs-busybox-temp" > /dev/null
	fi
	mkdir -p "${TEMP}/initramfs-busybox-temp/bin/" 
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
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-busybox-${BUSYBOX_VER}.cpio.gz
	rm -rf "${TEMP}/initramfs-busybox-temp" > /dev/null
}

create_insmod_cpio() {
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
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-insmod-${MODULE_INIT_TOOLS_VER}.cpio.gz
	rm -rf "${TEMP}/initramfs-insmod-temp" > /dev/null
}

create_udev_cpio(){
	if [ -d "${TEMP}/initramfs-udev-temp" ]
	then
		rm -r "${TEMP}/initramfs-udev-temp/"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-udev-temp/bin/"
	[ "${UDEV}" -eq '1' ] && { /bin/tar -jxpf "${UDEV_BINCACHE}" -C "${TEMP}/initramfs-udev-temp" ||
		gen_die "Could not extract udev binary cache!"; }
	cd "${TEMP}/initramfs-udev-temp/"
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-udev-${UDEV_VER}.cpio.gz
	rm -rf "${TEMP}/initramfs-udev-temp" > /dev/null
}

create_blkid_cpio(){
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
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-blkid-${E2FSPROGS_VER}.cpio.gz
	rm -rf "${TEMP}/initramfs-blkid-temp" > /dev/null
}

create_devfs_cpio(){
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
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-devfs-${DEVFSD_VER}.cpio.gz
	rm -rf "${TEMP}/initramfs-devfs-temp" > /dev/null
}

create_unionfs_modules_cpio(){
	#UNIONFS Modules
	if [ "${UNIONFS}" -eq '1' ]
	then
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
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-unionfs-${UNIONFS_VER}-modules-${KV}.cpio.gz
	rm -r "${TEMP}/initramfs-unionfs-modules-temp/"
	fi
}

create_unionfs_tools_cpio(){
	#UNIONFS Tools
	if [ "${UNIONFS}" -eq '1' ]
	then
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
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-unionfs-${UNIONFS_VER}-tools.cpio.gz
	rm -r "${TEMP}/initramfs-unionfs-tools-temp/"
	fi										        
}

create_dmraid_cpio(){
	# DMRAID
	if [ "${DMRAID}" = '1' ]
	then
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
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-dmraid-${DMRAID_VER}.cpio.gz
	rm -r "${TEMP}/initramfs-dmraid-temp/"
	fi										        
}

create_lvm2_cpio(){
	# LVM2
	if [ "${LVM2}" -eq '1' ]
	then
		if [ -d "${TEMP}/initramfs-lvm2-temp" ]
		then
			rm -r "${TEMP}/initramfs-lvm2-temp/"
		fi
		cd ${TEMP}
		mkdir -p "${TEMP}/initramfs-lvm2-temp/bin/"
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
		cd "${TEMP}/initramfs-lvm2-temp/"
		find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-lvm2-${LVM2_VER}.cpio.gz
		rm -r "${TEMP}/initramfs-lvm2-temp/"
	else # Deprecation warning; remove in a few versions.
		if [ -e '/sbin/lvm' ]
		then
			if ldd /sbin/lvm|grep -q 'not a dynamic executable';
			then
				print_warning 1 'LVM2: For support, use --lvm2!'
			fi
		fi
	fi
}

create_evms2_cpio(){	
	# EVMS2
	if [ -e '/sbin/evms_activate' ]
	then
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
			cp -a /lib/ld-* "${TEMP}/initramfs-evms2-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libc-* /lib/libc.* "${TEMP}/initramfs-evms2-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libdl-* /lib/libdl.* "${TEMP}/initramfs-evms2-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libpthread* "${TEMP}/initramfs-evms2-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libuuid*so* "${TEMP}/initramfs-evms2-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/libevms*so* "${TEMP}/initramfs-evms2-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/evms "${TEMP}/initramfs-evms2-temp/lib" || gen_die 'Could not copy files for EVMS2!'
			cp -a /lib/evms/* "${TEMP}/initramfs-evms2-temp/lib/evms" || gen_die 'Could not copy files for EVMS2!'
			cp -a /etc/evms.conf "${TEMP}/initramfs-evms2-temp/etc" || gen_die 'Could not copy files for EVMS2!'
			cp /sbin/evms_activate "${TEMP}/initramfs-evms2-temp/sbin/evms_activate" || gen_die 'Could not copy over evms_activate!'

			# Fix EVMS2 complaining that it can't find the swap utilities.
			# These are not required in the initramfs
			for swap_libs in "${TEMP}/initramfs-evms2-temp/lib/evms/*/swap*.so"
			do
				rm ${swap_libs}
			done
		fi
		cd "${TEMP}/initramfs-evms2-temp/"
		find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-evms2.cpio.gz
		rm -r "${TEMP}/initramfs-evms2-temp/"
	fi	
}

create_gensplash(){	
	if [ "${GENSPLASH}" -eq '1' ]
	then
		if [ -x /sbin/splash ]
		then
			[ -z "${GENSPLASH_THEME}" ] && [ -e /etc/conf.d/splash ] && source /etc/conf.d/splash
			[ -z "${GENSPLASH_THEME}" ] && GENSPLASH_THEME=default
			print_info 1 "  >> Installing gensplash [ using the ${GENSPLASH_THEME} theme ]..."
			cd /
			local tmp=""
			[ -n "${GENSPLASH_RES}" ] && tmp="-r ${GENSPLASH_RES}"
			splash_geninitramfs -g ${CACHE_CPIO_DIR}/initramfs-splash-${KV}.cpio.gz ${tmp} ${GENSPLASH_THEME}
			if [ -e "/usr/share/splashutils/initrd.splash" ]; then
				if [ -d "${TEMP}/initramfs-gensplash-temp" ]
				then
					rm -r "${TEMP}/initramfs-gensplash-temp/"
				fi
				mkdir -p "${TEMP}/initramfs-gensplash-temp/etc"
				cd "${TEMP}/initramfs-gensplash-temp/"
				gunzip -c ${CACHE_CPIO_DIR}/initramfs-splash-${KV}.cpio.gz | cpio -idm --quiet -H newc
				cp "/usr/share/splashutils/initrd.splash" "${TEMP}/initramfs-gensplash-temp/etc"
				find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-splash-${KV}.cpio.gz
				rm -r "${TEMP}/initramfs-gensplash-temp/"
			fi
		else
			print_warning 1 '               >> No splash detected; skipping!'
		fi
	fi
}
create_initramfs_overlay_cpio(){
	cd ${INITRAMFS_OVERLAY}
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-overlay.cpio.gz
}
print_list()
{
	local x
	for x in ${*}
	do
		echo ${x}
	done
}

create_initramfs_modules() {
	local group
	local group_modules
	
	MOD_EXT=".ko"

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
	find . | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-modules-${KV}.cpio.gz
	rm -r "${TEMP}/initramfs-modules-${KV}-temp/"	
}

create_initramfs_aux() {
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

	# Make a symlink to init .. incase we are bundled inside the kernel as one big cpio.
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
	if isTrue $CMD_BLADECENTER
	then
		echo 'MY_HWOPTS="${MY_HWOPTS} bladecenter"' >> ${TEMP}/initramfs-aux-temp/etc/initrd.defaults
	fi

	cd ${TEMP}/initramfs-aux-temp/sbin && ln -s ../init init
	cd ${TEMP}
	chmod +x "${TEMP}/initramfs-aux-temp/init"
	chmod +x "${TEMP}/initramfs-aux-temp/etc/initrd.scripts"
	chmod +x "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	chmod +x "${TEMP}/initramfs-aux-temp/sbin/modprobe"
	cd "${TEMP}/initramfs-aux-temp/"
	find . -print | cpio --quiet -o -H newc | gzip -9 > ${CACHE_CPIO_DIR}/initramfs-aux.cpio.gz
	rm -r "${TEMP}/initramfs-aux-temp/"	
}

merge_initramfs_cpio_archives(){
	cd "${CACHE_CPIO_DIR}"
	MERGE_LIST="initramfs-base-layout.cpio.gz initramfs-aux.cpio.gz"	
	if [ ! -e "${CACHE_CPIO_DIR}/initramfs-base-layout.cpio.gz" ]
	then
		gen_die "${CACHE_CPIO_DIR}/initramfs-base-layout.cpio.gz is missing."
	fi
	if [ ! -e "${CACHE_CPIO_DIR}/initramfs-aux.cpio.gz" ]
	then
		gen_die "${CACHE_CPIO_DIR}/initramfs-aux.cpio.gz is missing."
	fi
	
	if [ "${BUSYBOX}" -eq '1' -a -e ${CACHE_CPIO_DIR}/initramfs-busybox-${BUSYBOX_VER}.cpio.gz ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-busybox-${BUSYBOX_VER}.cpio.gz"
	fi
	
	if [ "${NOINITRDMODULES}" = '' -a -e ${CACHE_CPIO_DIR}/initramfs-insmod-${MODULE_INIT_TOOLS_VER}.cpio.gz ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-insmod-${MODULE_INIT_TOOLS_VER}.cpio.gz"
	fi
	
	if [ "${UDEV}" -eq '1' -a -e ${CACHE_CPIO_DIR}/initramfs-udev-${UDEV_VER}.cpio.gz ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-udev-${UDEV_VER}.cpio.gz"
	fi
	if [ "${DISKLABEL}" -eq '1' -a -e ${CACHE_CPIO_DIR}/initramfs-blkid-${E2FSPROGS_VER}.cpio.gz ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-blkid-${E2FSPROGS_VER}.cpio.gz"
	fi
	if [ "${UNIONFS}" -eq '1' -a -e ${CACHE_CPIO_DIR}/initramfs-unionfs-${UNIONFS_VER}-tools.cpio.gz ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-unionfs-${UNIONFS_VER}-tools.cpio.gz"
	fi
	if [ "${UNIONFS}" -eq '1' -a -e ${CACHE_CPIO_DIR}/initramfs-unionfs-${UNIONFS_VER}-modules-${KV}.cpio.gz ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-unionfs-${UNIONFS_VER}-modules-${KV}.cpio.gz"
	fi
	if [ "${EVMS2}" -eq '1' -a -e "${CACHE_CPIO_DIR}/initramfs-evms2.cpio.gz" ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-evms2.cpio.gz"
	fi
	if [ "${LVM2}" -eq '1' -a -e "${CACHE_CPIO_DIR}/initramfs-lvm2-${LVM2_VER}.cpio.gz" ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-lvm2-${LVM2_VER}.cpio.gz"
	fi
	if [ "${DEVFS}" -eq '1' -a -e "${CACHE_CPIO_DIR}/initramfs-devfs-${DEVFSD_VER}.cpio.gz" ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-devfs-${DEVFSD_VER}.cpio.gz"
	fi
	if [ "${DMRAID}" -eq '1' -a -e ${CACHE_CPIO_DIR}/initramfs-dmraid-${DMRAID_VER}.cpio.gz ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-dmraid-${DMRAID_VER}.cpio.gz"
	fi
	if [ "${NOINITRDMODULES}" = '' -a -e "${CACHE_CPIO_DIR}/initramfs-modules-${KV}.cpio.gz" ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-modules-${KV}.cpio.gz"
	fi
	if [ "${GENSPLASH}" -eq '1' -a -e "${CACHE_CPIO_DIR}/initramfs-splash-${KV}.cpio.gz" ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-splash-${KV}.cpio.gz"
	fi
	# This should always be appended last
	if [ "${INITRAMFS_OVERLAY}" != '' -a -e "${CACHE_CPIO_DIR}/initramfs-overlay.cpio.gz" ]
	then
		MERGE_LIST="${MERGE_LIST} initramfs-overlay.cpio.gz"
	fi
	
	echo
	print_info 1 "Merging"
	for i in ${MERGE_LIST}
	do
		print_info 1 "    $i"
	done

    	cat ${MERGE_LIST} > ${TMPDIR}/initramfs-${KV}

	# Pegasos hack for merging the initramfs into the kernel at compile time
	[ "${KERNEL_MAKE_DIRECTIVE}" == 'zImage.initrd' -a "${GENERATE_Z_IMAGE}" = '1' ] ||
		[ "${KERNEL_MAKE_DIRECTIVE_2}" == 'zImage.initrd' -a "${GENERATE_Z_IMAGE}" = '1' ] &&
			cp ${TMPDIR}/initramfs-${KV} ${KERNEL_DIR}/arch/${ARCH}/boot/images/ramdisk.image.gz &&
			rm ${TMPDIR}/initramfs-${KV}

	# Mips also mimics Pegasos to merge the initramfs into the kernel
	if [ ${BUILD_INITRAMFS} -eq 1 ]; then
		cp ${TMPDIR}/initramfs-${KV} ${KERNEL_DIR}/initramfs.cpio.gz
		gunzip -f ${KERNEL_DIR}/initramfs.cpio.gz
	fi
}

clear_cpio_dir(){
	if [ "${CLEAR_CPIO_CACHE}" == 'yes' ]
	then

		if [ -d ${CACHE_CPIO_DIR} ]
		then
			print_info 1 "        >> Clearing old cpio archives..."
	    		rm -r ${CACHE_CPIO_DIR}
		fi
	fi
	
	if [ ! -d ${CACHE_CPIO_DIR} ]
	then
		mkdir -p ${CACHE_CPIO_DIR}
	fi
}

create_initramfs() {
	local MOD_EXT

	print_info 1 "initramfs: >> Initializing..."
	clear_cpio_dir
	mkdir -p ${CACHE_CPIO_DIR}
	print_info 1 "        >> Creating base_layout cpio archive..."
	create_base_layout_cpio
	
	print_info 1 "        >> Creating auxilary cpio archive..."
	create_initramfs_aux
	
	if [ "${BUSYBOX}" -eq '1' ]
	then
	    print_info 1 "        >> Creating busybox cpio archive..."
	    create_busybox_cpio
	fi
	
	if [ "${DEVFS}" -eq '1' ]
	then
	    print_info 1 "        >> Creating devfs cpio archive..."
	    create_devfs_cpio
	fi
	
	if [ "${UDEV}" -eq '1' ]
	then
	    print_info 1 "        >> Creating udev cpio archive..."
	    create_udev_cpio
	fi
	
	if [ "${UNIONFS}" -eq '1' ]
	then
	    print_info 1 "        >> Creating unionfs modules cpio archive..."
	    create_unionfs_modules_cpio
	    print_info 1 "        >> Creating unionfs tools cpio archive..."
	    create_unionfs_tools_cpio
	fi
	
	if [ "${LVM2}" -eq '1' ]
	then
	    
	    print_info 1 "        >> Creating lvm2 cpio archive..."
	    create_lvm2_cpio
	fi
	
	if [ "${DMRAID}" -eq '1' ]
	then
	    print_info 1 "        >> Creating dmraid cpio archive..."
	    create_dmraid_cpio
	fi
	
	if [ "${EVMS2}" -eq '1' -a -e '/sbin/evms_activate' ]
	then
		print_info 1 "        >> Creating evms2 cpio archive..."
		create_evms2_cpio
	fi
	
	if [ "${NOINITRDMODULES}" = '' ]
	then
		print_info 1 "        >> Creating insmod cpio archive..."
		create_insmod_cpio
		print_info 1 "        >> Creating modules cpio archive..."
		create_initramfs_modules
	else
		print_info 1 "initramfs: Not copying modules..."
	fi
	
	if [ "${DISKLABEL}" -eq '1' ]
	then
		print_info 1 "        >> Creating blkid cpio archive..."
		create_blkid_cpio
	fi
		
	create_gensplash
	
	if [ "${INITRAMFS_OVERLAY}" != '' ]
	then
		print_info 1 "        >> Creating initramfs_overlay cpio archive..."
		create_initramfs_overlay_cpio
	fi
	
	merge_initramfs_cpio_archives

	if ! isTrue "${CMD_NOINSTALL}"
	then
		if [ "${GENERATE_Z_IMAGE}" != '1' ]
		then
			cp ${TMPDIR}/initramfs-${KV} /boot/initramfs-${KNAME}-${ARCH}-${KV} ||
				gen_die 'Could not copy the initramfs to /boot!'
		fi
	fi
}
