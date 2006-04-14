#!/bin/bash
# x86/config.sh

KERNEL_MAKE_DIRECTIVE=""
KERNEL_MAKE_DIRECTIVE_2=""
KERNEL_BINARY="vmlinuz"

# The dietlibc portion of busybox is commented out right now
# other stuff seems to compile fine though
USE_DIETLIBC=0

[ -z "${MAKEOPTS}" ] && MAKEOPTS="-j2"

KERNEL_MAKE="make ARCH=xen"
UTILS_MAKE=make

KERNEL_CC=gcc
KERNEL_AS=as
KERNEL_LD=ld

UTILS_CC=gcc
UTILS_AS=as
UTILS_LD=ld

COMPRESS_INITRD=yes
