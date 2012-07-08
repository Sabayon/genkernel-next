#!/bin/bash
# $Id$

CPIO_ARGS="--quiet -o -H newc"

# The copy_binaries function is explicitly released under the CC0 license to
# encourage wide adoption and re-use.  That means:
# - You may use the code of copy_binaries() as CC0 outside of genkernel
# - Contributions to this function are licensed under CC0 as well.
# - If you change it outside of genkernel, please consider sending your
#   modifications back to genkernel@gentoo.org.
#
# On a side note: "Both public domain works and the simple license provided by
#                  CC0 are compatible with the GNU GPL."
#                 (from https://www.gnu.org/licenses/license-list.html#CC0)
#
# Written by: 
# - Sebastian Pipping <sebastian@pipping.org> (error checking)
# - Robin H. Johnson <robbat2@gentoo.org> (complete rewrite)
# - Richard Yao <ryao@cs.stonybrook.edu> (original concept)
# Usage:
# copy_binaries DESTDIR BINARIES...
copy_binaries() {
	local destdir=$1
	shift

	for binary in "$@"; do
		[[ -e "${binary}" ]] \
				|| gen_die "Binary ${binary} could not be found"

		if LC_ALL=C lddtree "${binary}" 2>&1 | fgrep -q 'not found'; then
			gen_die "Binary ${binary} is linked to missing libraries and may need to be re-built"
		fi
	done
	# This must be OUTSIDE the for loop, we only want to run lddtree etc ONCE.
	lddtree "$@" \
			| tr ')(' '\n' \
			| awk  '/=>/{ if($3 ~ /^\//){print $3}}' \
			| sort \
			| uniq \
			| cpio -p --make-directories --dereference --quiet "${destdir}" \
			|| gen_die "Binary ${f} or some of its library dependencies could not be copied"
}

log_future_cpio_content() {
	if [[ "${LOGLEVEL}" -gt 1 ]]; then
		echo =================================================================
		echo "About to add these files from '${PWD}' to cpio archive:"
		find . | xargs ls -ald
		echo =================================================================
	fi
}

append_base_layout() {
	if [ -d "${TEMP}/initramfs-base-temp" ]
	then
		rm -rf "${TEMP}/initramfs-base-temp" > /dev/null
	fi

	mkdir -p ${TEMP}/initramfs-base-temp/dev
	mkdir -p ${TEMP}/initramfs-base-temp/bin
	mkdir -p ${TEMP}/initramfs-base-temp/etc
	mkdir -p ${TEMP}/initramfs-base-temp/usr
	mkdir -p ${TEMP}/initramfs-base-temp/lib
	mkdir -p ${TEMP}/initramfs-base-temp/mnt
	mkdir -p ${TEMP}/initramfs-base-temp/run
	mkdir -p ${TEMP}/initramfs-base-temp/sbin
	mkdir -p ${TEMP}/initramfs-base-temp/proc
	mkdir -p ${TEMP}/initramfs-base-temp/temp
	mkdir -p ${TEMP}/initramfs-base-temp/tmp
	mkdir -p ${TEMP}/initramfs-base-temp/sys
	mkdir -p ${TEMP}/initramfs-temp/.initrd
	mkdir -p ${TEMP}/initramfs-base-temp/var/lock/dmraid
	mkdir -p ${TEMP}/initramfs-base-temp/sbin
	mkdir -p ${TEMP}/initramfs-base-temp/usr/bin
	mkdir -p ${TEMP}/initramfs-base-temp/usr/sbin
	ln -s  lib  ${TEMP}/initramfs-base-temp/lib64

	echo "/dev/ram0     /           ext2    defaults	0 0" > ${TEMP}/initramfs-base-temp/etc/fstab
	echo "proc          /proc       proc    defaults    0 0" >> ${TEMP}/initramfs-base-temp/etc/fstab

	cd ${TEMP}/initramfs-base-temp/dev
	mknod -m 660 console c 5 1
	mknod -m 660 null c 1 3
	mknod -m 660 zero c 1 5
	mknod -m 600 tty0 c 4 0
	mknod -m 600 tty1 c 4 1
	mknod -m 600 ttyS0 c 4 64

	date -u '+%Y%m%d-%H%M%S' > ${TEMP}/initramfs-base-temp/etc/build_date

	cd "${TEMP}/initramfs-base-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing baselayout cpio"
	cd "${TEMP}"
	rm -rf "${TEMP}/initramfs-base-temp" > /dev/null
}

