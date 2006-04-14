#!/bin/bash
#sparc64-config.sh

KERNEL_MAKE_DIRECTIVE="vmlinux"
KERNEL_MAKE_DIRECTIVE_2="image"
KERNEL_BINARY="arch/sparc64/boot/image"

# Busybox 1.00-pre3 won't build with dietlibc, when it does we
# can turn this flag on
USE_DIETLIBC=0

[ -z "${MAKEOPTS}" ] && MAKEOPTS="-j2"

KERNEL_MAKE=make
UTILS_MAKE=make

KERNEL_CC=sparc64-linux-gcc
#KERNEL_AS=as
#KERNEL_LD=ld

UTILS_CC=gcc
UTILS_AS=as
UTILS_LD=ld

COMPRESS_INITRD=yes
BOOTSPLASH="no"
USECOLOR="no"
