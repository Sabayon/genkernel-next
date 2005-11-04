#!/bin/bash
# genkernel config.sh for mips systems (for 2.6.x kernels only)


# Kernel Build Info
KERNEL_MAKE=make
KERNEL_MAKE_DIRECTIVE="vmlinux"
KERNEL_MAKE_DIRECTIVE_2=""
KERNEL_BINARY="./vmlinux"
KERNEL_STATIC="yes"
CMD_KERNEL_CROSS_COMPILE="mips64-unknown-linux-uclibc-"
CMD_MAKEOPTS="-j2"

# Utils Build Info
UTILS_MAKE=make
UTILS_CC=gcc
UTILS_AS=as
UTILS_LD=ld
USE_DIETLIBC=0

# Initrd/Initramfs Options
COMPRESS_INITRD="yes"
BOOTSPLASH=0
GENSPLASH=0
USECOLOR="yes"
NOINITRDMODULES="yes"
BUSYBOX=1
UDEV=1
DEVFS=0
UNIONFS=0
LVM2=0
DMRAID=0
EVMS2=0
DISKLABEL=0
MIPS_EMBEDDED_IMAGE="yes"

# genkernel on mips is only used for LiveCDs.  Catalyst
# Will know where to get the kernels from.
CMD_NOINSTALL=1
