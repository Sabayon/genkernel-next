#!/bin/bash

longusage() {
  echo "Gentoo Linux Genkernel ${GK_V}"
  echo "Usage: "
  echo "  genkernel [options] action"
  echo
  echo "Available Actions: "
  echo "  all				Build all steps"
  echo "  bzImage			Build only the kernel"
  echo "  kernel			Build only the kernel and modules"
  echo "  initrd			Build only the initrd"
  echo
  echo "Available Options: "
  echo "  Debug settings"
  echo "	--debuglevel=<0-5>	Debug Verbosity Level"
  echo "	--debugfile=<outfile>	Output file for debug info"
  echo "	--color			Output debug in color"
  echo "	--no-color		Do not output debug in color"
  echo "  Kernel Configuration settings"
  echo "	--menuconfig		Run menuconfig after oldconfig"
  echo "	--no-menuconfig		Do not run menuconfig after oldconfig"
  echo "	--gconfig		Run gconfig after oldconfig"
  echo "	--xconfig		Run xconfig after oldconfig"
  echo "	--save-config		Save the configuration to /etc/kernels"
  echo "	--no-save-config	Don't save the configuration to /etc/kernels"
  echo "  Kernel Compile settings"
  echo "	--clean			Run make clean before compilation"
  echo "	--mrproper		Run make mrproper before compilation"
  echo "	--no-clean		Do not run make clean before compilation"
  echo "	--no-mrproper		Do not run make mrproper before compilation"
  echo "	--oldconfig		Implies --no-clean and runs a 'make oldconfig'"
  echo "	--bootsplash		Install bootsplash support to the initrd"
  echo "	--no-bootsplash		Do not use bootsplash"
  echo "	--gensplash		Install gensplash support into bzImage"
  echo "	--no-gensplash		Do not use gensplash"
  echo "	--install		Install the kernel after building"
  echo "	--no-install		Do not install the kernel after building"
  echo "	--no-initrdmodules	Don't copy any modules to the initrd"
  echo "	--no-udev		Disable udev support"
  echo "	--no-devfs		Disable devfs support"
  echo "	--callback=<...>	Run the specified arguments after the"
  echo "				kernel and modules have been compiled"
  echo "	--static		Build a static (monolithic kernel)."
  echo "	--initramfs		Builds initramfs before kernel and embeds it"
  echo "				into the kernel."
  echo "  Kernel settings"
  echo "	--kerneldir=<dir>	Location of the kernel sources"
  echo "	--kernel-config=<file>	Kernel configuration file to use for compilation"
  echo "	--module-prefix=<dir>	Prefix to kernel module destination, modules will"
  echo "				be installed in <prefix>/lib/modules"
  echo "  Low-Level Compile settings"
  echo "	--kernel-cc=<compiler>	Compiler to use for kernel (e.g. distcc)"
  echo "	--kernel-as=<assembler>	Assembler to use for kernel"
  echo "	--kernel-ld=<linker>	Linker to use for kernel"
  echo "	--kernel-cross-compile=<cross var> CROSS_COMPILE kernel variable"
  echo "	--kernel-make=<makeprg> GNU Make to use for kernel"
  echo "	--utils-cc=<compiler>	Compiler to use for utilities"
  echo "	--utils-as=<assembler>	Assembler to use for utils"
  echo "	--utils-ld=<linker>	Linker to use for utils"
  echo "	--utils-make=<makeprog>	GNU Make to use for utils"
  echo "	--utils-cross-compile=<cross var> CROSS_COMPILE utils variable"
  echo "	--utils-arch=<arch> 	Force to arch for utils only instead of autodetect."
  echo "	--makeopts=<makeopts>	Make options such as -j2, etc..."
  echo "	--mountboot		Mount /boot automatically"
  echo "	--no-mountboot		Don't mount /boot automatically"  
  echo "  Initialization"
  echo "	--bootsplash=<theme>	Force bootsplash using <theme>"
  echo "	--gensplash=<theme>	Force gensplash using <theme>"
  echo "	--gensplash-res=<res>	Select gensplash resolutions"
  echo "	--do-keymap-auto	Forces keymap selection at boot"
  echo "	--evms2			Include EVMS2 support"
  echo "				--> 'emerge evms' in the host operating system first"
  echo "	--lvm2			Include LVM2 support"
#  echo "	--unionfs		Include UNIONFS support"
  echo "	--dmraid		Include DMRAID support"
  echo "	--slowusb		Enables extra pauses for slow USB CD boots"
  echo "	--bootloader=grub	Add new kernel to GRUB configuration"
  echo "	--linuxrc=<file>	Specifies a user created linuxrc"
  echo "	--disklabel	        Include disk label and uuid support in your initrd"
  echo "  Internals"
  echo "	--arch-override=<arch>	Force to arch instead of autodetect"
  echo "	--cachedir=<dir>	Override the default cache location"
  echo "	--tempdir=<dir>		Location of Genkernel's temporary directory"
  echo "	--postclear		Clear all tmp files and caches after genkernel has run"
  echo "  Output Settings"
  echo "        --kernname=<...> 	Tag the kernel and initrd with a name:"
  echo "        	 		If not defined the option defaults to 'genkernel'"
  echo "        --minkernpackage=<tbz2> File to output a .tar.bz2'd kernel and initrd:"
  echo "                                No modules outside of the initrd will be"
  echo "                                included..."
  echo "        --modulespackage=<tbz2> File to output a .tar.bz2'd modules after the callbacks have run"
  echo "        --kerncache=<tbz2> 	File to output a .tar.bz2'd kernel,"
  echo "                                contents of /lib/modules/ and the kernel config"
  echo "                                NOTE: This is created before the callbacks are run!"
  echo "        --no-kernel-sources	This option is only valid if kerncache is defined"
  echo "        			If there is a valid kerncache no checks will be made"
  echo "        			against a kernel source tree"
  echo "        --initramfs-overlay=<dir>"
  echo "        			Directory structure to include in the initramfs,"
  echo "        			only available on 2.6 kernels that don't use bootsplash"
}

