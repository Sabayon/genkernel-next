#!/bin/ash

# Copyright 2001-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License, v2 or later



#// Path, basic vars
#//--------------------------------------------------------------------------------

BasicSetup() {
	export PATH=/usr/sbin:/usr/bin:/sbin:/bin

	#// Copyright year, Build date in YYYYMMDD format, and in MMDDYYYY to make busybox 'date' happy
	MYDATE="@@MYDATE@@"
	CPYYEAR="$(echo ${MYDATE} | cut -c 1-4)"
	BBDATE="$(echo ${MYDATE} | cut -c 5-8)$(echo ${MYDATE} | cut -c 1-4)"
	DISDATE="$(echo ${MYDATE} | cut -c 7-8) $(echo ${MYDATE} | cut -c 5-6) $(echo ${MYDATE} | cut -c 1-4)"
}
#//--------------------------------------------------------------------------------



#// Startup Tasks
#//--------------------------------------------------------------------------------

StartUp() {
	if [ ! -f "/tmp/.startup" ]; then
		#// Mount proc && sys
		mount none	/proc		-t proc			# /proc
		mount none	/sys		-t sysfs		# /sys
		mount udev	/dev		-t tmpfs  -o size=250k	# /dev for udev

		#// Let busybox build its applets
		/bin/busybox --install

		#// Create additional mount points
		mkdir		/dev/pts
		mkdir		/dev/shm
		mkdir		/gentoo
		mkdir -p	/mnt/cdrom
		mkdir -p	/mnt/floppy
		mkdir		/root
		mkdir		/srv
		mkdir		/tmp

		#// Mount remaining filesystems
		mount none	/tmp		-t tmpfs  -o rw		# /tmp
		mount devpts	/dev/pts 	-t devpts 		# /dev/pts

		#// Create mtab
		ln -sf	/proc/mounts		/etc/mtab		# mtab (symlink -> /proc/mounts)

		#// Udevstart segfaults if this file exists; Works for our needs fine w/o it.
		rm -f /etc/udev/rules.d/50-udev.rules	

		#// Start udev
		echo "/sbin/udevsend" > /proc/sys/kernel/hotplug
		/sbin/udevstart

		#// udev doesn't create RAID devices or std* for us
		mknod 	/dev/md0		b 9 0
		mknod 	/dev/md1		b 9 1
		mknod 	/dev/md2		b 9 2
		mknod 	/dev/md3		b 9 3
		mknod 	/dev/md4		b 9 4
		mknod 	/dev/md5		b 9 5
		mknod 	/dev/md6		b 9 6
		mknod 	/dev/md7		b 9 7
		mknod 	/dev/md8		b 9 8
		mknod 	/dev/md9		b 9 9
	        ln -snf /proc/self/fd		/dev/fd
	        ln -snf /proc/self/fd/0		/dev/stdin
	        ln -snf /proc/self/fd/1		/dev/stdout
	        ln -snf /proc/self/fd/2		/dev/stderr

		#// /dev/random blocks, use /dev/urandom instead
		mv	/dev/random		/dev/random-blocks
		ln -sf	/dev/urandom		/dev/random

		#// Setup dropbear (sshd)
		echo -e ""
		mkdir /etc/dropbear
		echo -e ">>> Generating RSA hostkey ..."
		dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
		echo -e ""
		echo -e ">>> Generating DSS hostkey ..."
		dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
		echo -e ""
		dropbear

		#// Misc tasks
		chmod +x /bin/net-setup
		chmod +x /usr/share/udhcpc/default.script

		#// Hostname
		hostname netboot-@@RELVER@@
	fi

}

#//--------------------------------------------------------------------------------



#// Informative Message (copied from Gentoo /sbin/functions.sh)
#//--------------------------------------------------------------------------------

#// show an informative message (with a newline)
einfo() {
	echo -e " * ${*}"
	return 0
}

#//--------------------------------------------------------------------------------



