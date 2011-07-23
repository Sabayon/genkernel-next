#!/bin/ash

# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License, v2 or later

export PATH="/usr/sbin:/usr/bin:/sbin:/bin"

#// Path, basic vars
#//--------------------------------------------------------------------------------

BasicSetup() {
	#// Copyright year, Build date in YYYYMMDD format, and in MMDDYYYY to make busybox 'date' happy
	MYDATE="`/bin/cat /etc/build_date`"
	CPYYEAR="$(echo ${MYDATE} | cut -c 1-4)"
	BBDATE="$(echo ${MYDATE} | cut -c 5-8)$(echo ${MYDATE} | cut -c 1-4)"
	DISDATE="$(echo ${MYDATE} | cut -c 7-8) $(echo ${MYDATE} | cut -c 5-6) $(echo ${MYDATE} | cut -c 1-4)"

	. /etc/initrd.defaults
	# Clean input/output
	exec >${CONSOLE} <${CONSOLE} 2>&1
}
#//--------------------------------------------------------------------------------



#// Startup Tasks
#//--------------------------------------------------------------------------------

StartUp() {
	if [ ! -f "/tmp/.startup" ]; then
		#// Mount proc && sys
		mount proc	/proc		-t proc			# /proc
		mount sys	/sys		-t sysfs		# /sys
		mount mdev	/dev		-t tmpfs  -o size=800k	# /dev for mdev

		#// Let busybox build its applets
		/bin/busybox --install -s

		#// Create additional mount points
		mkdir -m 0755 /dev/pts
		mkdir		/dev/shm
		mkdir -p	/mnt/cdrom
		mkdir		/mnt/floppy
		mkdir		/mnt/gentoo
		mkdir		/tmp

		#// Mount remaining filesystems
		mount tmp	/tmp		-t tmpfs		# /tmp
		mount devpts	/dev/pts 	-t devpts -o gid=5,mode=0620	# /dev/pts
		mount shm	/dev/shm	-t tmpfs -o size=512k	# /dev/shm

		#// Create mtab
		ln -sf	/proc/mounts		/etc/mtab		# mtab (symlink -> /proc/mounts)

		#// Start mdev
		echo "/sbin/mdev" > /proc/sys/kernel/hotplug		# mdev handles hotplug events
		/sbin/mdev -s						# have mdev populate /dev

		#// Create standard (non-mdev) devices
		if [ ! -e /dev/md0 ]
		then
			makedevs	/dev/md		b 9 0 0 7
		fi

		if [ ! -e /dev/tty0 ]
		then
			makedevs 	/dev/tty	c 4 0 0 12
		fi

		# We probably don't need any of these anymore with mdev
#		makedevs	/dev/ptyp	c 2 0 0 9
#		makedevs	/dev/ttyp	c 3 0 0 9
#		makedevs	/dev/ttyq	c 3 16 0 9
#		makedevs	/dev/ttyS	c 4 64 0 3
#		mknod		/dev/console	c 5 1
#		mknod		/dev/kmsg	c 1 11
#		mknod		/dev/null	c 1 3
#		mknod		/dev/tty	c 5 0
#		mknod		/dev/urandom	c 1 9
#		ln -s		/dev/urandom	/dev/random
#		mknod		/dev/zero	c 1 5

		#// Create std* devices
		ln -snf /proc/self/fd /dev/fd
		ln -snf /proc/self/fd/0 /dev/stdin
		ln -snf /proc/self/fd/1 /dev/stdout
		ln -snf /proc/self/fd/2 /dev/stderr

		#// Make some misc directories
		mkdir	/var/log
		mkdir	/var/run

		#// Start a minimal logger
		klogd
		syslogd

		#// Hostname
		hostname netboot

		if [ -n "`which dropbear 2>/dev/null`" ]
		then
			# Setup dropbear (sshd)
			echo -e ""
			mkdir /etc/dropbear
			echo -e ">>> Generating RSA hostkey ..."
			dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key
			echo -e ""
			echo -e ">>> Generating DSS hostkey ..."
			dropbearkey -t dss -f /etc/dropbear/dropbear_dss_host_key
			echo -e ""
			dropbear
		fi

		#// Misc tasks
		chmod +x /bin/net-setup
		chmod +x /bin/ashlogin
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

	for i in 2 3 4 5 6; do
		getty -n -l /bin/ashlogin 38400 tty${i} &
	done

#	# We run the getty for tty1 in the foreground so our pid 1 doesn't end
#	getty -n -l /bin/ashlogin 38400 tty1

	# We were running the above code, but that doesn't work well on serial. Until
	# we can autodetect a serial console and start a getty there, we'll just run
	# ash on /dev/console
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
	sparc*)		DetectSparc
		mount -t openpromfs openprom /proc/openprom
	;;
	ppc*)		DetectPpc	;;
	*)			MACHTYPE=$ARCHINFO	;;
esac

DetectNetwork
SubGenius
GenMotd
DisplayMotd
LaunchShell

#//--------------------------------------------------------------------------------

