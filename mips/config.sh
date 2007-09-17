#!/bin/bash

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

# Initrd/Initramfs Options
COMPRESS_INITRD="yes"
GENSPLASH=0
USECOLOR="yes"
NOINITRDMODULES="yes"
BUSYBOX=1
UNIONFS=0
DMRAID=0
DISKLABEL=0

# genkernel on mips is only used for LiveCDs && netboots.  Catalyst
# will know where to get the kernels at.
CMD_NOINSTALL=1