#// Determine Mips Machine Type
#//--------------------------------------------------------------------------------

DetectMips() {
	MYARCH="MIPS"
	MACHINFO="$(cat /proc/cpuinfo | grep "system type" | tr -d "\t" | sed -e "s/: /:/g" | cut -d":" -f2)"
	CPUINFO="$(cat /proc/cpuinfo | grep "cpu model" | tr -d "\t" | sed -e "s/: /:/g" | cut -d":" -f2)"
	case "${MACHINFO}" in
		"SGI Indy")			MACHTYPE="SGI Indy"		;;	# Indy R4x00/R5000
		"SGI Indigo2")
			case "${CPUINFO}" in
				R4*)		MACHTYPE="SGI Indigo2"		;;	# I2 R4x00
				R8*)		MACHTYPE="SGI Indigo2 Power"	;;	# I2 R8000
				R10*)		MACHTYPE="SGI Indigo2 Impact"	;;	# I2 R10000
			esac
			;;
		"SGI O2"|"SGI IP32")		MACHTYPE="SGI O2"		;;	# O2 R5K/RM5K2/RM7K/R10K/R12K
		"SGI Octane"|"SGI IP30")	MACHTYPE="SGI Octane"		;;	# Octane R10K/R12K/R14K
		"SGI Origin"|"SGI IP27")	MACHTYPE="SGI Origin"		;;	# Origin 200/2000 R10K/R12K
		"MIPS Cobalt"|*RaQ*|*Qube*)	MACHTYPE="Cobalt Microserver"	;;	# Cobalt Qube/RaQ (1/2)
		*)				MACHTYPE="Unknown MIPS"		;;	# ???
	esac
}

#//--------------------------------------------------------------------------------



#// Determine Sparc Machine Type
#//--------------------------------------------------------------------------------

DetectSparc() {
	MYARCH="SPARC"
	MACHINFO="$(cat /proc/cpuinfo | grep "type" | tr -d "\t" | sed -e "s/: /:/g" | cut -d":" -f2)"

	case "${MACHINFO}" in
		sun4u)			MACHTYPE="Sun UltraSparc"	;;		# Sparc64
		sun4c|sun4d|sun4m)	MACHTYPE="Sun Sparc32"		;;		# Sparc32
		*)			MACHTYPE="Unknown SPARC"	;;		# ???
	esac
}

#//--------------------------------------------------------------------------------



#// Determine Ppc Machine Type
#//--------------------------------------------------------------------------------

DetectPpc() {
	MACHINFO="$(cat /proc/cpuinfo | grep "machine" | tr -d "\t" | sed -e "s/: /:/g" | cut -d":" -f2)"

	case "${ARCHINFO}" in
		ppc)
			MYARCH="PPC"
			case "${MACHINFO}" in
				PowerMac*)	MACHTYPE="Apple PowerMac"	;;	# PowerMac
				PowerBook*)	MACHTYPE="Apple PowerBook"	;;	# PowerBook
				"CHRP Pegasos")	MACHTYPE="Pegasos"		;;	# Pegasos
				CHRP*|PReP)	MACHTYPE="IBM PPC-Based"	;;	# IBM PPC
				Amiga)		MACHTYPE="Amiga"		;;	# Amiga
				*)		MACHTYPE="Unknown PPC"		;;	# ???
			esac
		;;

		ppc64)
			MYARCH="PPC64"
			case "${MACHINFO}" in
				PowerMac*)	MACHTYPE="Apple G5"		;;	# Apple G5
				CHRP*|PReP)	MACHTYPE="IBM PPC-Based"	;;	# IBM PPC
				*iSeries*)	MACHTYPE="iSeries (Old)"	;;	# Old iSeries
				*)		MACHTYPE="Unknown PPC64"	;;	# ???
			esac
		;;
	esac
}

#//--------------------------------------------------------------------------------



#// Discover if the network is already running for us or not
#//--------------------------------------------------------------------------------

