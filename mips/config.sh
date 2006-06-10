#!/bin/bash
# genkernel config.sh for mips systems

# Kernel Build Info
KERNEL_MAKE=make
KERNEL_MAKE_DIRECTIVE="vmlinux"
KERNEL_MAKE_DIRECTIVE_2=""
KERNEL_BINARY="./vmlinux"

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

# genkernel on mips is only used for LiveCDs && netboots.  Catalyst
# will know where to get the kernels at.
CMD_NOINSTALL=1
