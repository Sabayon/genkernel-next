#!/bin/bash
# sparc/config.sh

KERNEL_MAKE_DIRECTIVE="vmlinux"
KERNEL_MAKE_DIRECTIVE_2=""
KERNEL_BINARY="vmlinux"

# The dietlibc portion of busybox is commented out right now
# other stuff seems to compile fine though
USE_DIETLIBC=0

[ -z "${MAKEOPTS}" ] && MAKEOPTS="-j1"

KERNEL_MAKE=make
UTILS_MAKE=make

KERNEL_CC=gcc

UTILS_CC=gcc
UTILS_AS=as
UTILS_LD=ld

COMPRESS_INITRD=yes
BOOTSPLASH="no"
USECOLOR="no"
