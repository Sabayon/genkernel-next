#!/bin/bash
# x86/config.sh

KERNEL_MAKE_DIRECTIVE="bzImage"
KERNEL_MAKE_DIRECTIVE_2=""
KERNEL_BINARY="arch/i386/boot/bzImage"

# The dietlibc portion of busybox is commented out right now
# other stuff seems to compile fine though
USE_DIETLIBC=1

[ -z "${MAKEOPTS}" ] && MAKEOPTS="-j2"

KERNEL_MAKE=make
UTILS_MAKE=make

KERNEL_CC=gcc
KERNEL_AS=as
KERNEL_LD=ld

UTILS_CC=gcc
UTILS_AS=as
UTILS_LD=ld

COMPRESS_INITRD=yes