DetectNetwork() {
	if [ ! -f "/tmp/.startup" ]; then
		#// If this image is loaded via NFS Root, chances are the network is autoconfigured for us
		if [ ! -z "$(ifconfig | grep "eth0")" ]; then
			MYIP="$(ifconfig | grep "inet addr" | cut -d":" -f2 | cut -d" " -f1 | head -n 1)"
			MYGW="$(route | grep default | cut -d" " -f10)"
		fi
	fi
}

#//--------------------------------------------------------------------------------



#// For those in the Church of the SubGenius...
#//--------------------------------------------------------------------------------

SubGenius() {
	BUILDDATE="Build Date: $(date -d ${BBDATE} +"%B %d, %Y")"
	for CMDLINE in $(cat /proc/cmdline); do
		if [ "${CMDLINE}" = "discord" ]; then
			BUILDDATE="$(ddate +'Built on %{%A, the %e day of %B%} in the YOLD %Y. %NCelebrate %H!' ${DISDATE})"
		fi
	done
}
#//--------------------------------------------------------------------------------



#// Basic Startup Stuff
#//--------------------------------------------------------------------------------

GenMotd() {
	echo -e ""										> /etc/motd
	echo -e ""										>> /etc/motd
	echo -e "Gentoo Linux; http://www.gentoo.org/"						>> /etc/motd
	echo -e " Copyright 2001-${CPYYEAR} Gentoo Foundation; Distributed under the GPL"	>> /etc/motd
	echo -e ""										>> /etc/motd
	echo -e " Gentoo/${MYARCH} Netboot for ${MACHTYPE} Systems"				>> /etc/motd
	echo -e " ${BUILDDATE}"									>> /etc/motd
	echo -e ""										>> /etc/motd

	#// If this is the initial startup, then display some messages, otherwise just execute a shell for the user
	if [ ! -f "/tmp/.startup" ]; then
		if [ -z "${MYIP}" ]; then
			einfo "To configure networking (eth0), do the following:"		> /etc/motd2
			echo -e ""								>> /etc/motd2
			einfo "For Static IP:"							>> /etc/motd2
			einfo "/bin/net-setup <IP Address> <Gateway Address>"			>> /etc/motd2
			echo -e ""								>> /etc/motd2
			einfo "For Dynamic IP:"							>> /etc/motd2
			einfo "/bin/net-setup dhcp"						>> /etc/motd2
			echo -e ""								>> /etc/motd2
		else
			echo -e ""								> /etc/motd2
			einfo "Network interface eth0 has been started:"			>> /etc/motd2
			einfo "  IP Address: ${MYIP}"						>> /etc/motd2
			einfo "  Gateway:    ${MYGW}"						>> /etc/motd2
			echo -e ""								>> /etc/motd2
			einfo "An sshd server is available on port 22.  Please set a root"	>> /etc/motd2
			einfo "password via \"passwd\" before using."				>> /etc/motd2
			echo -e ""								>> /etc/motd2
		fi
	fi
}

#//--------------------------------------------------------------------------------



#// Display Motd
#//--------------------------------------------------------------------------------

DisplayMotd() {
	cat /etc/motd
	[ -f "/etc/motd2" ] && cat /etc/motd2
}

#//--------------------------------------------------------------------------------



#// Launch Shell
#//--------------------------------------------------------------------------------

LaunchShell() {
	#// Completed Startup
	touch /tmp/.startup

	#// All Done!
	echo -e ""
	/bin/ash
}

#//--------------------------------------------------------------------------------



#// Main
#//--------------------------------------------------------------------------------

BasicSetup
StartUp

#// Detect Arch
ARCHINFO="$(uname -m)"
case "${ARCHINFO}" in
	mips*)		DetectMips	;;
	sparc*)		DetectSparc	;;
	ppc*)		DetectPpc	;;
esac

DetectNetwork
SubGenius
GenMotd
DisplayMotd
LaunchShell

#//--------------------------------------------------------------------------------