usage() {
  echo "Gentoo Linux Genkernel ${GK_V}"
  echo "Usage: "
  echo "	genkernel [options] all"
  echo
  echo 'Some useful options:'
  echo '	--menuconfig		Run menuconfig after oldconfig'
  echo '	--no-clean		Do not run make clean before compilation'
  echo '	--no-mrproper		Do not run make mrproper before compilation,'
  echo '				this is implied by --no-clean.'
  echo
  echo 'For a detailed list of supported options and flags; issue:'
  echo '	genkernel --help'
}

parse_opt() {
	case "$1" in
		*\=*)
			echo "$1" | cut -f2- -d=
		;;
	esac
}

parse_cmdline() {
	case "$*" in
	      --kernel-cc=*)
		      CMD_KERNEL_CC=`parse_opt "$*"`
		      print_info 2 "CMD_KERNEL_CC: $CMD_KERNEL_CC"
	      ;;
	      --kernel-ld=*)
		      CMD_KERNEL_LD=`parse_opt "$*"`
		      print_info 2 "CMD_KERNEL_LD: $CMD_KERNEL_LD"
	      ;;
	      --kernel-as=*)
		      CMD_KERNEL_AS=`parse_opt "$*"`
		      print_info 2 "CMD_KERNEL_AS: $CMD_KERNEL_AS"
	      ;;
	      --kernel-make=*)
		      CMD_KERNEL_MAKE=`parse_opt "$*"`
		      print_info 2 "CMD_KERNEL_MAKE: $CMD_KERNEL_MAKE"
	      ;;
	      --kernel-cross-compile=*)
		      CMD_KERNEL_CROSS_COMPILE=`parse_opt "$*"`
		      CMD_KERNEL_CROSS_COMPILE=$(echo ${CMD_KERNEL_CROSS_COMPILE}|sed -e 's/.*[^-]$/&-/g')
		      print_info 2 "CMD_KERNEL_CROSS_COMPILE: $CMD_KERNEL_CROSS_COMPILE"
	      ;;
	      --utils-cc=*)
		      CMD_UTILS_CC=`parse_opt "$*"`
		      print_info 2 "CMD_UTILS_CC: $CMD_UTILS_CC"
	      ;;
	      --utils-ld=*)
		      CMD_UTILS_LD=`parse_opt "$*"`
		      print_info 2 "CMD_UTILS_LD: $CMD_UTILS_LD"
	      ;;
	      --utils-as=*)
		      CMD_UTILS_AS=`parse_opt "$*"`
		      print_info 2 "CMD_UTILS_AS: $CMD_UTILS_AS"
	      ;;
	      --utils-make=*)
		      CMD_UTILS_MAKE=`parse_opt "$*"`
		      print_info 2 "CMD_UTILS_MAKE: $CMD_UTILS_MAKE"
	      ;;
	      --utils-cross-compile=*)
		      CMD_UTILS_CROSS_COMPILE=`parse_opt "$*"`
		      CMD_UTILS_CROSS_COMPILE=$(echo ${CMD_UTILS_CROSS_COMPILE}|sed -e 's/.*[^-]$/&-/g')
		      print_info 2 "CMD_UTILS_CROSS_COMPILE: $CMD_UTILS_CROSS_COMPILE"
	      ;;
	      --utils-arch=*)
		      CMD_UTILS_ARCH=`parse_opt "$*"`
		      print_info 2 "CMD_UTILS_ARCH: $CMD_ARCHOVERRIDE"
	      ;;
	      --makeopts=*)
		      CMD_MAKEOPTS=`parse_opt "$*"`
		      print_info 2 "CMD_MAKEOPTS: $CMD_MAKEOPTS"
	      ;;
	      --mountboot)
		      CMD_MOUNTBOOT=1
		      print_info 2 "CMD_MOUNTBOOT: $CMD_MOUNTBOOT"
	      ;;
	      --no-mountboot)
		      CMD_MOUNTBOOT=0
		      print_info 2 "CMD_MOUNTBOOT: $CMD_MOUNTBOOT"
	      ;;
	      --do-keymap-auto)
		      CMD_DOKEYMAPAUTO=1
		      print_info 2 "CMD_DOKEYMAPAUTO: $CMD_DOKEYMAPAUTO"
	      ;;
	      --evms2)
		      CMD_EVMS2=1
		      print_info 2 "CMD_EVMS2: $CMD_EVMS2"
	      ;;
	      --unionfs)
		      echo
		      print_warning 1 "WARNING: unionfs support is in active development and is not meant for general use."
		      print_warning 1 "DISABLING UNIONFS SUPPORT AT THIS TIME."
		      echo
	      ;;
	      --unionfs-dev)
		      CMD_UNIONFS=1
		      print_info 2 "CMD_UNIONFS: $CMD_UNIONFS"
		      echo
		      print_warning 1 "WARNING: unionfs support is in active development and is not meant for general use."
		      print_warning 1 "Bug Reports without patches/fixes will be ignored."
		      print_warning 1 "Use at your own risk as this could blow up your system."
		      print_warning 1 "This code is subject to change at any time."
		      echo
	      ;;
	      --lvm2)
		      CMD_LVM2=1
		      print_info 2 "CMD_LVM2: $CMD_LVM2"
	      ;;
	      --no-busybox)
		      CMD_NO_BUSYBOX=1
		      print_info 2 "CMD_NO_BUSYBOX: $CMD_NO_BUSYBOX"
	      ;;
	      --slowusb)
		      CMD_SLOWUSB=1
		      print_info 2 "CMD_SLOWUSB: $CMD_SLOWUSB"
	      ;;
	      --dmraid)
		      if [ ! -e /usr/include/libdevmapper.h ]
		      then
			echo 'Error: --dmraid requires device-mapper to be installed'
			echo '       on the host system; try "emerge device-mapper".'
			exit 1
		      fi
		      CMD_DMRAID=1
		      print_info 2 "CMD_DMRAID: $CMD_DMRAID"
	      ;;
	      --bootloader=*)
		      CMD_BOOTLOADER=`parse_opt "$*"`
		      print_info 2 "CMD_BOOTLOADER: $CMD_BOOTLOADER"
	      ;;
	      --debuglevel=*)
		      CMD_DEBUGLEVEL=`parse_opt "$*"`
		      DEBUGLEVEL="${CMD_DEBUGLEVEL}"
		      print_info 2 "CMD_DEBUGLEVEL: $CMD_DEBUGLEVEL"
	      ;;
	      --menuconfig)
		      TERM_LINES=`stty -a | head -n 1 | cut -d\  -f5 | cut -d\; -f1`
		      TERM_COLUMNS=`stty -a | head -n 1 | cut -d\  -f7 | cut -d\; -f1`

		      if [[ TERM_LINES -lt 19 || TERM_COLUMNS -lt 80 ]]
		      then
			echo "Error: You need a terminal with at least 80 columns"
			echo "       and 19 lines for --menuconfig; try --nomenuconfig..."
			exit 1
		      fi
		      CMD_MENUCONFIG=1
		      print_info 2 "CMD_MENUCONFIG: $CMD_MENUCONFIG"
	      ;;
	      --no-menuconfig)
		      CMD_MENUCONFIG=0
		      print_info 2 "CMD_MENUCONFIG: $CMD_MENUCONFIG"
	      ;;
	      --gconfig)
		      CMD_GCONFIG=1
		      print_info 2 "CMD_GCONFIG: $CMD_GCONFIG"
	      ;;
	      --xconfig)
		      CMD_XCONFIG=1
		      print_info 2 "CMD_XCONFIG: $CMD_XCONFIG"
	      ;;
	      --save-config)
		      CMD_SAVE_CONFIG=1
		      print_info 2 "CMD_SAVE_CONFIG: $CMD_SAVE_CONFIG"
	      ;;
	      --no-save-config)
		      CMD_SAVE_CONFIG=0
		      print_info 2 "CMD_SAVE_CONFIG: $CMD_SAVE_CONFIG"
	      ;;
	      --mrproper)
		      CMD_MRPROPER=1
		      print_info 2 "CMD_MRPROPER: $CMD_MRPROPER"
	      ;;
	      --no-mrproper)
		      CMD_MRPROPER=0
		      print_info 2 "CMD_MRPROPER: $CMD_MRPROPER"
	      ;;
	      --clean)
		      CMD_CLEAN=1
		      print_info 2 "CMD_CLEAN: $CMD_CLEAN"
	      ;;
	      --no-clean)
		      CMD_CLEAN=0
		      print_info 2 "CMD_CLEAN: $CMD_CLEAN"
	      ;;
	      --oldconfig)
		      CMD_CLEAN=0
		      CMD_OLDCONFIG=1
		      print_info 2 "CMD_CLEAN: $CMD_CLEAN"
		      print_info 2 "CMD_OLDCONFIG: $CMD_OLDCONFIG"
	      ;;
	      --bootsplash=*)
		      CMD_BOOTSPLASH=1
		      CMD_GENSPLASH=0
		      BOOTSPLASH_THEME=`parse_opt "$*"`
		      print_info 2 "CMD_BOOTSPLASH: $CMD_BOOTSPLASH"
		      print_info 2 "CMD_GENSPLASH: $CMD_GENSPLASH"
		      print_info 2 "BOOTSPLASH_THEME: $BOOTSPLASH_THEME"
	      ;;
	      --bootsplash)
		      CMD_BOOTSPLASH=1
		      CMD_GENSPLASH=0
		      print_info 2 "CMD_BOOTSPLASH: $CMD_BOOTSPLASH"
		      print_info 2 "CMD_GENSPLASH: $CMD_GENSPLASH"
	      ;;
	      --no-bootsplash)
		      CMD_BOOTSPLASH=0
		      print_info 2 "CMD_BOOTSPLASH: $CMD_BOOTSPLASH"
	      ;;
	      --gensplash=*)
		      CMD_GENSPLASH=1
		      CMD_BOOTSPLASH=0
		      GENSPLASH_THEME=`parse_opt "$*"`
		      print_info 2 "CMD_GENSPLASH: $CMD_GENSPLASH"
		      print_info 2 "GENSPLASH_THEME: $GENSPLASH_THEME"
		      print_info 2 "CMD_BOOTSPLASH: $CMD_BOOTSPLASH"
	      ;;
	      --gensplash)
		      CMD_GENSPLASH=1
		      CMD_BOOTSPLASH=0
		      GENSPLASH_THEME='default'
		      print_info 2 "CMD_GENSPLASH: $CMD_GENSPLASH"
		      print_info 2 "CMD_BOOTSPLASH: $CMD_BOOTSPLASH"
	      ;;
	      --no-gensplash)
		      CMD_GENSPLASH=0
	              print_info 2 "CMD_GENSPLASH: $CMD_GENSPLASH"
	      ;;
	      --gensplash-res=*)
		      GENSPLASH_RES=`parse_opt "$*"`
		      print_info 2 "GENSPLASH_RES: $GENSPLASH_RES"
	      ;;
	      --install)
		      CMD_NOINSTALL=0
		      print_info 2 "CMD_NOINSTALL: $CMD_NOINSTALL"
	      ;;
	      --no-install)
		      CMD_NOINSTALL=1
		      print_info 2 "CMD_NOINSTALL: $CMD_NOINSTALL"
	      ;;
	      --no-initrdmodules)
		      CMD_NOINITRDMODULES=1
		      print_info 2 "CMD_NOINITRDMODULES: $CMD_NOINITRDMODULES"
	      ;;
	      --udev)
	      	      echo
		      echo
		      print_info 1 "--udev is deprecated and no longer necessary as udev is on by default"
		      sleep 3
		      echo
		      echo
		      print_info 2 "CMD_UDEV: $CMD_UDEV"
	      ;;
	      --no-udev)
		      CMD_NO_UDEV=1
		      print_info 2 "CMD_NO_UDEV: $CMD_NO_UDEV"
	      ;;
	      --no-devfs)
		      CMD_NO_DEVFS=1
		      print_info 2 "CMD_NO_DEVFS: $CMD_NO_DEVFS"
	      ;;
	      --callback=*)
		      CMD_CALLBACK=`parse_opt "$*"`
		      print_info 2 "CMD_CALLBACK: $CMD_CALLBACK/$*"
	      ;;
	      --static)
		      CMD_STATIC=1
		      print_info 2 "CMD_STATIC: $CMD_STATIC"
	      ;;
	      --initramfs)
		      CMD_INITRAMFS=1
		      print_info 2 "CMD_INITRAMFS: $CMD_INITRAMFS"
	      ;;
	      --tempdir=*)
		      TEMP=`parse_opt "$*"`
		      print_info 2 "TEMP: $TEMP"
	      ;; 
	      --postclear)
		      CMD_POSTCLEAR=1
		      print_info 2 "CMD_POSTCLEAR: $CMD_POSTCLEAR"
	      ;; 
	      --arch-override=*)
		      CMD_ARCHOVERRIDE=`parse_opt "$*"`
		      print_info 2 "CMD_ARCHOVERRIDE: $CMD_ARCHOVERRIDE"
	      ;;
	      --color)
		      CMD_USECOLOR=1
		      print_info 2 "CMD_USECOLOR: $CMD_USECOLOR"
	      ;;
	      --no-color)
		      CMD_USECOLOR=0
		      print_info 2 "CMD_USECOLOR: $CMD_USECOLOR"
	      ;;
	      --debugfile=*)
		      CMD_DEBUGFILE=`parse_opt "$*"`
		      DEBUGFILE=`parse_opt "$*"`
		      print_info 2 "CMD_DEBUGFILE: $CMD_DEBUGFILE"
		      print_info 2 "DEBUGFILE: $CMD_DEBUGFILE"
	      ;;
	      --kerneldir=*)
		      CMD_KERNELDIR=`parse_opt "$*"`
		      print_info 2 "CMD_KERNELDIR: $CMD_KERNELDIR"
	      ;;
	      --kernel-config=*)
		      CMD_KERNEL_CONFIG=`parse_opt "$*"`
		      print_info 2 "CMD_KERNEL_CONFIG: $CMD_KERNEL_CONFIG"
	      ;;
	      --module-prefix=*)
		      CMD_INSTALL_MOD_PATH=`parse_opt "$*"`
		      print_info 2 "CMD_INSTALL_MOD_PATH: $CMD_INSTALL_MOD_PATH"
	      ;;
	      --cachedir=*)
		      CACHE_DIR=`parse_opt "$*"`
		      print_info 2 "CACHE_DIR: $CACHE_DIR"
	      ;;
	      --minkernpackage=*)
		      CMD_MINKERNPACKAGE=`parse_opt "$*"`
		      print_info 2 "MINKERNPACKAGE: $CMD_MINKERNPACKAGE"
	      ;;
	      --modulespackage=*)
		      CMD_MODULESPACKAGE=`parse_opt "$*"`
		      print_info 2 "MODULESPACKAGE: $CMD_MODULESPACKAGE"
	      ;;
	      --kerncache=*)
		      CMD_KERNCACHE=`parse_opt "$*"`
		      print_info 2 "KERNCACHE: $CMD_KERNCACHE"
	      ;;
	      --kernname=*)
		      CMD_KERNNAME=`parse_opt "$*"`
		      print_info 2 "KERNNAME: $CMD_KERNNAME"
	      ;;
	      --symlink)
		      CMD_SYMLINK=1
		      print_info 2 "CMD_SYMLINK: $CMD_SYMLINK"
	      ;;
	      --no-kernel-sources)
		      CMD_NO_KERNEL_SOURCES=1
		      print_info 2 "CMD_NO_KERNEL_SOURCES: $CMD_NO_KERNEL_SOURCES"
	      ;;
	      --initramfs-overlay=*)
		      CMD_INITRAMFS_OVERLAY=`parse_opt "$*"`
		      print_info 2 "CMD_INITRAMFS_OVERLAY: $CMD_INITRAMFS_OVERLAY"
	      ;;
	      --linuxrc=*)
	      		CMD_LINUXRC=`parse_opt "$*"`
			print_info 2 "CMD_LINUXRC: $CMD_LINUXRC"
	      ;;
              --genzimage)
			KERNEL_MAKE_DIRECTIVE_2='zImage.initrd'
			KERNEL_BINARY_2='arch/ppc/boot/images/zImage.initrd.chrp'
			GENERATE_Z_IMAGE=1
			print_info 2 "GENERATE_Z_IMAGE: $GENERATE_Z_IMAGE"
	      ;;
	      --disklabel)
		      CMD_DISKLABEL=1
		      print_info 2 "CMD_DISKLABEL: $CMD_DISKLABEL"
	      ;;
	      all)
		      BUILD_KERNEL=1
		      BUILD_MODULES=1
		      BUILD_INITRD=1
	      ;;
	      initrd)
		      BUILD_INITRD=1
	      ;;
	      kernel)
		      BUILD_KERNEL=1
		      BUILD_MODULES=1
		      BUILD_INITRD=0
	      ;;
	      bzImage)
		      BUILD_KERNEL=1
		      BUILD_MODULES=0
		      BUILD_INITRD=1
		      CMD_NOINITRDMODULES=1
		      print_info 2 "CMD_NOINITRDMODULES: $CMD_NOINITRDMODULES"
	      ;;
	      --help)
		      longusage
		      exit 1
	      ;;
	      --version)
		      echo "${GK_V}"
		      exit 0
	      ;;
	      *)
		      echo "Error: Unknown option '$*'!"
		      exit 1
	      ;;
	esac
}
