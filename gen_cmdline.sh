#!/bin/bash

usage() {
  echo "GenKernel ${GK_V} Options"
  echo "Available Options: "

  echo "  Debug settings"
  echo "	--debuglevel=<0-5>	Debug Verbosity Level"
  echo "	--debugfile=<outfile>	Output file for debug info"
  echo "	--color			Output debug in color"
  echo "	--no-color		Do not output debug in color"
  echo "  Kernel Compile settings"
  echo "	--menuconfig		Run menu config after oldconfig"
  echo "	--no-menuconfig		Do no run menu config after oldconfig"
  echo "	--mrproper		Run make mrproper before compilation"
  echo "	--clean			Run make clean before compilation"
  echo "	--no-clean		Do not run make clean before compilation"
  echo "	--no-mrproper		Do not run make mrproper before compilation"
  echo "	--bootsplash		Install bootsplash to initrd"
  echo "	--no-bootsplash		Do not use bootsplash"
  echo "	--install		Install kernel after building"
  echo "	--no-install		Do not install kernel after building"
  echo "	--kerneldir=<dir>	Location of kernel source"
  echo "	--kernel-config=<file>	Kernel configuration file to use for compilation"
  echo "  Low-Level Compile settings"
  echo "	--kernel-cc=<compiler>	Compiler to use for kernel (e.g. distcc)"
  echo "	--kernel-ld=<linker>	Linker to use for kernel"
  echo "	--kernel-as=<assembler>	Assembler to use for kernel"
  echo "	--utils-cc=<compiler>	Compiler to use for utils (e.g. busybox, modutils)"
  echo "	--utils-ld=<linker>	Linker to use for utils"
  echo "	--utils-as=<assembler>	Assembler to use for utils"
  echo "	--make=<make prog>	GNU Make to use"
  echo "  Internals"
  echo "	--arch-override=<arch>	Force to arch instead of autodetect (cross-compile?)"
  echo "	--busybox-config=<file>	Busybox configuration file to use"
  echo "	--busybox-bin=<file>	Don't compile busybox, use this _static_ bzip2'd binary"
  echo "  Misc Settings"
  echo "	--max-kernel-size=<k>	Maximum kernel size"
  echo "	--max-initrd-size=<k>	Maximum initrd size"
  echo "	--max-kernel-and-initrd-size=<k>	Maximum combined initrd + kernel size"
  echo ""
}

parse_opt() {
	case "$1" in
		*\=*)
			echo "$1" | cut -f2 -d=
		;;
	esac
}

parse_cmdline() {
	for x in $*
	do
		case "${x}" in
			--kernel-cc*)
				CMD_KERNEL_CC=`parse_opt "${x}"`
				print_info 2 "CMD_KERNEL_CC: $CMD_KERNEL_CC"
			;;
			--kernel-ld*)
				CMD_KERNEL_LD=`parse_opt "${x}"`
				print_info 2 "CMD_KERNEL_LD: $CMD_KERNEL_LD"
			;;
			--kernel-as*)
				CMD_KERNEL_AS=`parse_opt "${x}"`
				print_info 2 "CMD_KERNEL_AS: $CMD_KERNEL_AS"
			;;
			--utils-cc*)
				CMD_UTILS_CC=`parse_opt "${x}"`
				print_info 2 "CMD_UTILS_CC: $CMD_UTILS_CC"
			;;
			--utils-ld*)
				CMD_UTILS_LD=`parse_opt "${x}"`
				print_info 2 "CMD_UTILS_LD: $CMD_UTILS_LD"
			;;
			--utils-as*)
				CMD_UTILS_AS=`parse_opt "${x}"`
				print_info 2 "CMD_UTILS_AS: $CMD_UTILS_AS"
			;;
			--make*)
				CMD_MAKE=`parse_opt "${x}"`
				print_info 2 "CMD_MAKE: $CMD_MAKE"
			;;
			
			--debuglevel*)
				CMD_DEBUGLEVEL=`parse_opt "${x}"`
				DEBUGLEVEL="${CMD_DEBUGLEVEL}"
				print_info 2 "CMD_DEBUGLEVEL: $CMD_DEBUGLEVEL"

			;;
			--menuconfig)
				CMD_MENUCONFIG=1
				print_info 2 "CMD_MENUCONFIG: $CMD_MENUCONFIG"
			;;
			--no-menuconfig)
				CMD_MENUCONFIG=0
				print_info 2 "CMD_MENUCONFIG: $CMD_MENUCONFIG"
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
			--bootsplash)
				CMD_BOOTSPLASH=1
				print_info 2 "CMD_BOOTSPLASH: $CMD_BOOTSPLASH"
			;;
			--no-bootsplash)
				CMD_BOOTSPLASH=0
				print_info 2 "CMD_BOOTSPLASH: $CMD_BOOTSPLASH"
			;;
			--install)
				CMD_NOINSTALL=0
				print_info 2 "CMD_NOINSTALL: $CMD_NOINSTALL"
			;;
			--no-install)
				CMD_NOINSTALL=1
				print_info 2 "CMD_NOINSTALL: $CMD_NOINSTALL"
			;;
			--arch-override*)
				CMD_ARCHOVERRIDE=`parse_opt "${x}"`
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
			--debugfile*)
				CMD_DEBUGFILE=`parse_opt "${x}"`
				print_info 2 "CMD_DEBUGFILE: $CMD_DEBUGFILE"
			;;
			--kerneldir*)
				CMD_KERNELDIR=`parse_opt "${x}"`
				print_info 2 "CMD_KERNELDIR: $CMD_KERNELDIR"
			;;
			--kernel-config*)
				CMD_KERNEL_CONFIG=`parse_opt "${x}"`
				print_info 2 "CMD_KERNEL_CONFIG: $CMD_KERNEL_CONFIG"
			;;
			--busybox-config*)
				CMD_BUSYBOX_CONFIG=`parse_opt "${x}"`
				print_info 2 "CMD_BUSYBOX_CONFIG: $CMD_BUSYBOX_CONFIG"
			;;
			--busybox-bin*)
				CMD_BUSYBOX_BIN=`parse_opt "${x}"`
				print_info 2 "CMD_BUSYBOX_BIN: $CMD_BUSYBOX_BIN"
			;;
			--max-kernel-size*)
				CMD_MAX_KERNEL_SIZE=`parse_opt "${x}"`
				print_info 2 "MAX_KERNEL_SIZE: $CMD_MAX_KERNEL_SIZE"
			;;
			--max-initrd-size*)
				CMD_MAX_INITRD_SIZE=`parse_opt "${x}"`
				print_info 2 "MAX_INITRD_SIZE: $CMD_MAX_INITRD_SIZE"
			;;
			--max-kernel-and-initrd-size*)
				CMD_MAX_KERNEL_AND_INITRD_SIZE=`parse_opt "${x}"`
				print_info 2 "MAX_KERNEL_AND_INITRD_SIZE: $CMD_MAX_KERNEL_AND_INITRD_SIZE"
			;;
			--help)
				usage
				exit 1
			;;

		esac
	done
}