append_busybox() {
	if [ -d "${TEMP}/initramfs-busybox-temp" ]
	then
		rm -rf "${TEMP}/initramfs-busybox-temp" > /dev/null
	fi

	mkdir -p "${TEMP}/initramfs-busybox-temp/bin/" 
	tar -xjf "${BUSYBOX_BINCACHE}" -C "${TEMP}/initramfs-busybox-temp/bin" busybox ||
		gen_die 'Could not extract busybox bincache!'
	chmod +x "${TEMP}/initramfs-busybox-temp/bin/busybox"

	mkdir -p "${TEMP}/initramfs-busybox-temp/usr/share/udhcpc/"
	cp "${GK_SHARE}/defaults/udhcpc.scripts" ${TEMP}/initramfs-busybox-temp/usr/share/udhcpc/default.script
	chmod +x "${TEMP}/initramfs-busybox-temp/usr/share/udhcpc/default.script"

	# Set up a few default symlinks
	for i in ${BUSYBOX_APPLETS:-[ ash sh mount uname echo cut cat}; do
		rm -f ${TEMP}/initramfs-busybox-temp/bin/$i > /dev/null
		ln -s busybox ${TEMP}/initramfs-busybox-temp/bin/$i ||
			gen_die "Busybox error: could not link ${i}!"
	done

	cd "${TEMP}/initramfs-busybox-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing busybox cpio"
	cd "${TEMP}"
	rm -rf "${TEMP}/initramfs-busybox-temp" > /dev/null
}

append_blkid(){
	if [ -d "${TEMP}/initramfs-blkid-temp" ]
	then
		rm -r "${TEMP}/initramfs-blkid-temp/"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-blkid-temp/"

	if [[ "${DISKLABEL}" = "1" ]]; then
		copy_binaries "${TEMP}"/initramfs-blkid-temp/ /sbin/blkid
	fi

	cd "${TEMP}/initramfs-blkid-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing blkid cpio"
	cd "${TEMP}"
	rm -rf "${TEMP}/initramfs-blkid-temp" > /dev/null
}

#append_fuse() {
#	if [ -d "${TEMP}/initramfs-fuse-temp" ]
#	then
#		rm -r "${TEMP}/initramfs-fuse-temp"
#	fi
#	cd ${TEMP}
#	mkdir -p "${TEMP}/initramfs-fuse-temp/lib/"
#	tar -C "${TEMP}/initramfs-fuse-temp/lib/" -xjf "${FUSE_BINCACHE}"
#	cd "${TEMP}/initramfs-fuse-temp/"
#	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
#			|| gen_die "compressing fuse cpio"
#	rm -rf "${TEMP}/initramfs-fuse-temp" > /dev/null
#}

append_unionfs_fuse() {
	if [ -d "${TEMP}/initramfs-unionfs-fuse-temp" ]
	then
		rm -r "${TEMP}/initramfs-unionfs-fuse-temp"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-unionfs-fuse-temp/sbin/"
	bzip2 -dc "${UNIONFS_FUSE_BINCACHE}" > "${TEMP}/initramfs-unionfs-fuse-temp/sbin/unionfs" ||
		gen_die 'Could not extract unionfs-fuse binary cache!'
	chmod a+x "${TEMP}/initramfs-unionfs-fuse-temp/sbin/unionfs"
	cd "${TEMP}/initramfs-unionfs-fuse-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing unionfs fuse cpio"
	cd "${TEMP}"
	rm -rf "${TEMP}/initramfs-unionfs-fuse-temp" > /dev/null
}

#append_suspend(){
#	if [ -d "${TEMP}/initramfs-suspend-temp" ];
#	then
#		rm -r "${TEMP}/initramfs-suspend-temp/"
#	fi
#	print_info 1 'SUSPEND: Adding support (compiling binaries)...'
#	compile_suspend
#	mkdir -p "${TEMP}/initramfs-suspend-temp/"
#	/bin/tar -jxpf "${SUSPEND_BINCACHE}" -C "${TEMP}/initramfs-suspend-temp" ||
#		gen_die "Could not extract suspend binary cache!"
#	mkdir -p "${TEMP}/initramfs-suspend-temp/etc"
#	cp -f /etc/suspend.conf "${TEMP}/initramfs-suspend-temp/etc" ||
#		gen_die 'Could not copy /etc/suspend.conf'
#	cd "${TEMP}/initramfs-suspend-temp/"
#	log_future_cpio_content
#	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
#			|| gen_die "compressing suspend cpio"
#	rm -r "${TEMP}/initramfs-suspend-temp/"
#}

append_multipath(){
	if [ -d "${TEMP}/initramfs-multipath-temp" ]
	then
		rm -r "${TEMP}/initramfs-multipath-temp"
	fi
	print_info 1 '	Multipath support being added'
	mkdir -p "${TEMP}"/initramfs-multipath-temp/{bin,etc,sbin,lib}/

	# Copy files
	copy_binaries "${TEMP}/initramfs-multipath-temp" /sbin/{multipath,kpartx,mpath_prio_*,devmap_name,dmsetup} /lib64/udev/scsi_id /bin/mountpoint

	if [ -x /sbin/multipath ]
	then
		cp /etc/multipath.conf "${TEMP}/initramfs-multipath-temp/etc/" || gen_die 'could not copy /etc/multipath.conf please check this'
	fi
	# /etc/scsi_id.config does not exist in newer udevs
	# copy it optionally.
	if [ -x /sbin/scsi_id -a -f /etc/scsi_id.config ]
	then
		cp /etc/scsi_id.config "${TEMP}/initramfs-multipath-temp/etc/" || gen_die 'could not copy scsi_id.config'
	fi
	cd "${TEMP}/initramfs-multipath-temp"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing multipath cpio"
	cd "${TEMP}"
	rm -r "${TEMP}/initramfs-multipath-temp/"
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
	RAID456=`find . -type f -name raid456.ko`
	if [ -n "${RAID456}" ]
	then
		cd "${RAID456/raid456.ko/}"
		ln -sf raid456.kp raid45.ko
		cd "${TEMP}/initramfs-dmraid-temp/"
	fi
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing dmraid cpio"
	cd "${TEMP}"
	rm -r "${TEMP}/initramfs-dmraid-temp/"
}

append_iscsi(){
	if [ -d "${TEMP}/initramfs-iscsi-temp" ]
	then
		rm -r "${TEMP}/initramfs-iscsi-temp/"
	fi
	print_info 1 'iSCSI: Adding support (compiling binaries)...'
	compile_iscsi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-iscsi-temp/bin/"
	/bin/bzip2 -dc "${ISCSI_BINCACHE}" > "${TEMP}/initramfs-iscsi-temp/bin/iscsistart" ||
		gen_die "Could not extract iscsi binary cache!"
	chmod a+x "${TEMP}/initramfs-iscsi-temp/bin/iscsistart"
	cd "${TEMP}/initramfs-iscsi-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing iscsi cpio"
	cd "${TEMP}"
	rm -rf "${TEMP}/initramfs-iscsi-temp" > /dev/null
}

append_lvm(){
	if [ -d "${TEMP}/initramfs-lvm-temp" ]
	then
		rm -r "${TEMP}/initramfs-lvm-temp/"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-lvm-temp/bin/"
	mkdir -p "${TEMP}/initramfs-lvm-temp/etc/lvm/"
	if false && [ -e '/sbin/lvm.static' ]
	then
		print_info 1 '          LVM: Adding support (using local static binary /sbin/lvm.static)...'
		cp /sbin/lvm.static "${TEMP}/initramfs-lvm-temp/bin/lvm" ||
			gen_die 'Could not copy over lvm!'
		# See bug 382555
		if [ -e '/sbin/dmsetup.static' ]
		then
			cp /sbin/dmsetup.static "${TEMP}/initramfs-lvm-temp/bin/dmsetup"
		fi
	elif false && [ -e '/sbin/lvm' ] && LC_ALL="C" ldd /sbin/lvm|grep -q 'not a dynamic executable'
	then
		print_info 1 '          LVM: Adding support (using local static binary /sbin/lvm)...'
		cp /sbin/lvm "${TEMP}/initramfs-lvm-temp/bin/lvm" ||
			gen_die 'Could not copy over lvm!'
		# See bug 382555
		if [ -e '/sbin/dmsetup' ] && LC_ALL="C" ldd /sbin/dmsetup | grep -q 'not a dynamic executable'
		then
			cp /sbin/dmsetup "${TEMP}/initramfs-lvm-temp/bin/dmsetup"
		fi
	else
		print_info 1 '          LVM: Adding support (compiling binaries)...'
		compile_lvm
		/bin/tar -jxpf "${LVM_BINCACHE}" -C "${TEMP}/initramfs-lvm-temp" ||
			gen_die "Could not extract lvm binary cache!";
		mv ${TEMP}/initramfs-lvm-temp/sbin/lvm.static ${TEMP}/initramfs-lvm-temp/bin/lvm ||
			gen_die 'LVM error: Could not move lvm.static to lvm!'
		# See bug 382555
		mv ${TEMP}/initramfs-lvm-temp/sbin/dmsetup.static ${TEMP}/initramfs-lvm-temp/bin/dmsetup ||
			gen_die 'LVM error: Could not move dmsetup.static to dmsetup!'
		rm -rf ${TEMP}/initramfs-lvm-temp/{lib,share,man,include,sbin/{lvm,dmsetup}}
	fi
	if [ -x /sbin/lvm -o -x /bin/lvm ]
	then
#		lvm dumpconfig 2>&1 > /dev/null || gen_die 'Could not copy over lvm.conf!'
#		ret=$?
#		if [ ${ret} != 0 ]
#		then
			cp /etc/lvm/lvm.conf "${TEMP}/initramfs-lvm-temp/etc/lvm/" ||
				gen_die 'Could not copy over lvm.conf!'
#		else
#			gen_die 'Could not copy over lvm.conf!'
#		fi
	fi
	cd "${TEMP}/initramfs-lvm-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing lvm cpio"
	cd "${TEMP}"
	rm -r "${TEMP}/initramfs-lvm-temp/"
}

append_mdadm(){
	if [ -d "${TEMP}/initramfs-mdadm-temp" ]
	then
		rm -r "${TEMP}/initramfs-mdadm-temp/"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-mdadm-temp/etc/"
	mkdir -p "${TEMP}/initramfs-mdadm-temp/sbin/"
	if [ "${MDADM}" = '1' ]
	then
		if [ -n "${MDADM_CONFIG}" ]
		then
			if [ -f "${MDADM_CONFIG}" ]
			then
				cp -a "${MDADM_CONFIG}" "${TEMP}/initramfs-mdadm-temp/etc/mdadm.conf" \
				|| gen_die "Could not copy mdadm.conf!"
			else
				gen_die 'sl${MDADM_CONFIG} does not exist!'
			fi
		else
			print_info 1 '		MDADM: Skipping inclusion of mdadm.conf'
		fi

		if [ -e '/sbin/mdadm' ] && LC_ALL="C" ldd /sbin/mdadm | grep -q 'not a dynamic executable' \
		&& [ -e '/sbin/mdmon' ] && LC_ALL="C" ldd /sbin/mdmon | grep -q 'not a dynamic executable'
		then
			print_info 1 '		MDADM: Adding support (using local static binaries /sbin/mdadm and /sbin/mdmon)...'
			cp /sbin/mdadm /sbin/mdmon "${TEMP}/initramfs-mdadm-temp/sbin/" ||
				gen_die 'Could not copy over mdadm!'
		else
			print_info 1 '		MDADM: Adding support (compiling binaries)...'
			compile_mdadm
			/bin/tar -jxpf "${MDADM_BINCACHE}" -C "${TEMP}/initramfs-mdadm-temp" ||
				gen_die "Could not extract mdadm binary cache!";
		fi
	fi
	cd "${TEMP}/initramfs-mdadm-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing mdadm cpio"
	cd "${TEMP}"
	rm -rf "${TEMP}/initramfs-mdadm-temp" > /dev/null
}

append_zfs(){
	if [ -d "${TEMP}/initramfs-zfs-temp" ]
	then
		rm -r "${TEMP}/initramfs-zfs-temp"
	fi

	mkdir -p "${TEMP}/initramfs-zfs-temp/etc/zfs/"

	# Copy files to /etc/zfs
	for i in /etc/zfs/{zdev.conf,zpool.cache}
	do
		cp -a "${i}" "${TEMP}/initramfs-zfs-temp/etc/zfs" \
			|| gen_die "Could not copy file ${i} for ZFS"
	done

	# Copy binaries
	copy_binaries "${TEMP}/initramfs-zfs-temp" /sbin/{mount.zfs,zfs,zpool}

	cd "${TEMP}/initramfs-zfs-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing zfs cpio"
	cd "${TEMP}"
	rm -rf "${TEMP}/initramfs-zfs-temp" > /dev/null
}

append_splash(){
	splash_geninitramfs=`which splash_geninitramfs 2>/dev/null`
	if [ -x "${splash_geninitramfs}" ]
	then
		[ -z "${SPLASH_THEME}" ] && [ -e /etc/conf.d/splash ] && source /etc/conf.d/splash
		[ -z "${SPLASH_THEME}" ] && SPLASH_THEME=default
		print_info 1 "  >> Installing splash [ using the ${SPLASH_THEME} theme ]..."
		if [ -d "${TEMP}/initramfs-splash-temp" ]
		then
			rm -r "${TEMP}/initramfs-splash-temp/"
		fi
		mkdir -p "${TEMP}/initramfs-splash-temp"
		cd /
		local tmp=""
		[ -n "${SPLASH_RES}" ] && tmp="-r ${SPLASH_RES}"
		splash_geninitramfs -c "${TEMP}/initramfs-splash-temp" ${tmp} ${SPLASH_THEME} || gen_die "Could not build splash cpio archive"
		if [ -e "/usr/share/splashutils/initrd.splash" ]; then
			mkdir -p "${TEMP}/initramfs-splash-temp/etc"
			cp -f "/usr/share/splashutils/initrd.splash" "${TEMP}/initramfs-splash-temp/etc"
		fi
		cd "${TEMP}/initramfs-splash-temp/"
		log_future_cpio_content
		find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing splash cpio"
		cd "${TEMP}"
		rm -r "${TEMP}/initramfs-splash-temp/"
	else
		print_warning 1 '               >> No splash detected; skipping!'
	fi
}

append_overlay(){
	cd ${INITRAMFS_OVERLAY}
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing overlay cpio"
}

append_luks() {
	local _luks_error_format="LUKS support cannot be included: %s.  Please emerge sys-fs/cryptsetup[static]."
	local _luks_source=/sbin/cryptsetup
	local _luks_dest=/sbin/cryptsetup

	if [ -d "${TEMP}/initramfs-luks-temp" ]
	then
		rm -r "${TEMP}/initramfs-luks-temp/"
	fi

	mkdir -p "${TEMP}/initramfs-luks-temp/lib/luks/"
	mkdir -p "${TEMP}/initramfs-luks-temp/sbin"
	cd "${TEMP}/initramfs-luks-temp"

	if isTrue ${LUKS}
	then
		[ -x "${_luks_source}" ] \
				|| gen_die "$(printf "${_luks_error_format}" "no file ${_luks_source}")"

		print_info 1 "Including LUKS support"
		copy_binaries "${TEMP}/initramfs-luks-temp/" /sbin/cryptsetup
	fi

	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
		|| gen_die "appending cryptsetup to cpio"

	cd "${TEMP}"
	rm -r "${TEMP}/initramfs-luks-temp/"
}

append_firmware() {
	if [ -z "${FIRMWARE_FILES}" -a ! -d "${FIRMWARE_DIR}" ]
	then
		gen_die "specified firmware directory (${FIRMWARE_DIR}) does not exist"
	fi
	if [ -d "${TEMP}/initramfs-firmware-temp" ]
	then
		rm -r "${TEMP}/initramfs-firmware-temp/"
	fi
	mkdir -p "${TEMP}/initramfs-firmware-temp/lib/firmware"
	cd "${TEMP}/initramfs-firmware-temp"
	if [ -n "${FIRMWARE_FILES}" ]
	then
		OLD_IFS=$IFS
		IFS=","
		for i in ${FIRMWARE_FILES}
		do
			cp -L "${i}" ${TEMP}/initramfs-firmware-temp/lib/firmware/
		done
		IFS=$OLD_IFS
	else
		cp -a "${FIRMWARE_DIR}"/* ${TEMP}/initramfs-firmware-temp/lib/firmware/
	fi
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
		|| gen_die "appending firmware to cpio"
	cd "${TEMP}"
	rm -r "${TEMP}/initramfs-firmware-temp/"
}

append_gpg() {
	if [ -d "${TEMP}/initramfs-gpg-temp" ]
	then
		rm -r "${TEMP}/initramfs-gpg-temp"
	fi
	cd ${TEMP}
	mkdir -p "${TEMP}/initramfs-gpg-temp/sbin/"
	if [ ! -e ${GPG_BINCACHE} ] ; then
		print_info 1 '		GPG: Adding support (compiling binaries)...'
		compile_gpg
	fi
	bzip2 -dc "${GPG_BINCACHE}" > "${TEMP}/initramfs-gpg-temp/sbin/gpg" ||
		gen_die 'Could not extract gpg binary cache!'
	chmod a+x "${TEMP}/initramfs-gpg-temp/sbin/gpg"
	cd "${TEMP}/initramfs-gpg-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}"
	rm -rf "${TEMP}/initramfs-gpg-temp" > /dev/null
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
	log_future_cpio_content
	find . | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing modules cpio"
	cd "${TEMP}"
	rm -r "${TEMP}/initramfs-modules-${KV}-temp/"	
}

# check for static linked file with objdump
is_static() {
	LANG="C" LC_ALL="C" objdump -T $1 2>&1 | grep "not a dynamic object" > /dev/null
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
		if isTrue ${NETBOOT}
		then
			cp "${GK_SHARE}/netboot/linuxrc.x" "${TEMP}/initramfs-aux-temp/init"
		else
			if [ -f "${GK_SHARE}/arch/${ARCH}/linuxrc" ]
			then
				cp "${GK_SHARE}/arch/${ARCH}/linuxrc" "${TEMP}/initramfs-aux-temp/init"
			else
				cp "${GK_SHARE}/defaults/linuxrc" "${TEMP}/initramfs-aux-temp/init"
			fi
		fi
	fi

	# Make sure it's executable
	chmod 0755 "${TEMP}/initramfs-aux-temp/init"

	# Make a symlink to init .. incase we are bundled inside the kernel as one
	# big cpio.
	cd ${TEMP}/initramfs-aux-temp
	ln -s init linuxrc
#	ln ${TEMP}/initramfs-aux-temp/init ${TEMP}/initramfs-aux-temp/linuxrc

	if [ -f "${GK_SHARE}/arch/${ARCH}/initrd.scripts" ]
	then
		cp "${GK_SHARE}/arch/${ARCH}/initrd.scripts" "${TEMP}/initramfs-aux-temp/etc/initrd.scripts"
	else
		cp "${GK_SHARE}/defaults/initrd.scripts" "${TEMP}/initramfs-aux-temp/etc/initrd.scripts"
	fi

	if [ -f "${GK_SHARE}/arch/${ARCH}/initrd.defaults" ]
	then
		cp "${GK_SHARE}/arch/${ARCH}/initrd.defaults" "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	else
		cp "${GK_SHARE}/defaults/initrd.defaults" "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	fi

	if [ -n "${REAL_ROOT}" ]
	then
		sed -i "s:^REAL_ROOT=.*$:REAL_ROOT='${REAL_ROOT}':" "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	fi

	echo -n 'HWOPTS="$HWOPTS ' >> "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	for group_modules in ${!MODULES_*}; do
		group="$(echo $group_modules | cut -d_ -f2 | tr "[:upper:]" "[:lower:]")"
		echo -n "${group} " >> "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	done
	echo '"' >> "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"

	if [ -f "${GK_SHARE}/arch/${ARCH}/modprobe" ]
	then
		cp "${GK_SHARE}/arch/${ARCH}/modprobe" "${TEMP}/initramfs-aux-temp/sbin/modprobe"
	else
		cp "${GK_SHARE}/defaults/modprobe" "${TEMP}/initramfs-aux-temp/sbin/modprobe"
	fi
	if isTrue $CMD_DOKEYMAPAUTO
	then
		echo 'MY_HWOPTS="${MY_HWOPTS} keymap"' >> ${TEMP}/initramfs-aux-temp/etc/initrd.defaults
	fi
	if isTrue $CMD_KEYMAP
	then
		print_info 1 "        >> Copying keymaps"
		mkdir -p "${TEMP}/initramfs-aux-temp/lib/"
		cp -R "${GK_SHARE}/defaults/keymaps" "${TEMP}/initramfs-aux-temp/lib/" \
				|| gen_die "Error while copying keymaps"
	fi

	cd ${TEMP}/initramfs-aux-temp/sbin && ln -s ../init init
	cd ${TEMP}
	chmod +x "${TEMP}/initramfs-aux-temp/init"
	chmod +x "${TEMP}/initramfs-aux-temp/etc/initrd.scripts"
	chmod +x "${TEMP}/initramfs-aux-temp/etc/initrd.defaults"
	chmod +x "${TEMP}/initramfs-aux-temp/sbin/modprobe"

	if isTrue ${NETBOOT}
	then
		cd "${GK_SHARE}/netboot/misc"
		cp -pPRf * "${TEMP}/initramfs-aux-temp/"
	fi

	cd "${TEMP}/initramfs-aux-temp/"
	log_future_cpio_content
	find . -print | cpio ${CPIO_ARGS} --append -F "${CPIO}" \
			|| gen_die "compressing auxilary cpio"
	cd "${TEMP}"
	rm -r "${TEMP}/initramfs-aux-temp/"
}

append_data() {
	local name=$1 var=$2
	local func="append_${name}"

	[ $# -eq 0 ] && gen_die "append_data() called with zero arguments"
	if [ $# -eq 1 ] || isTrue ${var}
	then
	    print_info 1 "        >> Appending ${name} cpio data..."
	    ${func} || gen_die "${func}() failed"
	fi
}

create_initramfs() {
	local compress_ext=""
	print_info 1 "initramfs: >> Initializing..."

	# Create empty cpio
	CPIO="${TMPDIR}/initramfs-${KV}"
	echo | cpio ${CPIO_ARGS} -F "${CPIO}" 2>/dev/null \
		|| gen_die "Could not create empty cpio at ${CPIO}"

	append_data 'base_layout'
	append_data 'auxilary' "${BUSYBOX}"
	append_data 'busybox' "${BUSYBOX}"
	append_data 'lvm' "${LVM}"
	append_data 'dmraid' "${DMRAID}"
	append_data 'iscsi' "${ISCSI}"
	append_data 'mdadm' "${MDADM}"
	append_data 'luks' "${LUKS}"
	append_data 'multipath' "${MULTIPATH}"
	append_data 'gpg' "${GPG}"

	if [ "${RAMDISKMODULES}" = '1' ]
	then
		append_data 'modules'
	else
		print_info 1 "initramfs: Not copying modules..."
	fi

	append_data 'zfs' "${ZFS}"

	append_data 'blkid' "${DISKLABEL}"

	append_data 'unionfs_fuse' "${UNIONFS}"

	append_data 'splash' "${SPLASH}"

	if isTrue "${FIRMWARE}" && [ -n "${FIRMWARE_DIR}" ]
	then
		append_data 'firmware'
	fi

	# This should always be appended last
	if [ "${INITRAMFS_OVERLAY}" != '' ]
	then
		append_data 'overlay'
	fi

	if isTrue "${INTEGRATED_INITRAMFS}"
	then
		# Explicitly do not compress if we are integrating into the kernel.
		# The kernel will do a better job of it than us.
		mv ${TMPDIR}/initramfs-${KV} ${TMPDIR}/initramfs-${KV}.cpio
		sed -i '/^.*CONFIG_INITRAMFS_SOURCE=.*$/d' ${KERNEL_DIR}/.config
		cat >>${KERNEL_DIR}/.config	<<-EOF
		CONFIG_INITRAMFS_SOURCE="${TMPDIR}/initramfs-${KV}.cpio${compress_ext}"
		CONFIG_INITRAMFS_ROOT_UID=0
		CONFIG_INITRAMFS_ROOT_GID=0
		EOF
	else
		if isTrue "${COMPRESS_INITRD}"
		then
			if [[ "$(file --brief --mime-type "${KERNEL_CONFIG}")" == application/x-gzip ]]; then
				# Support --kernel-config=/proc/config.gz, mainly
				local CONFGREP=zgrep
			else
				local CONFGREP=grep
			fi

			cmd_xz=$(type -p xz)
			cmd_lzma=$(type -p lzma)
			cmd_bzip2=$(type -p bzip2)
			cmd_gzip=$(type -p gzip)
			cmd_lzop=$(type -p lzop)
			pkg_xz='app-arch/xz-utils'
			pkg_lzma='app-arch/xz-utils'
			pkg_bzip2='app-arch/bzip2'
			pkg_gzip='app-arch/gzip'
			pkg_lzop='app-arch/lzop'
			local compression
			case ${COMPRESS_INITRD_TYPE} in
				xz|lzma|bzip2|gzip|lzop) compression=${COMPRESS_INITRD_TYPE} ;;
				lzo) compression=lzop ;;
				best|fastest)
					for tuple in \
							'CONFIG_RD_XZ    cmd_xz    xz' \
							'CONFIG_RD_LZMA  cmd_lzma  lzma' \
							'CONFIG_RD_BZIP2 cmd_bzip2 bzip' \
							'CONFIG_RD_GZIP  cmd_gzip  gzip' \
							'CONFIG_RD_LZO   cmd_lzop  lzop'; do
						set -- ${tuple}
						kernel_option=$1
						cmd_variable_name=$2
						if ${CONFGREP} -q "^${kernel_option}=y" "${KERNEL_CONFIG}" && test -n "${!cmd_variable_name}" ; then
							compression=$3
							[[ ${COMPRESS_INITRD_TYPE} == best ]] && break
						fi
					done
					;;
				*)
					gen_die "Compression '${COMPRESS_INITRD_TYPE}' unknown"
					;;
			esac

			# Check for actual availability
			cmd_variable_name=cmd_${compression}
			pkg_variable_name=pkg_${compression}
			[[ -z "${!cmd_variable_name}" ]] && gen_die "Compression '${compression}' is not available. Please install package '${!pkg_variable_name}'."

			case $compression in
				xz) compress_ext='.xz' compress_cmd="${cmd_xz} -e --check=none -z -f -9" ;;
				lzma) compress_ext='.lzma' compress_cmd="${cmd_lzma} -z -f -9" ;;
				bzip2) compress_ext='.bz2' compress_cmd="${cmd_bzip2} -z -f -9" ;;
				gzip) compress_ext='.gz' compress_cmd="${cmd_gzip} -f -9" ;;
				lzop) compress_ext='.lzo' compress_cmd="${cmd_lzop} -f -9" ;;
			esac
	
			if [ -n "${compression}" ]; then
				print_info 1 "        >> Compressing cpio data (${compress_ext})..."
				${compress_cmd} "${CPIO}" || gen_die "Compression (${compress_cmd}) failed"
				mv -f "${CPIO}${compress_ext}" "${CPIO}" || gen_die "Rename failed"
			else
				print_info 1 "        >> Not compressing cpio data ..."
			fi
		fi
	fi

	if isTrue "${CMD_INSTALL}"
	then
		if ! isTrue "${INTEGRATED_INITRAMFS}"
		then
			copy_image_with_preserve "initramfs" \
				"${TMPDIR}/initramfs-${KV}" \
				"initramfs-${KNAME}-${ARCH}-${KV}"
		fi
	fi
}
